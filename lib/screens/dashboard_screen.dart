import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _displayName;
  String? _email;

  // lists of items for per-item progress
  List<Map<String, dynamic>> animeList = [];
  List<Map<String, dynamic>> webtoonList = [];

  // genre counts for pie chart
  Map<String, int> genreCounts = {};

  bool showAllAnime = false;
  bool showAllWebtoons = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initUser();
    _loadData();
  }

  Future<void> _initUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _email = user.email;
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      setState(() => _displayName = user.displayName);
      return;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists && doc.data() != null && doc.data()!['username'] != null) {
      setState(() => _displayName = doc.data()!['username'] as String);
      return;
    }

    setState(() => _displayName = user.email?.split('@').first ?? 'User');
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final Map<String, int> genres = {};
    final List<Map<String, dynamic>> anime = [];
    final List<Map<String, dynamic>> webtoons = [];

    // -- ANIME: collection name is "anime_list" (matches your Anime screen)
    final animeSnapshot = await FirebaseFirestore.instance
        .collection("anime_list")
        .get();
    for (var doc in animeSnapshot.docs) {
      final raw = doc.data();
      // if doc has uid, only include docs that belong to current user
      if (raw.containsKey('uid') && raw['uid'] != user.uid) continue;

      final title = (raw['title'] ?? 'Untitled').toString();
      final current = (raw['currentEpisode'] as num?)?.toInt() ?? 0;
      // account for possible different naming (totalEpisode or totalEpisodes)
      final total =
          (raw['totalEpisode'] as num?)?.toInt() ??
          (raw['totalEpisodes'] as num?)?.toInt() ??
          0;

      // genres can be stored as List<dynamic> or single string — handle both
      if (raw.containsKey('genres') && raw['genres'] is List) {
        final list = List.from(raw['genres']);
        for (var g in list) {
          final gs = g.toString();
          genres[gs] = (genres[gs] ?? 0) + 1;
        }
      } else if (raw.containsKey('genre')) {
        // fallback if you used 'genre' string
        final gs = raw['genre'].toString();
        genres[gs] = (genres[gs] ?? 0) + 1;
      }

      anime.add({'title': title, 'current': current, 'total': total});
    }

    // -- WEBTOONS: collection name is "webtoons" (matches your Webtoon screen)
    final webtoonSnapshot = await FirebaseFirestore.instance
        .collection("webtoons")
        // some docs have uid — use filter server-side if present (but we still double-check below)
        .get();
    for (var doc in webtoonSnapshot.docs) {
      final raw = doc.data();
      if (raw.containsKey('uid') && raw['uid'] != user.uid) continue;

      final title = (raw['title'] ?? 'Untitled').toString();
      final current = (raw['currentChapter'] as num?)?.toInt() ?? 0;
      final total = (raw['totalChapter'] as num?)?.toInt() ?? 0;

      if (raw.containsKey('genre')) {
        final gs = raw['genre'].toString();
        genres[gs] = (genres[gs] ?? 0) + 1;
      }

      webtoons.add({'title': title, 'current': current, 'total': total});
    }

    //ascending order
    setState(() {
      animeList = anime;
      webtoonList = webtoons;
      genreCounts = genres;
      _loading = false;
    });
  }

  Widget _buildClickableCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
    Color? color, // 👈 new optional color parameter
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color:
            color ?? Colors.deepPurple[800], // 👈 fallback if no color is given
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 25,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard({
    required String title,
    required List<Map<String, dynamic>> items,
    required bool expanded,
    required VoidCallback toggleExpanded,
    required Color color,
  }) {
    if (items.isEmpty) {
      return Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "No $title yet.",
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final toShow = expanded ? items : items.take(3).toList();

    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            ...toShow.map((item) {
              final current = (item['current'] as int?) ?? 0;
              final total = (item['total'] as int?) ?? 0;
              final progress = total > 0
                  ? (current / total).clamp(0.0, 1.0)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      color: color,
                      backgroundColor: Colors.grey[800],
                      minHeight: 8,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$current / $total",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (items.length > 3)
              TextButton(
                onPressed: toggleExpanded,
                child: Text(
                  expanded ? "Show less" : "Show more",
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreChart() {
    if (genreCounts.isEmpty) {
      return const Text(
        "No genre data yet.",
        style: TextStyle(color: Colors.white70),
      );
    }

    final total = genreCounts.values.fold<int>(0, (p, n) => p + n);
    final entries = genreCounts.entries.toList();

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final value = entry.value.toDouble();
      final color = Colors.primaries[i % Colors.primaries.length];
      final percentage = total > 0 ? (entry.value / total) * 100 : 0.0;

      sections.add(
        PieChartSectionData(
          value: value,
          title: "${entry.key} (${percentage.toStringAsFixed(1)}%)",
          color: color,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF9333EA),
        title: const Text(
          "Anime Tracker",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: Color(0xFF9333EA),
              icon: const Icon(
                Icons.account_circle,
                color: Colors.white,
                size: 30,
              ),
              items: const [
                DropdownMenuItem(
                  value: "profile",
                  child: Text("Profile", style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: "logout",
                  child: Text("Logout", style: TextStyle(color: Colors.white)),
                ),
              ],
              onChanged: (value) {
                if (value == "profile") {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Profile feature coming soon!"),
                    ),
                  );
                } else if (value == "logout") {
                  _signOut();
                }
              },
              hint: Text(
                _displayName ?? "User",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildClickableCard(
                icon: Icons.tv,
                title: "Anime List",
                description:
                    "Keep track of all the anime you’re currently watching and what’s next in your queue.",
                onTap: () {
                  Navigator.pushNamed(context, '/anime-list');
                },
                color: Colors.purple,
              ),
              const SizedBox(height: 20),
              _buildClickableCard(
                icon: Icons.menu_book,
                title: "Webtoon List",
                description:
                    "Organize and track the webtoons you’re reading, with updates on your progress.",
                onTap: () {
                  Navigator.pushNamed(context, '/webtoon-list');
                },
                color: Colors.green,
              ),
              const SizedBox(height: 30),

              // Anime per-item progress (shows up to 3, expandable)
              _loading
                  ? const Card(
                      color: Colors.grey,
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  : _buildListCard(
                      title: "Anime Watching Progress",
                      items: animeList,
                      expanded: showAllAnime,
                      toggleExpanded: () =>
                          setState(() => showAllAnime = !showAllAnime),
                      color: Colors.purple,
                    ),

              // Webtoon per-item progress
              _buildListCard(
                title: "Webtoon Reading Progress",
                items: webtoonList,
                expanded: showAllWebtoons,
                toggleExpanded: () =>
                    setState(() => showAllWebtoons = !showAllWebtoons),
                color: Colors.green,
              ),

              const SizedBox(height: 30),

              const Text(
                "Your Genres",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildGenreChart(),
            ],
          ),
        ),
      ),
    );
  }
}
