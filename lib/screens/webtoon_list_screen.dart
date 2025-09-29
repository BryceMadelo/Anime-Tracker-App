import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebtoonListScreen extends StatefulWidget {
  const WebtoonListScreen({super.key});

  @override
  State<WebtoonListScreen> createState() => _WebtoonListScreenState();
}

class _WebtoonListScreenState extends State<WebtoonListScreen> {
  final user = FirebaseAuth.instance.currentUser;

  final _titleController = TextEditingController();
  final _genreController = TextEditingController();
  final _currentChapterController = TextEditingController();
  final _totalChapterController = TextEditingController();
  String _status = "Reading";

  Future<void> _addOrUpdateWebtoon({String? docId}) async {
    final title = _titleController.text.trim();
    final genre = _genreController.text.trim();
    final current = int.tryParse(_currentChapterController.text.trim()) ?? 0;
    final total = int.tryParse(_totalChapterController.text.trim()) ?? 0;

    if (title.isEmpty || genre.isEmpty) return;

    final data = {
      "title": title,
      "genre": genre,
      "currentChapter": current,
      "totalChapter": total,
      "status": _status,
      "uid": user!.uid,
      "timestamp": FieldValue.serverTimestamp(),
    };

    final collection = FirebaseFirestore.instance.collection("webtoons");

    if (docId == null) {
      await collection.add(data);
    } else {
      await collection.doc(docId).update(data);
    }

    _titleController.clear();
    _genreController.clear();
    _currentChapterController.clear();
    _totalChapterController.clear();
    _status = "Reading";
    Navigator.pop(context);
  }

  void _showForm({DocumentSnapshot? doc}) {
    if (doc != null) {
      _titleController.text = doc["title"];
      _genreController.text = doc["genre"];
      _currentChapterController.text = doc["currentChapter"].toString();
      _totalChapterController.text = doc["totalChapter"].toString();
      _status = doc["status"];
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? "Add Webtoon" : "Edit Webtoon"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: _genreController,
                decoration: const InputDecoration(labelText: "Genre"),
              ),
              TextField(
                controller: _currentChapterController,
                decoration: const InputDecoration(labelText: "Current Chapter"),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _totalChapterController,
                decoration: const InputDecoration(labelText: "Total Chapters"),
                keyboardType: TextInputType.number,
              ),
              DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: "Reading", child: Text("Reading")),
                  DropdownMenuItem(
                    value: "Completed",
                    child: Text("Completed"),
                  ),
                  DropdownMenuItem(
                    value: "Plan to Read",
                    child: Text("Plan to Read"),
                  ),
                ],
                onChanged: (val) => setState(() => _status = val!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => _addOrUpdateWebtoon(docId: doc?.id),
            child: Text(doc == null ? "Add" : "Update"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWebtoon(String docId) async {
    await FirebaseFirestore.instance.collection("webtoons").doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Webtoon List"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("webtoons")
            .where("uid", isEqualTo: user!.uid)
            .orderBy("timestamp", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No Webtoons added yet.",
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(
              top: 20.0,
              left: 12.0,
              right: 12.0,
              bottom: 12.0,
            ),
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                color: const Color.fromARGB(255, 49, 61, 49),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    data["title"],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Genre: ${data['genre']}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        "Progress: ${data['currentChapter']}/${data['totalChapter']} chapters",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        "Status: ${data['status']}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showForm(doc: doc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteWebtoon(doc.id),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
      backgroundColor: Colors.black,
    );
  }
}
