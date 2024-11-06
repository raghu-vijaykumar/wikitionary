import 'dart:convert';
import 'dart:io';

class TrieNode {
  Map<String, TrieNode> children = {};
  bool isEndOfWord = false;

  // Convert the TrieNode to a Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'isEndOfWord': isEndOfWord,
      'children': children.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  // Create a TrieNode from a Map for JSON deserialization
  static TrieNode fromJson(Map<String, dynamic> json) {
    TrieNode node = TrieNode();
    node.isEndOfWord = json['isEndOfWord'];
    json['children'].forEach((key, value) {
      node.children[key] = TrieNode.fromJson(value);
    });
    return node;
  }
}

class Trie {
  TrieNode root = TrieNode();

  void insert(String word) {
    TrieNode current = root;
    for (var char in word.split('')) {
      if (!current.children.containsKey(char)) {
        current.children[char] = TrieNode();
      }
      current = current.children[char]!;
    }
    current.isEndOfWord = true;
  }

  bool search(String word) {
    TrieNode current = root;
    for (var char in word.split('')) {
      if (!current.children.containsKey(char)) {
        return false;
      }
      current = current.children[char]!;
    }
    return current.isEndOfWord;
  }

  List<String> autocomplete(String prefix) {
    TrieNode current = root;
    for (var char in prefix.split('')) {
      if (!current.children.containsKey(char)) {
        return [];
      }
      current = current.children[char]!;
    }
    return _findAllWords(current, prefix);
  }

  List<String> _findAllWords(TrieNode node, String prefix) {
    List<String> words = [];
    if (node.isEndOfWord) {
      words.add(prefix);
    }
    node.children.forEach((char, childNode) {
      words.addAll(_findAllWords(childNode, prefix + char));
    });
    return words;
  }

  // Serialize the trie to a JSON file
  Future<void> saveToJsonFile(String filePath) async {
    final file = File(filePath);
    final jsonData = jsonEncode(root.toJson());
    await file.writeAsString(jsonData);
  }

  // Load the trie from a JSON file
  static Future<Trie> loadFromJsonFile(String filePath) async {
    final file = File(filePath);
    final jsonData = await file.readAsString();
    return _deserializeFromJson(jsonDecode(jsonData));
  }

  static Trie _deserializeFromJson(Map<String, dynamic> json) {
    Trie trie = Trie();
    trie.root = TrieNode.fromJson(json);
    return trie;
  }
}
