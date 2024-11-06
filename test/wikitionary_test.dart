library wikitionary_test;

import 'dart:io';

import 'package:test/test.dart';
import 'package:wikitionary/parser/wiki_template_parser.dart';

import '../bin/wikitionary.dart';

void main() {
  group('Wiktionary XML Processing', () {
    test('processXmlStream extracts correct data', () async {
      // Sample XML content
      final xmlContent =
          await File('./assets/test_page_article.xml').readAsString();

      // Create a temporary file to simulate the XML input
      final filePath = './test/test_page_article.xml';
      await File(filePath).writeAsString(xmlContent);

      // Call the processXmlStream function
      final outputDir = './test_output'; // Specify your output directory
      // delete all file in output directory
      await Directory(outputDir).delete(recursive: true);
      await processXmlStream(filePath, outputDir);

      // Read all the .db files in the output directory, each line except the first line contains json data, send it to wikiParser to parse and print the output to a new file in append mode
      final wikiParser = WikiTemplateParser();
      final outputFilePath = './test_output/test_output.json';
      await wikiParser.parseDbFiles(outputDir, outputFilePath);

      // Clean up the temporary file
      await File(filePath).delete();
    });
  }, timeout: Timeout(Duration(seconds: 4500)));
}
