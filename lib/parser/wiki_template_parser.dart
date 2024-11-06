import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../util/lang_info_loader.dart';

extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}

class WikiTemplateParser {
  late LangInfoLoader _langInfoLoader;
  // Craete a constructor that loads the langinf oject
  WikiTemplateParser() {
    _langInfoLoader = LangInfoLoader('./data/wikilang.csv')..loadLangInfo();
  }

  /// Parses the input text and returns the displayable text.
  String parse(String input, String language, String title) {
    // Remove comments
    String cleanedInput = _removeComments(input);

    // Remove references
    cleanedInput = _removeReferences(cleanedInput);

    // Remove references like {{R:FGSS}}
    cleanedInput = _removeReferencesTemplate(cleanedInput);

    // Remove audio templates
    cleanedInput = _removeAudioTemplates(cleanedInput);

    // Remove topics templates
    cleanedInput = _removeTopicsTemplates(cleanedInput);

    // Parse [link word] format
    cleanedInput = parseLinkWord(cleanedInput);

    // Further clean up the text (e.g., remove extra whitespace)
    cleanedInput = _cleanUpText(cleanedInput);

    // Parse the content and return the formatted output
    return _parseContent(cleanedInput, language, title);
  }

  // Recursive function to parse content in sections
  void parseSections(
      Map<String, dynamic> sections, String language, String title) {
    for (var section in sections.entries) {
      if (section.key == 'content') {
        sections['content'] =
            parse(section.value, language, title); // Update content directly
      } else if (section.value is Map<String, dynamic>) {
        parseSections(
            section.value, language, title); // Recursively parse nested maps
      }
    }
  }

  /// Removes comments from the input text.
  String _removeComments(String content) {
    return content.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  }

  /// Removes references from the input text.
  String _removeReferences(String content) {
    return content.replaceAll(RegExp(r'<ref>.*?</ref>', dotAll: true), '');
  }

  /// Removes references like {{R:FGSS}} from the input text.
  String _removeReferencesTemplate(String content) {
    return content.replaceAll(RegExp(r'\{\{R:[^}]*\}\}'), '');
  }

  /// Removes audio templates from the input text.
  String _removeAudioTemplates(String content) {
    return content.replaceAll(RegExp(r'\{\{audio\|.*?\}\}'), '');
  }

  /// Removes topics templates from the input text.
  String _removeTopicsTemplates(String content) {
    return content.replaceAll(RegExp(r'\{\{topics\|.*?\}\}'), '');
  }

  /// Cleans up the text by removing extra whitespace and newlines.
  String _cleanUpText(String content) {
    // Remove [[ ]] around words
    content = content.replaceAllMapped(RegExp(r'\[\[(.*?)\]\]'), (match) {
      return match.group(1) ?? ''; // Return the captured group
    });
    return content.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Parses the content, handling both templates and regular text.
  String _parseContent(String content, String language, String title) {
    final buffer = StringBuffer();
    final regex =
        RegExp(r'(\{\{.*?\}\}|[^{}]+)'); // Match templates or regular text

    // Check for file links and set display text to empty if found
    if (RegExp(r'\[\[File:.*?\]\]').hasMatch(content)) {
      return ''; // Return empty if any file links are found
    }

    for (final match in regex.allMatches(content)) {
      if (match.group(0)!.startsWith('{{')) {
        // It's a template
        String templateOutput =
            _chooseParsingLogic(match.group(0)!, language, title);
        buffer.write(templateOutput);
      } else {
        // It's regular text
        buffer.write(match.group(0));
      }
    }

    return buffer.toString();
  }

  /// Parses the {{lang-noun|...}} and {{lang-noun-m|...}} templates generically.
  String parseLangNoun(String template, String language, String title,
      {bool isGendered = false}) {
    final regex = isGendered
        ? RegExp(r'\{\{(\w+)-noun-(m|f|n)?\|([^|]*)\|([^|]*)\|([^|]*)\}\}')
        : RegExp(r'\{\{(\w+)-noun\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\}\}');

    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code
      String singular = match.group(2) ?? ''; // The singular form
      String plural = match.group(3) ?? ''; // The plural form
      String gender = match.group(4) ?? ''; // The gender (optional)
      String declension = match.group(5) ?? ''; // The declension (optional)

      // Construct the display text
      return '''$singular (singular), $plural (plural), Gender: $gender, Declension: $declension in $langCode''';
    }

    return '';
  }

