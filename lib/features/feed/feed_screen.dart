import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _loadFeed(); /// ACÁ se ejecuta todo
  }

  Future<void> _loadFeed() async {

    try {
      /// 1. Obtener ubicación (tu servicio completo)
      final locationData = await LocationService.collect();

      /// 2. Obtener ciudad (GPS > IP)
      final city = (locationData.city ?? locationData.ipCity ?? "unknown")
          .trim()
          .toLowerCase();

      print("Ciudad detectada: $city");

      /// 3. Traer feed desde Firebase
      final data = await FeedService.getFeedByCity(city);

      /// 4. Guardar en estado
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
        slivers: [

          /// HEADER
          const SliverAppBar(
            floating: true,
            snap: true,
            elevation: 0,
            backgroundColor: Colors.white,
            toolbarHeight: 64,
            title: FeedHeader(),
          ),

          /// STORIES
          const SliverToBoxAdapter(
            child: StoriesBar(),
          ),

          /// LOADING
          if (isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          /// FEED REAL
          if (!isLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {

                  final item = feed[index];

                  if (item["type"] == "post") {
                    return PostCard(
                      username: item["username"],
                      images: List<String>.from(item["images"]),
                      caption: item["caption"],
                      likes: item["likes"],
                    );
                  }

                  if (item["type"] == "event") {
                    return EventCard(
                      title: item["title"],
                      location: item["location"],
                      date: item["date"],
                    );
                  }

                  return const SizedBox();
                },
                childCount: feed.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),

      bottomNavigationBar: const BottomNav(),
    );
  }
}