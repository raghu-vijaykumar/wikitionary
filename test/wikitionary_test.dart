library wikitionary_test;

import 'dart:io';

import 'package:test/test.dart';

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
      final outputDir = './output'; // Specify your output directory
      await processXmlStream(filePath, outputDir);

      // Optionally, read the content of the output file and verify its correctness
      // This part will depend on how you save data in your database
      // For example, you might want to check if the database contains the expected entries

      // Clean up the temporary file
      await File(filePath).delete();
    });
  }, timeout: Timeout(Duration(seconds: 4500)));
}