  /// Parses the {{head|...}} template and returns a formatted string.
  String parseHeadTemplate(String template, String language, String title) {
    final regex = RegExp(
        r'\{\{head\|([^|]+)\|([^|]*)\|?([^|]*)\|?([^|]*)\|?([^|]*)\|?([^|]*)\}\}');
    final match = regex.firstMatch(template);

    String? currentLangCode =
        _langInfoLoader.getLangCodeByCanonicalName(language);

    if (match != null) {
      String language = match.group(1) ?? '';
      if (currentLangCode == language) {
        language = '';
      }
      String partOfSpeech = match.group(2) ?? '';
      String dual = match.group(4) ?? '';
      String plural = match.group(6) ?? '';

      String displayText =
          '$title${language.isNotEmpty ? ' ($language)' : ''}'; // Show language only if not empty
      List<String> forms = [];

      if (partOfSpeech.isNotEmpty) {
        forms.add(partOfSpeech);
      }
      if (dual.isNotEmpty) {
        forms.add('dual: $dual');
      }
      if (plural.isNotEmpty) {
        forms.add('plural: $plural');
      }

      if (forms.isNotEmpty) {
        displayText += ' (${forms.join(', ')})';
      }

      return displayText;
    }

    return '';
  }

  /// Parses the {{alt|...}} template and returns a formatted string.
  String parseAltTemplate(String template, String language, String title) {
    final regex = RegExp(r'\{\{alt\|([^|]*)\|([^|]*)\|?([^|]*)\|?([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String word = match.group(2) ?? ''; // The word (e.g., "shena")
      String alternative =
          match.group(4) ?? ''; // The alternative (e.g., "Gheg")

      return '$word — $alternative';
    }

    return '';
  }

  /// Parses the {{inflection of|...}} template and returns a formatted string.
  String parseInflectionTemplate(
      String template, String language, String title) {
    final regex = RegExp(
        r'\{\{inflection of\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String baseWord = match.group(1) ?? 'N/A'; // The base word
      String language = match.group(2) ?? ''; // The language (optional)
      String tense = match.group(3) ?? ''; // The tense (optional)
      String person = match.group(4) ?? ''; // The person (optional)
      String number = match.group(5) ?? ''; // The number (optional)

      // Construct the display text
      String displayText = baseWord;
      List<String> descriptors = [];

      if (tense.isNotEmpty) {
        descriptors.add(tense);
      }
      if (person.isNotEmpty) {
        descriptors.add(person);
      }
      if (number.isNotEmpty) {
        descriptors.add(number);
      }

      if (descriptors.isNotEmpty) {
        displayText += ' (${descriptors.join(', ')})';
      }

      return displayText;
    }

    return '';
  }

  /// Parses the {{bor|...}} template and returns a formatted string.
  String parseBorrowingTemplate(
      String template, String language, String title) {
    final regex = RegExp(r'\{\{bor\|([^|]*)\|([^|]*)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String language =
          match.group(2) ?? ''; // The borrowing language (e.g., "la")
      String borrowedWord =
          match.group(3) ?? ''; // The borrowed word (e.g., "capitālis")
      String languageDisplay = _mapLanguageToDisplay(language);
      return '$borrowedWord ($languageDisplay)';
    }

    return '';
  }

  String _mapLanguageToDisplay(String language) {
    String? name = _langInfoLoader.getNameByLangCode(language);
    return name ?? language;
  }

  /// Parses the {{ast-adj-mf|...}} template and returns a formatted string.
  String parseAstAdjMfTemplate(String template, String language, String title) {
    final regex = RegExp(r'\{\{ast-adj-mf\|pl=([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String pluralForm =
          match.group(1) ?? ''; // The plural form (e.g., "capitales")
      return 'plural: $pluralForm'; // Format as needed
    }

    return '';
  }

