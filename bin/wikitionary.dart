import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';
import 'package:synchronized/extension.dart';
import 'package:xml/xml_events.dart';

int pageCount = 0;
final pageCountLock = Object();
final batchData = <String, List<Map<String, dynamic>>>{}; // Global batch data

void main() async {
  final filePath = './data/enwiktionary-latest-pages-articles.xml';
  final outputDir = './output';
  await processXmlStream(filePath, outputDir);
}

Future<void> createDatabase(String dbPath) async {
  final db = await databaseFactoryIo.openDatabase(dbPath);
  intMapStoreFactory.store('words');
  await db.close();
}

Future<Set<String>> loadLanguages(String filePath) async {
  final file = File(filePath);
  final lines = await file.readAsLines(encoding: utf8);
  return lines.map((line) => line.trim().toLowerCase()).toSet();
}

Future<void> initializeDatabases(
    String outputDir, Set<String> languages) async {
  for (var language in languages) {
    final normalizedLanguage = language.replaceAll('old ', '');
    final dbPath = p.join(outputDir, '$normalizedLanguage.db');
    await createDatabase(dbPath);
  }
}

Future<void> processXmlStream(String filePath, String outputDir) async {
  final languageInclusions = await loadLanguages('./bin/languages.txt');
  await initializeDatabases(outputDir, languageInclusions);

  final file = File(filePath);
  final stream = file.openRead();

  final xmlStream = stream
      .transform(utf8.decoder)
      .transform(XmlEventDecoder())
      .expand((events) => events);

  String? currentTitle;
  StringBuffer textBuffer = StringBuffer();
  bool isPage = false;
  bool isText = false;
  bool isTitle = false;
  bool isRelevantNamespace = false;
  bool isNamespace = false;

  final dbCache = <String, Database>{};

  await for (final event in xmlStream) {
    if (event is XmlStartElementEvent) {
      if (event.name == 'page') {
        isPage = true;
        currentTitle = null;
        textBuffer.clear();
        isRelevantNamespace = false;
      } else if (isPage && event.name == 'title') {
        currentTitle = '';
        isTitle = true;
      } else if (isPage && event.name == 'text') {
        isText = true;
      } else if (isPage && event.name == 'ns') {
        isNamespace = true;
      }
    } else if (event is XmlEndElementEvent) {
      if (event.name == 'page') {
        if (isRelevantNamespace &&
            currentTitle != null &&
            textBuffer.isNotEmpty) {
          if (!RegExp(r'[0-9!@#$%^&*()?":{}|<>]').hasMatch(currentTitle)) {
            await processPage(
                currentTitle, textBuffer.toString(), outputDir, dbCache);
          }
        }
        isPage = false;
      } else if (event.name == 'title') {
        currentTitle = currentTitle?.trim();
        isTitle = false;
      } else if (event.name == 'text') {
        isText = false;
      } else if (event.name == 'ns') {
        isNamespace = false;
      }
    } else if (event is XmlTextEvent) {
      if (currentTitle != null && isPage && isTitle) {
        currentTitle += event.text;
      } else if (isText && isPage && isRelevantNamespace) {
        textBuffer.write(event.text);
      } else if (isPage && isNamespace) {
        isRelevantNamespace = event.text.trim() == '0';
      }
    }
  }

  // Insert any remaining data in the global batchData
  for (var dbPath in batchData.keys) {
    if (batchData[dbPath]!.isNotEmpty) {
      await _insertBatch(dbPath, batchData[dbPath]!, dbCache);
      print('Inserted remaining batch into $dbPath');
    }
  }

  // Close all cached databases
  for (var db in dbCache.values) {
    await db.close();
  }
}

Future<void> processPage(String title, String textContent, String outputDir,
    Map<String, Database> dbCache) async {
  if (RegExp(r'\d').hasMatch(title)) return;

  final lines = LineSplitter.split(textContent);
  final languageInclusions = await loadLanguages('./bin/languages.txt');
  final languageSections = <String, Map<String, dynamic>>{};
  String? currentLanguage;
  List<Map<String, dynamic>> sectionStack = [];

  for (var line in lines) {
    final headingLevel = line.indexOf(RegExp(r'[^=]'));
    if (headingLevel > 0 && line.endsWith('=' * headingLevel)) {
      final sectionName =
          line.substring(headingLevel, line.length - headingLevel).trim();

      if (headingLevel == 2 &&
          languageInclusions.contains(sectionName.toLowerCase())) {
        currentLanguage = sectionName;
        if (!languageSections.containsKey(currentLanguage)) {
          languageSections[currentLanguage] = {};
        }
        sectionStack = [languageSections[currentLanguage]!];
      } else if (currentLanguage != null && sectionStack.isNotEmpty) {
        while (sectionStack.length >= headingLevel - 1) {
          sectionStack.removeLast();
        }
        final parentMap = sectionStack.isNotEmpty ? sectionStack.last : null;
        if (parentMap != null && !parentMap.containsKey(sectionName)) {
          parentMap[sectionName] = <String, dynamic>{};
        }
        if (parentMap != null) {
          sectionStack.add(parentMap[sectionName] as Map<String, dynamic>);
        }
      }
    } else if (currentLanguage != null && sectionStack.isNotEmpty) {
      final currentSectionMap = sectionStack.last;
      final contentKey = 'content';
      if (!currentSectionMap.containsKey(contentKey)) {
        currentSectionMap[contentKey] = '';
      }
      currentSectionMap[contentKey] += '${line.trim()}\n';
    }
  }

  for (var language in languageSections.keys) {
    if (languageInclusions
        .contains(language.toLowerCase().replaceAll('old ', ''))) {
      final normalizedLanguage = language.toLowerCase().replaceAll('old ', '');
      final dbPath = p.join(outputDir, '$normalizedLanguage.db');

      if (!batchData.containsKey(dbPath)) {
        batchData[dbPath] = [];
      }

      batchData[dbPath]!.add({
        'word': title,
        'language': normalizedLanguage,
        ...languageSections[language]!
      });

      // If batch size reaches 100, insert into the database
      if (batchData[dbPath]!.length >= 1000) {
        await _insertBatch(dbPath, batchData[dbPath]!, dbCache);
        //print('Inserted batch of 1000 entries into $dbPath');
        batchData[dbPath]!.clear();
      }
    }
  }

  await pageCountLock.synchronized(() {
    pageCount++;
    if (pageCount % 10000 == 0) {
      print('Processed $pageCount pages.');
    }
  });
}

Future<void> _insertBatch(String dbPath, List<Map<String, dynamic>> batchData,
    Map<String, Database> dbCache) async {
  if (!dbCache.containsKey(dbPath)) {
    dbCache[dbPath] = await databaseFactoryIo.openDatabase(dbPath);
  }
  final db = dbCache[dbPath]!;
  final store = intMapStoreFactory.store('words');

  await db.transaction((txn) async {
    for (var data in batchData) {
      await store.add(txn, data);
    }
  });
}
