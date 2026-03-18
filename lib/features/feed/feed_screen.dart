import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import '../../services/seed_posts.dart';

import 'widgets/feed_header.dart';
import 'widgets/stories_bar.dart';
import 'widgets/post_card.dart';
import 'widgets/event_card.dart';
import 'widgets/bottom_nav.dart';

import '../../services/location_service.dart';
import '../../services/feed_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Map<String, dynamic>> feed = [];
  bool isLoading = true;

  final ScrollController _scrollController = ScrollController();

  bool _showBottomBar = true;
  bool _showHeader = true;

  @override
  void initState() {
    super.initState();
    SeedPosts.run();
    _loadFeed();

    _scrollController.addListener(() {
      final direction = _scrollController.position.userScrollDirection;

      /// SCROLL HACIA ABAJO
      if (direction == ScrollDirection.reverse) {
        if (_showBottomBar || _showHeader) {
          setState(() {
            _showBottomBar = false;
            _showHeader = false;
          });
        }
      }
      /// SCROLL HACIA ARRIBA
      else if (direction == ScrollDirection.forward) {
        if (!_showBottomBar || !_showHeader) {
          setState(() {
            _showBottomBar = true;
            _showHeader = true;
          });
        }
      }
    });
  }

  /// 🔥 EVITA MEMORY LEAK (IMPORTANTE)
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    try {
      final locationData = await LocationService.collect();

      final city = (locationData.city ?? locationData.ipCity ?? "unknown")
          .trim()
          .toLowerCase();

      print("Ciudad detectada: $city");

      final userId = FirebaseAuth.instance.currentUser!.uid;

      final data = await FeedService.getFeed(city, userId);

      setState(() {
        feed = data;
        isLoading = false;
      });
    } catch (e) {
      print("Error cargando feed: $e");

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          /// 🔥 HEADER ANIMADO (TIPO INSTAGRAM)
          SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: Colors.white,
            toolbarHeight: _showHeader ? 64 : 0,
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showHeader ? 1 : 0,
              child: const FeedHeader(),
            ),
          ),

          /// STORIES
          const SliverToBoxAdapter(child: StoriesBar()),

          /// LOADING
          if (isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          /// FEED
          if (!isLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = feed[index];

                if (item["type"] == "post") {
                  final docId = item["docId"] as String? ?? "";
                  final authorId = item["authorId"] as String? ?? "";
                  if (docId.isEmpty) return const SizedBox.shrink();
                  return PostCard(
                    postId: docId,
                    postAuthorId: authorId,
                    username: item["username"] as String? ?? "usuario",
                    images: List<String>.from(item["images"] ?? []),
                    caption: item["caption"] as String? ?? "",
                    userCountryFlag: item["countryFlag"] as String?,
                    userCity: item["city"] as String?,
                    userBio: item["bio"] as String?,
                  );
                }

                if (item["type"] == "event") {
                  return EventCard(
                    title: item["title"] as String? ?? "",
                    location: item["location"] as String? ?? "",
                    date: item["date"] as String? ?? "",
                  );
                }

                return const SizedBox();
              }, childCount: feed.length),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),

      /// BOTTOM BAR ANIMADO
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _showBottomBar ? Offset.zero : const Offset(0, 1),
        child: const BottomNav(),
      ),
    );
  }
}
