import '../util/lang_info_loader.dart';

class WikiTemplateParser {
  late LangInfoLoader _langInfoLoader;
  // Craete a constructor that loads the langinf oject
  WikiTemplateParser() {
    _langInfoLoader = LangInfoLoader('./data/wikilang.csv');
    _langInfoLoader.loadLangInfo();
  }

  /// Parses the input text and returns the displayable text.
  String parse(String input, String language, String title) {
    // Remove comments
    String cleanedInput = _removeComments(input);

    // Remove references
    cleanedInput = _removeReferences(cleanedInput);

    // Further clean up the text (e.g., remove extra whitespace)
    cleanedInput = _cleanUpText(cleanedInput);

    // Parse the content and return the formatted output
    return _parseContent(cleanedInput, language, title);
  }

  /// Removes comments from the input text.
  String _removeComments(String content) {
    return content.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  }

  /// Removes references from the input text.
  String _removeReferences(String content) {
    return content.replaceAll(RegExp(r'<ref>.*?</ref>', dotAll: true), '');
  }

  /// Cleans up the text by removing extra whitespace and newlines.
  String _cleanUpText(String content) {
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

  /// Parses the {{lang-noun-m|...}} template and returns a formatted string.
  String parseLangNounTemplate(String template, String language, String title) {
    final regex =
        RegExp(r'\{\{(\w+)-noun-(m|f|n)?\|([^|]*)\|([^|]*)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "sq")
      String gender = match.group(2) ?? ''; // The gender (e.g., "m", "f", "n")
      String singular = match.group(3) ?? ''; // The singular form
      String plural = match.group(4) ?? ''; // The plural form
      String declension = match.group(5) ?? ''; // The declension

      String genderDisplay = _mapGenderToDisplay(gender);

      // Construct the display text
      return '$singular ($genderDisplay) - Plural: $plural, Declension: $declension';
    }

    return '';
  }

  /// Parses the {{lang-noun|...}} template generically for all language codes.
  String parseLangNounV2(String template, String language, String title) {
    final regex =
        RegExp(r'\{\{(\w+)-noun\|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\}\}');
    final match = regex.firstMatch(template);

    if (match != null) {
      String langCode = match.group(1) ?? ''; // The language code (e.g., "sq")
      String gender = match.group(2) ?? ''; // The gender (e.g., "m", "f", "n")
      String singular = match.group(3) ?? ''; // The singular form
      String plural = match.group(4) ?? ''; // The plural form
      String declension = match.group(5) ?? ''; // The declension

      String genderDisplay = _mapGenderToDisplay(gender);

      // Construct the display text in the specified format
      return '$singular $genderDisplay (plural $plural, definite $singular, definite plural $declension)';
    }

    return '';
  }

  String _mapGenderToDisplay(String gender) {
    return gender.isNotEmpty ? '$gender (${gender.toUpperCase()})' : '';
  }

  /// Chooses the appropriate parsing logic based on the content.
  String _chooseParsingLogic(String content, String language, String title) {
    if (content.contains('{{head|')) {
      return parseHeadTemplate(content, language, title);
    } else if (content.contains('{{alt|')) {
      return parseAltTemplate(content, language, title);
    } else if (content.contains('{{inflection of|')) {
      return parseInflectionTemplate(content, language, title);
    } else if (content.contains('{{bor|')) {
      return parseBorrowingTemplate(content, language, title);
    } else if (content.contains('{{ast-adj-mf|')) {
      return parseAstAdjMfTemplate(content, language, title);
    } else if (content.contains('{{IPA|')) {
      return parseIPATemplate(content, language, title);
    } else if (content.contains('{{rhyme|')) {
      return parseRhymeTemplate(content, language, title);
    } else if (content.contains('{{gloss|')) {
      return parseGlossTemplate(content, language, title);
    } else if (content.contains('{{cog|')) {
      return parseCogTemplate(content, language, title);
    } else if (RegExp(r'\{\{(\w+)-noun-(m|f|n)?\|').hasMatch(content)) {
      return parseLangNounTemplate(
          content, language, title); // Handle noun templates generically
    } else if (RegExp(r'\{\{(\w+)-noun\|').hasMatch(content)) {
      return parseLangNounV2(
          content, language, title); // Handle noun templates generically
    }
    // Add more conditions for other templates as needed

    return content; // Return the original content if no templates are matched
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

  /// Parses the {{rhyme|...}} template and returns a formatted string.
  String parseRhymeTemplate(String template, String language, String title) {
    final regex = RegExp(
        r'\{\{rhyme\|([^|]*)\|([^|]*)\|s=(\d+)\}\}'); // Updated regex to capture rhyme word and syllable count
    final match = regex.firstMatch(template);

    if (match != null) {
      String rhymeWord = match.group(2) ?? ''; // The rhyme word
      String syllableCount = match.group(3) ?? ''; // The syllable count
      return 'Rhymes: -$rhymeWord (syllables: $syllableCount)'; // Format as needed
    }

    return '';
  }

  /// Parses the {{gloss|...}} template and returns a formatted string.
  String parseGlossTemplate(String template, String language, String title) {
    final regex =
        RegExp(r'\{\{gloss\|([^}]*)\}\}'); // Regex to capture the gloss text
    final match = regex.firstMatch(template);

    if (match != null) {
      String glossText = match.group(1) ?? ''; // The gloss text
      return '($glossText)'; // Format as needed
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
      return '{{l|$langCode|$word}}'; // Format as needed
    }

    return '';
  }
}
