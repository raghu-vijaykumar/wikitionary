import 'dart:io';

class LanguageInfo {
  final String line;
  final String code;
  final String canonicalName;
  final String category;
  final String type;
  final String familyCode;
  final String family;
  final String sortKey;
  final String autodetect;
  final String exceptional;
  final String scriptCodes;
  final String otherNames;
  final String standardCharacters;

  LanguageInfo({
    required this.line,
    required this.code,
    required this.canonicalName,
    required this.category,
    required this.type,
    required this.familyCode,
    required this.family,
    required this.sortKey,
    required this.autodetect,
    required this.exceptional,
    required this.scriptCodes,
    required this.otherNames,
    required this.standardCharacters,
  });

  @override
  String toString() {
    return 'LanguageInfo(code: $code, name: $canonicalName)';
  }
}

class LangInfoLoader {
  final String filePath;
  List<LanguageInfo>? _languages; // Cache the loaded languages

  LangInfoLoader(this.filePath);

  List<LanguageInfo> loadLangInfo() {
    if (_languages != null)
      return _languages!; // Return cached languages if already loaded

    final List<LanguageInfo> languages = [];
    final file = File(filePath);

    // Read the file line by line
    final lines = file.readAsLinesSync();

    // Skip the header and parse each line
    for (var i = 1; i < lines.length; i++) {
      final fields = lines[i].split(';');
      if (fields.length == 13) {
        languages.add(LanguageInfo(
          line: fields[0],
          code: fields[1],
          canonicalName: fields[2],
          category: fields[3],
          type: fields[4],
          familyCode: fields[5],
          family: fields[6],
          sortKey: fields[7],
          autodetect: fields[8],
          exceptional: fields[9],
          scriptCodes: fields[10],
          otherNames: fields[11],
          standardCharacters: fields[12],
        ));
      }
    }

    _languages = languages; // Cache the loaded languages
    return languages;
  }

  String? getLangCodeByCanonicalName(String canonicalName) {
    // Load languages if not already loaded
    loadLangInfo();

    // Find the language code for the given lowercase canonical name
    final langInfo = _languages!.firstWhere(
      (lang) => lang.canonicalName.toLowerCase() == canonicalName.toLowerCase(),
      orElse: () => LanguageInfo(
        line: '',
        code: '',
        canonicalName: '',
        category: '',
        type: '',
        familyCode: '',
        family: '',
        sortKey: '',
        autodetect: '',
        exceptional: '',
        scriptCodes: '',
        otherNames: '',
        standardCharacters: '',
      ),
    );

    return langInfo.code; // Return the language code or null if not found
  }

  String? getNameByLangCode(String language) {
    // Load languages if not already loaded
    loadLangInfo();

    final langInfo = _languages!.firstWhere(
      (lang) => lang.code == language,
    );
    return langInfo.canonicalName;
  }
}
