import 'dart:io';

class TrieNode {
  Map<String, TrieNode> children = {};
  bool isEndOfWord = false;
}

class Trie {
  final TrieNode root = TrieNode();

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

  // Serialize the trie to a file
  Future<void> saveToFile(String filePath) async {
    final file = File(filePath);
    final data = _serialize(root);
    await file.writeAsString(data);
  }

  String _serialize(TrieNode node) {
    StringBuffer buffer = StringBuffer();
    _serializeNode(node, buffer);
    return buffer.toString();
  }

  void _serializeNode(TrieNode node, StringBuffer buffer) {
    if (node.isEndOfWord) {
      buffer.write('1');
    } else {
      buffer.write('0');
    }
    buffer.write(node.children.length);
    for (var entry in node.children.entries) {
      buffer.write(entry.key);
      _serializeNode(entry.value, buffer);
    }
  }

  // Load the trie from a file
  static Future<Trie> loadFromFile(String filePath) async {
    final file = File(filePath);
    final data = await file.readAsString();
    return _deserialize(data);
  }

  static Trie _deserialize(String data) {
    Trie trie = Trie();
    int index = 0;
    _deserializeNode(trie.root, data, index);
    return trie;
  }

  static void _deserializeNode(TrieNode node, String data, int index) {
    node.isEndOfWord = data[index++] == '1';
    int childrenCount = int.parse(data[index++].toString());
    for (int i = 0; i < childrenCount; i++) {
      String char = data[index++];
      TrieNode childNode = TrieNode();
      node.children[char] = childNode;
      _deserializeNode(childNode, data, index);
    }
  }
}
