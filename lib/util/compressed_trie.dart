import 'dart:convert';
import 'dart:io';

class CompressedTrieNode {
  Map<String, CompressedTrieNode> children = {};
  bool isEndOfWord = false;
  String key; // The key for this node

  CompressedTrieNode(this.key);

  // Convert the CompressedTrieNode to a Map for JSON serialization
  Map<String, dynamic> toJson() {
    return {
      'isEndOfWord': isEndOfWord,
      'key': key,
      'children': children.map((key, value) => MapEntry(key, value.toJson())),
    };
  }

  // Create a CompressedTrieNode from a Map for JSON deserialization
  static CompressedTrieNode fromJson(Map<String, dynamic> json) {
    CompressedTrieNode node = CompressedTrieNode(json['key']);
    node.isEndOfWord = json['isEndOfWord'];
    json['children'].forEach((key, value) {
      node.children[key] = CompressedTrieNode.fromJson(value);
    });
    return node;
  }
}

class CompressedTrie {
  CompressedTrieNode root = CompressedTrieNode('');

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
          // If it matches completely, move to the child node
          current = childNode;
          remaining = remaining.substring(childKey.length);
          found = true;
          break;
        } else if (childKey.startsWith(remaining)) {
          // If the remaining word is a prefix of the child key, split the node
          var newChild =
              CompressedTrieNode(childKey.substring(remaining.length));
          newChild.children.addAll(childNode.children);
          newChild.isEndOfWord = childNode.isEndOfWord;

          childNode.key = remaining; // Update the child node's key
          childNode.children.clear(); // Clear the children of the old node
          childNode.children[newChild.key] = newChild; // Add the new child

          current = childNode; // Move to the new child
          remaining = ''; // We are done inserting
          found = true;
          break;
        }
      }

      // If no matching child was found, create a new child node
      if (!found) {
        current.children[remaining] = CompressedTrieNode(remaining);
        current.children[remaining]!.isEndOfWord = true;
        break;
      }
    }
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
      words.add(prefix + node.key);
    }
    node.children.forEach((key, childNode) {
      words.addAll(_findAllWords(childNode, prefix + key));
    });
    return words;
  }

  // Serialize the compressed trie to a JSON file
  Future<void> saveToJsonFile(String filePath) async {
    final file = File(filePath);
    final jsonData = jsonEncode(root.toJson());
    await file.writeAsString(jsonData);
  }

  // Load the compressed trie from a JSON file
  static Future<CompressedTrie> loadFromJsonFile(String filePath) async {
    final file = File(filePath);
    final jsonData = await file.readAsString();
    return _deserializeFromJson(jsonDecode(jsonData));
  }

  static CompressedTrie _deserializeFromJson(Map<String, dynamic> json) {
    CompressedTrie trie = CompressedTrie();
    trie.root = CompressedTrieNode.fromJson(json);
    return trie;
  }
}