  /// Parses the {{IPA|...}} template and returns a formatted string.
  String parseIPATemplate(String template, String language, String title) {
    final regex = RegExp(
        r'\{\{IPA\|([^|]*)\|([^|]*)\}\}'); // Updated regex to capture language code
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "sq")
      String ipa = match.group(2) ?? ''; // The IPA representation
      return 'IPA: /$ipa/'; // Format as needed
    }

    return '';
  }

  /// Parses the {{rhyme|...}} or {{rhymes|...}} template and returns a formatted string.
  String parseRhymeTemplate(String template, String language, String title) {
    final regex = RegExp(
        r'\{\{(rhyme|rhymes)\|([^|]*)\|([^|]*)\|s=(\d+)\}\}'); // Updated regex to capture rhyme word and syllable count
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(2) ?? ''; // The language code (e.g., "ca")
      String rhymeWord = match.group(3) ?? ''; // The rhyme word
      String syllableCount = match.group(4) ?? ''; // The syllable count
      return 'Rhymes in $langCode: -$rhymeWord (syllables: $syllableCount)'; // Format as needed
    }

    return '';
  }

  /// Parses the {{gloss|...}} and {{gl|...}} templates and returns a formatted string.
  String parseGloss(String template, String language, String title) {
    final regex = RegExp(r'\{\{(gloss|gl)\|([^}]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String glossText = match.group(2) ?? ''; // The gloss text
      return match.group(1) == 'gloss'
          ? '($glossText)'
          : glossText; // Format as needed
    }

    return '';
  }

  /// Parses the {{cog|...}} template and returns a formatted string.
  String parseCogTemplate(String template, String language, String title) {
    final regex = RegExp(
        r'\{\{cog\|([^|]*)\|([^|]*)\}\}'); // Regex to capture language code and word
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "cy")
      String word = match.group(2) ?? ''; // The word (e.g., "ei")
      return '$word ($langCode)'; // Format as needed
    }

    return '';
  }

  /// Parses the {{ux|...}} and {{uxi|...}} templates and returns a formatted string.
  String parseUx(String template, String language, String title) {
    final regex = RegExp(r'\{\{(ux|uxi)\|([^|]*)\|([^|]*)\|?([^}]*)\}\}');
    final matches = regex.allMatches(template);

    List<String> results = [];

    for (final match in matches) {
      String langCode = match.group(1) ?? ''; // The language code
      String example = match.group(2) ?? ''; // The example text
      String translation = match.group(3) ?? ''; // The translation text

      // Format the output as needed
      results.add(translation.isNotEmpty ? '$example | $translation' : example);
    }

    return results.join(', '); // Join multiple results with a comma
  }

  /// Parses the {{alter|...}} template and returns a formatted string.
  String parseAlterTemplate(String template, String language, String title) {
    final regex = RegExp(
        r'\{\{alter\|([^|]*)\|([^|]*)\|([^|]*)\}\}'); // Regex to capture the parameters
    final match = regex.firstMatch(template);

    if (match != null) {
      String baseForm = match.group(1) ?? ''; // The base form
      String altForm1 = match.group(2) ?? ''; // The first alternative form
      String altForm2 = match.group(3) ?? ''; // The second alternative form

      // Format the output as needed
      return '$baseForm (alternatives: $altForm1, $altForm2)'; // Example format
    }

    return '';
  }

  /// Parses the {{der|...}} template and returns a formatted string.
  String parseDerTemplate(String template, String language, String title) {
    final regex = RegExp(
        r'\{\{der\|([^|]*)\|([^|]*)\|([^|]*)\}\}'); // Regex to capture the parameters
    final match = regex.firstMatch(template);

    if (match != null) {
      String baseForm = match.group(1) ?? ''; // The base form
      String langCode = match.group(2) ?? ''; // The language code (e.g., "en")
      String derivedForm = match.group(3) ?? ''; // The derived form

      // Format the output as needed
      return '$baseForm (derived: $derivedForm in $langCode)'; // Example format
    }

    return '';
  }

  /// Parses the {{n-g|...}} template and returns a formatted string.
  String parseNGTemplate(String template, String language, String title) {
    final regex =
        RegExp(r'\{\{n-g\|([^}]*)\}\}'); // Regex to capture the description
    final match = regex.firstMatch(template);

    if (match != null) {
      String description = match.group(1) ?? ''; // The description text
      return 'Noun-Gender: $description'; // Format as needed
    }

    return '';
  }

  /// Parses the {{wes-...}} template and returns a formatted string.
  String parseWesDashTemplate(String template, String language, String title) {
    return ''; // Return an empty string if no match is found
  }

  /// Parses the {{c|...}} template and returns a formatted string.
  String parseCTemplate(String template, String language, String title) {
    return '';
  }

  /// Parses the {{l|...}} template and returns a formatted string.
  String parseLangTemplate(String template, String language, String title) {
    final regex = RegExp(r'\{\{l\|([^|]+)\|([^|]+)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "sq")
      String word = match.group(2) ?? ''; // The word (e.g., "shi")
      return '$word ($langCode)'; // Format as needed
    }

    return '';
  }

  /// Parses the {{der2|...}} template and returns a formatted string.
  String parseDer2Template(String template, String language, String title) {
    final regex = RegExp(
        r'\{\{der2\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String baseForm = match.group(1) ?? ''; // The base form
      String form1 = match.group(2) ?? ''; // The first derived form
      String form2 = match.group(3) ?? ''; // The second derived form
      String form3 = match.group(4) ?? ''; // The third derived form
      String form4 = match.group(5) ?? ''; // The fourth derived form
      String form5 = match.group(6) ?? ''; // The fifth derived form

      // Construct the display text
      return '$baseForm (derived: $form1, $form2, $form3, $form4, $form5)'; // Format as needed
    }

    return '';
  }

  /// Parses the {{lb|...}} template and returns a formatted string.
  String parseLbTemplate(String template, String language, String title) {
    final regex = RegExp(r'\{\{lb\|([^|]+)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String word = match.group(2) ?? ''; // The word (e.g., "Mpakwithi")
      return word; // Return the word directly
    }

    return '';
  }

  /// Parses the {{bor+|...}} template and returns a formatted string.
  String parseBorrowingPlusTemplate(
      String template, String language, String title) {
    final regex = RegExp(r'\{\{bor\+\|([^|]+)\|([^|]+)\|([^|]+)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String borrowingLang =
          match.group(1) ?? ''; // The borrowing language (e.g., "ca")
      String sourceLang =
          match.group(2) ?? ''; // The source language (e.g., "la")
      String borrowedWord =
          match.group(3) ?? ''; // The borrowed word (e.g., "capitālis")
      String borrowingLangDisplay = _mapLanguageToDisplay(borrowingLang);
      String sourceLangDisplay = _mapLanguageToDisplay(sourceLang);
      return '$borrowedWord (borrowed from $sourceLangDisplay in $borrowingLangDisplay)'; // Format as needed
    }

    return '';
  }

  /// Parses the {{adj|...}} template and returns a formatted string.
  String parseAdjTemplate(String template, String language, String title) {
    final regex = RegExp(r'\{\{(\w+)-adj\|([^|]*)\|([^|]*)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "en")
      String masculine = match.group(2) ?? ''; // The masculine form
      String feminine = match.group(3) ?? ''; // The feminine form
      String plural = match.group(4) ?? ''; // The plural form

      if (masculine.isEmpty && feminine.isEmpty && plural.isEmpty) {
        return ''; // Return empty if nothing is present after adj
      }

      // Construct the display text
      return '''$masculine (masculine), $feminine (feminine), $plural (plural) in $langCode''';
    }

    return ''; // Return empty if only {{(\w+)-adj}} is present
  }

  /// Parses the {{desc|...}} template and returns a formatted string.
  String parseDescendantsTemplate(
      String template, String language, String title) {
    final regex = RegExp(r'\{\{desc\|([^|]+)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode =
          match.group(1) ?? ''; // The language code (e.g., "gmw-jdt")
      String term = match.group(2) ?? ''; // The term (e.g., "wê")

      // Construct the display text
      return '''Descendants: $term (in $langCode)''';
    }

    return '';
  }

  /// Parses the {{quote-journal|...}} or {{quote-book|...}} template and returns a formatted string.
  String parseQuoteTemplate(String template, String language, String title) {
    final regex = RegExp(
        r'\{\{(quote-journal\s*\|\s*|quote-book\s*\|\s*|quote-text\s*\|\s*quote-web\s*|\s*|cite-book\s*\|)([^|]*)\|([^|]*)\}\}'); // Updated regex to allow spaces after quote-journal
    final match = regex.firstMatch(template);

    if (match != null) {
      String type =
          match.group(1) ?? ''; // The type (quote-journal or quote-book)
      String content =
          match.group(2) ?? ''; // The content containing key-value pairs

      // Split the content into key-value pairs
      final keyValuePairs = content.split('|');
      Map<String, String> values = {};

      for (var pair in keyValuePairs) {
        final keyValue = pair.split('=');
        if (keyValue.length == 2) {
          values[keyValue[0].trim()] = keyValue[1].trim();
        }
      }

      // Construct the display text using the extracted values
      StringBuffer displayText = StringBuffer();
      displayText.writeln('Quote from ${values['magazine'] ?? ''}:');
      values.forEach((key, value) {
        displayText.writeln('${key.capitalize()}: $value');
      });
      return displayText.toString();
    }

    return '';
  }

  /// Parses the {{non-gloss|...}} template and returns a formatted string.
  String parseNonGlossTemplate(String template, String language, String title) {
    final regex = RegExp(r'\{\{non-gloss\|([^}]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String description = match.group(1) ?? ''; // The description text
      return 'Non-gloss: $description'; // Format as needed
    }

    return '';
  }

  /// Parses the {{misspelling of|...}} template and returns a formatted string.
  String parseMisspellingOfTemplate(
      String template, String language, String title) {
    final regex = RegExp(r'\{\{misspelling of\|([^|]*)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "nl")
      String misspelledWord =
          match.group(2) ?? ''; // The misspelled word (e.g., "hé")

      // Construct the display text
      return 'Misspelling of "$misspelledWord" in language code: $langCode';
    }

    return '';
  }

  /// Parses the {{t|...}}, {{t+|...}}, {{tt|...}}, and {{tt+|...}} templates and returns a formatted string.
  String parseTranslation(String template, String language, String title,
      {bool isPlus = false}) {
    final regex = isPlus
        ? RegExp(r'\{\{t\+\|([^|]+)\|([^|]*)\|?([^|]*)\}\}')
        : RegExp(r'\{\{t\|([^|]+)\|([^|]*)\|?([^|]*)\}\}');

    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code
      String translatedWord = match.group(2) ?? ''; // The translated word
      String gender = match.group(3) ?? ''; // The gender (optional)

      // Construct the display text
      String genderDisplay = gender.isNotEmpty ? " ($gender)" : '';
      return '$translatedWord$genderDisplay ($langCode)'; // Format as needed
    }

    // Handle {{tt|...}} and {{tt+|...}} templates
    final ttRegex = isPlus
        ? RegExp(r'\{\{tt\+\|([^|]+)\|([^|]*)\}\}')
        : RegExp(r'\{\{tt\|([^|]+)\|([^|]*)\}\}');

    final ttMatch = ttRegex.firstMatch(template);

    if (ttMatch != null) {
      String langCode = ttMatch.group(1) ?? ''; // The language code
      String translatedWord = ttMatch.group(2) ?? ''; // The translated word
      return '$translatedWord ($langCode)'; // Format as needed
    }

    return '';
  }

  /// Parses the {{qualifier|...}} template and returns a formatted string.
  String parseQualifierTemplate(
      String template, String language, String title) {
    final regex = RegExp(r'\{\{qualifier\|([^|]*)\}\}');
    final matches = regex.allMatches(template);

    List<String> qualifiers = [];

    for (final match in matches) {
      String qualifierText = match.group(1) ?? ''; // The qualifier text
      if (qualifierText.isNotEmpty) {
        qualifiers.add(qualifierText);
      }
    }

    return qualifiers.isNotEmpty
        ? '(${qualifiers.join(', ')})'
        : ''; // Format as needed
  }

  /// Parses the {{inh|...}} template and returns a formatted string.
  String parseInhTemplate(String template, String language, String title) {
    final regex = RegExp(r'\{\{inh\|([^|]+)\|([^|]+)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "en")
      String inheritedLangCode =
          match.group(2) ?? ''; // The inherited language code (e.g., "enm")
      String term =
          match.group(3) ?? ''; // The term being inherited (e.g., "capital")

      // Construct the display text
      return '''Term: $term (inherited from $inheritedLangCode in $langCode)''';
    }

    return '';
  }

  /// Parses the {{langCode-verb form of|...}} template and returns a formatted string.
  String parseLangCodeVerbFormTemplate(
      String template, String language, String title) {
    final regex = RegExp(r'\{\{(\w+)-verb form of\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "ca")
      String verbForm =
          match.group(2) ?? ''; // The verb form (e.g., "haver<var:aux>")

      // Construct the display text
      return '''Verb Form: $verbForm (in $langCode)''';
    }

    return '';
  }

  /// Parses the {{langCode-adj}} template and returns a message indicating it's empty.
  String parseLangCodeAdjEmpty(String template, String language, String title) {
    final regex = RegExp(r'\{\{(\w+)-adj\}\}');
    final matches = regex.allMatches(template);

    if (matches.isNotEmpty) {
      // Return a message indicating that the langCode-adj template is empty for each occurrence
      return '';
    }

    return '';
  }

  /// Parses the {{langCode-noun|...}} template and returns a formatted string.
  String parseLangCodeNounTemplate(
      String template, String language, String title) {
    final regex =
        RegExp(r'\{\{(\w+)-noun\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "en")
      String singular = match.group(2) ?? ''; // The singular form
      String plural = match.group(3) ?? ''; // The plural form
      String gender = match.group(4) ?? ''; // The gender (optional)
      String declension = match.group(5) ?? ''; // The declension (optional)

      if (singular.isEmpty &&
          plural.isEmpty &&
          gender.isEmpty &&
          declension.isEmpty) {
        return ''; // Return empty if nothing is present after -noun
      }

      // Construct the display text
      return '''$singular (singular), $plural (plural), Gender: $gender, Declension: $declension in $langCode''';
    }

    return '';
  }

  /// Parses the {{RQ:<lang_code>:<any_string>|...}} template and returns a formatted string.
  String parseRQTemplate(String template, String language, String title) {
    final regex =
        RegExp(r'\{\{RQ:([^:]+):([^|]+)\|([^|]*)\|([^|]*)\|lit=([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "jam")
      String referenceCode =
          match.group(2) ?? ''; // The reference code (e.g., "YDYR")
      String mainText = match.group(3) ?? ''; // The main text
      String translation = match.group(4) ?? ''; // The translation
      String literalTranslation =
          match.group(5) ?? ''; // The literal translation

      // Construct the display text
      return '''Language Code: $langCode
Reference: $referenceCode
Main Text: $mainText
Translation: $translation
Literal Translation: $literalTranslation''';
    }

    return '';
  }

  /// Chooses the appropriate parsing logic based on the content.
  String _chooseParsingLogic(String content, String language, String title) {
    if (content.contains('{{head|')) {
      return parseHeadTemplate(content, language, title);
    }
    if (content.contains('{{alt|')) {
      return parseAltTemplate(content, language, title);
    }
    if (content.contains('{{inflection of|')) {
      return parseInflectionTemplate(content, language, title);
    }
    if (content.contains('{{bor|')) {
      return parseBorrowingTemplate(content, language, title);
    }
    if (content.contains('{{ast-adj-mf|')) {
      return parseAstAdjMfTemplate(content, language, title);
    }
    if (content.contains('{{IPA|')) {
      return parseIPATemplate(content, language, title);
    }
    if (content.contains('{{rhyme|') || content.contains('{{rhymes|')) {
      return parseRhymeTemplate(content, language, title);
    }
    if (content.contains('{{gloss|') || content.contains('{{gl|')) {
      return parseGloss(content, language, title);
    }
    if (content.contains('{{cog|')) {
      return parseCogTemplate(content, language, title);
    }
    if (content.contains('{{ux|') || content.contains('{{uxi|')) {
      return parseUx(content, language, title);
    }
    if (content.contains('{{alter|')) {
      return parseAlterTemplate(content, language, title);
    }
    if (content.contains('{{der|')) {
      return parseDerTemplate(content, language, title);
    }
    if (content.contains('{{n-g|')) {
      return parseNGTemplate(content, language, title);
    }
    if (content.contains('{{wes-')) {
      return parseWesDashTemplate(content, language, title);
    }
    if (content.contains('{{c|')) {
      return parseCTemplate(
          content, language, title); // Handle {{c|...}} template
    }
    if (content.contains('{{l|')) {
      return parseLangTemplate(
          content, language, title); // Handle {{l|...}} template
    }
    if (content.contains('{{der2|')) {
      return parseDer2Template(
          content, language, title); // Handle {{der2|...}} template
    }
    if (content.contains('{{lb|')) {
      return parseLbTemplate(
          content, language, title); // Handle {{lb|...}} template
    }
    if (RegExp(r'\{\{(\w+)-noun(-(m|f|n))?\|').hasMatch(content)) {
      return parseLangNoun(
          content, language, title); // Handle noun templates generically
    }
    if (content.contains('{{bor+|')) {
      return parseBorrowingPlusTemplate(
          content, language, title); // Handle {{bor+|...}} template
    }

    if (RegExp(r'\{\{(\w+)-adj\|').hasMatch(content)) {
      return parseAdjTemplate(
          content, language, title); // Handle {{adj|...}} template
    }
    if (RegExp(r'\{\{(\w+)-noun\|').hasMatch(content)) {
      return parseLangCodeNounTemplate(
          content, language, title); // Handle {{langCode-noun|...}} template
    }
    if (content.contains('{{RQ:')) {
      return parseRQTemplate(
          content, language, title); // Handle {{RQ:...}} template
    }
    if (content.contains('{{t+|') || content.contains('{{t|')) {
      return parseTranslation(content, language, title,
          isPlus: content
              .contains('{{t+|}')); // Handle {{t+|...}} or {{t|...}} template
    }
    if (content.contains('{{tt|') || content.contains('{{tt+|')) {
      return parseTranslation(content, language, title,
          isPlus: content
              .contains('{{tt+|')); // Handle {{tt|...}} or {{tt+|...}} template
    }
    if (content.contains('{{qualifier|')) {
      return parseQualifierTemplate(
          content, language, title); // Handle {{qualifier|...}} template
    }
    if (content.contains('{{inh|')) {
      return parseInhTemplate(
          content, language, title); // Handle {{inh|...}} template
    }
    if (RegExp(r'\{\{(\w+)-verb\|').hasMatch(content)) {
      return parseLangCodeVerbFormTemplate(content, language,
          title); // Handle {{langCode-verb form of|...}} template
    }
    if (RegExp(r'\{\{(\w+)-adj\}\}').hasMatch(content)) {
      return parseLangCodeAdjEmpty(
          content, language, title); // Handle {{langCode-adj}} template
    }
    if (RegExp(r'\{\{(\w+)-noun\}\}').hasMatch(content)) {
      return parseLangCodeNounTemplate(
          content, language, title); // Handle {{langCode-noun}} template
    }
    if (content.contains('{{desc|')) {
      return parseDescendantsTemplate(
          content, language, title); // Handle {{desc|...}} template
    }
    if (content.contains('{{quote') || content.contains('{{cite-book')) {
      return parseQuoteTemplate(content, language,
          title); // Handle {{quote-journal|...}} or {{quote-book|...}} template
    }
    if (content.contains('{{non-gloss|')) {
      return parseNonGlossTemplate(
          content, language, title); // Handle {{non-gloss|...}} template
    }
    if (content.contains('{{misspelling of|')) {
      return parseMisspellingOfTemplate(
          content, language, title); // Handle {{misspelling of|...}} template
    }

    // Add more conditions for other templates as needed

    return content; // Return the original content if no templates are matched
  }

  Future<void> parseDbFiles(String outputDir, String outputFilePath) async {
    final dbFiles = Directory(outputDir)
        .listSync(recursive: true)
        .where((file) => file.path.endsWith('.db'))
        .toList();
    List<Map<String, dynamic>> jsonList = [];

    for (var dbFile in dbFiles) {
      final fileContent = await File(dbFile.path).readAsString();
      for (var line in fileContent.split('\n').skip(1)) {
        if (line.isEmpty) {
          continue;
        }
        final jsonData = jsonDecode(line);

        parseSections(
            jsonData['value'],
            p.basenameWithoutExtension(dbFile.path).split('.').first,
            jsonData['value']['word']);
        jsonList.add(jsonData);
      }
    }
    await File(outputFilePath)
        .writeAsString(jsonEncode(jsonList), mode: FileMode.write);
  }

  /// Parses the [link word] format and returns a formatted string.
  String parseLinkWord(String content) {
    final regex = RegExp(r'\[([^\s]+)\s+([^\]]+)\]'); // Matches [link word]
    return content.replaceAllMapped(regex, (match) {
      String link = match.group(1) ?? ''; // The link (e.g., "link")
      String word = match.group(2) ?? ''; // The word (e.g., "word")
      return '$word ($link)'; // Format as needed
    });
  }
}
