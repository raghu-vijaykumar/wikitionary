import 'dart:io';

class CompressedTrieNode {
  Map<String, CompressedTrieNode> children = {};
  bool isEndOfWord = false;

  // Store the key for this node
  String key;

  CompressedTrieNode(this.key);
}

class CompressedTrie {
  final CompressedTrieNode root = CompressedTrieNode('');

  void insert(String word) {
    CompressedTrieNode current = root;
    String remaining = word;

    while (remaining.isNotEmpty) {
      bool found = false;

      // Check for existing children
      for (var entry in current.children.entries) {
        String childKey = entry.key;
        CompressedTrieNode childNode = entry.value;

        // Check if the child key matches the beginning of the remaining word
        if (remaining.startsWith(childKey)) {
          current = childNode;
          remaining = remaining.substring(childKey.length);
          found = true;
          break;
        } else if (childKey.startsWith(remaining)) {
          // Split the node if the remaining word is a prefix of the child key
          var newChild =
              CompressedTrieNode(childKey.substring(remaining.length));
          newChild.children.addAll(childNode.children);
          newChild.isEndOfWord = childNode.isEndOfWord;

          childNode.key = childKey.substring(0, remaining.length);
          childNode.children.clear();
          childNode.children[newChild.key] = newChild;

          current = childNode;
          remaining = '';
          found = true;
          break;
        }
      }

      // If no matching child is found, create a new child node
      if (!found) {
        current.children[remaining] = CompressedTrieNode(remaining);
        current.children[remaining]!.isEndOfWord = true;
        break;
      }
    }

    current.isEndOfWord = true;
  }

  bool search(String word) {
    CompressedTrieNode current = root;
    String remaining = word;

    while (remaining.isNotEmpty) {
      bool found = false;

      for (var entry in current.children.entries) {
        String childKey = entry.key;
        CompressedTrieNode childNode = entry.value;

        if (remaining.startsWith(childKey)) {
          current = childNode;
          remaining = remaining.substring(childKey.length);
          found = true;
          break;
        }
      }

      if (!found) {
        return false; // No matching child found
      }
    }

    return current.isEndOfWord;
  }

  List<String> autocomplete(String prefix) {
    CompressedTrieNode current = root;
    String remaining = prefix;

    while (remaining.isNotEmpty) {
      bool found = false;

      for (var entry in current.children.entries) {
        String childKey = entry.key;
        CompressedTrieNode childNode = entry.value;

        if (remaining.startsWith(childKey)) {
          current = childNode;
          remaining = remaining.substring(childKey.length);
          found = true;
          break;
        }
      }

      if (!found) {
        return []; // No matching prefix found
      }
    }

    return _findAllWords(current, prefix);
  }

  List<String> _findAllWords(CompressedTrieNode node, String prefix) {
    List<String> words = [];
    if (node.isEndOfWord) {
      words.add(prefix);
    }
    node.children.forEach((key, childNode) {
      words.addAll(_findAllWords(childNode, prefix + key));
    });
    return words;
  }

  // Serialize the compressed trie to a file
  Future<void> saveToFile(String filePath) async {
    final file = File(filePath);
    final data = _serialize(root);
    await file.writeAsString(data);
  }

  String _serialize(CompressedTrieNode node) {
    StringBuffer buffer = StringBuffer();
    _serializeNode(node, buffer);
    return buffer.toString();
  }

  void _serializeNode(CompressedTrieNode node, StringBuffer buffer) {
    buffer.write(node.isEndOfWord ? '1' : '0');
    buffer.write(node.key.length);
    buffer.write(node.key);
    buffer.write(node.children.length);
    for (var entry in node.children.entries) {
      _serializeNode(entry.value, buffer);
    }
  }

  // Load the compressed trie from a file
  static Future<CompressedTrie> loadFromFile(String filePath) async {
    final file = File(filePath);
    final data = await file.readAsString();
    return _deserialize(data);
  }

  static CompressedTrie _deserialize(String data) {
    CompressedTrie trie = CompressedTrie();
    int index = 0;
    _deserializeNode(trie.root, data, index);
    return trie;
  }

  static void _deserializeNode(
      CompressedTrieNode node, String data, int index) {
    node.isEndOfWord = data[index++] == '1';
    int keyLength = int.parse(data[index++].toString());
    node.key = data.substring(index, index + keyLength);
    index += keyLength;
    int childrenCount = int.parse(data[index++].toString());
    for (int i = 0; i < childrenCount; i++) {
      CompressedTrieNode childNode = CompressedTrieNode('');
      node.children[childNode.key] = childNode;
      _deserializeNode(childNode, data, index);
    }
  }
}
