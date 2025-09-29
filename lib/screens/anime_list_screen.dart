import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AnimeListScreen extends StatefulWidget {
  const AnimeListScreen({super.key});

  @override
  State<AnimeListScreen> createState() => _AnimeListScreenState();
}

class _AnimeListScreenState extends State<AnimeListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  final CollectionReference _animeCollection = FirebaseFirestore.instance
      .collection('anime_list');

  Future<void> _searchAnime(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final url = "https://api.jikan.moe/v4/anime?q=$query&limit=5";
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        _searchResults = data['data'] ?? [];
      });
    }
  }

  Future<void> _addAnime(Map<String, dynamic> anime) async {
    // collect all genres into a list of strings
    final List<String> genres = (anime['genres'] as List)
        .map((g) => g['name'] as String)
        .toList();

    await _animeCollection.add({
      'title': anime['title'],
      'cover': anime['images']['jpg']['image_url'],
      'genres': genres,
      'currentEpisode': 1,
      'totalEpisode': anime['episodes'] ?? 0,
      'status': 'Watching',
    });

    // clear both the search results AND the text field
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
  }

  Future<void> _updateAnime(
    String docId,
    Map<String, dynamic> updatedData,
  ) async {
    await _animeCollection.doc(docId).update(updatedData);
  }

  Future<void> _deleteAnime(String docId) async {
    await _animeCollection.doc(docId).delete();
  }

  void _showEditDialog(String docId, Map<String, dynamic> anime) {
    final currentController = TextEditingController(
      text: anime['currentEpisode'].toString(),
    );
    final totalController = TextEditingController(
      text: anime['totalEpisode'].toString(),
    );
    String status = anime['status'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Anime"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              decoration: const InputDecoration(labelText: "Current Episode"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: totalController,
              decoration: const InputDecoration(labelText: "Total Episodes"),
              keyboardType: TextInputType.number,
            ),
            DropdownButton<String>(
              value: status,
              onChanged: (val) {
                if (val != null) {
                  setState(() => status = val);
                }
              },
              items: [
                "Watching",
                "Completed",
                "Plan to Watch",
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              _updateAnime(docId, {
                'currentEpisode': int.tryParse(currentController.text) ?? 1,
                'totalEpisode': int.tryParse(totalController.text) ?? 0,
                'status': status,
              });
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.purple,
        title: const Text("Anime List", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // search bar
          Padding(
            padding: const EdgeInsets.only(
              top: 20.0,
              left: 8.0,
              right: 8.0,
              bottom: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search Anime",
                hintStyle: const TextStyle(color: Colors.white70),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () => _searchAnime(_searchController.text),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: _searchAnime,
            ),
          ),

          // search results
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final anime = _searchResults[index];
                  final genres = (anime['genres'] as List)
                      .map((g) => g['name'])
                      .join(', ');
                  return ListTile(
                    leading: Image.network(anime['images']['jpg']['image_url']),
                    title: Text(
                      anime['title'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      genres.isNotEmpty ? genres : "Unknown",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add, color: Colors.green),
                      onPressed: () => _addAnime(anime),
                    ),
                  );
                },
              ),
            ),

          // saved anime list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _animeCollection.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final docs = snapshot.data!.docs;
                return ListView(
                  children: docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final genres =
                        (data['genres'] as List<dynamic>?)?.join(', ') ??
                        "Unknown";
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15.0,
                        vertical: 8.0,
                      ),
                      child: Card(
                        color: const Color.fromARGB(255, 54, 44, 85),
                        child: ListTile(
                          leading: Image.network(data['cover'], width: 50),
                          title: Text(
                            data['title'],
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            "$genres • ${data['currentEpisode']}/${data['totalEpisode']} • ${data['status']}",
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.yellow,
                                ),
                                onPressed: () => _showEditDialog(doc.id, data),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteAnime(doc.id),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
