import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'like_button.dart';
import 'save_button.dart';
import 'share_sheet.dart'; // ← nuevo import
import 'comments_screen.dart';
import 'user_profile_trigger.dart';
import 'user_profile_card.dart';
import '../../../services/social_service.dart';

class PostCard extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String username;
  final List<String> images;
  final String caption;

  final String? userCountryFlag;
  final String? userCity;
  final String? userBio;

  const PostCard({
    super.key,
    required this.postId,
    required this.postAuthorId,
    required this.username,
    required this.images,
    required this.caption,
    this.userCountryFlag,
    this.userCity,
    this.userBio,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool showHeart = false;
  int currentPage = 0;
  final PageController _pageController = PageController();

  void _onDoubleTap() {
    setState(() => showHeart = true);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header del post ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                UserProfileTrigger(
                  user: UserProfileData(
                    username: widget.username,
                    fullName: widget.username,
                    countryFlag: widget.userCountryFlag,
                    city: widget.userCity,
                    bio: widget.userBio,
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFFCCFBF1),
                        child: Icon(
                          Icons.person,
                          size: 22,
                          color: Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF134E4A),
                            ),
                          ),
                          const Text(
                            "Hace 2 h",
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                const Icon(Icons.more_horiz, size: 22),
              ],
            ),
          ),

          // ── Imagen / Carousel ─────────────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onDoubleTap: _onDoubleTap,
                child: SizedBox(
                  height: 320,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (i) => setState(() => currentPage = i),
                    itemBuilder: (_, i) => Image.network(
                      widget.images[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: showHeart ? 1 : 0,
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 120,
                ),
              ),
              if (widget.images.length > 1)
                Positioned(
                  bottom: 10,
                  child: Row(
                    children: List.generate(
                      widget.images.length,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: currentPage == i ? 8 : 6,
                        height: currentPage == i ? 8 : 6,
                        decoration: BoxDecoration(
                          color: currentPage == i
                              ? Colors.white
                              : Colors.white54,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Acciones ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Like conectado a Firestore
                LikeButton(
                  postId: widget.postId,
                  postAuthorId: widget.postAuthorId,
                ),

                const SizedBox(width: 18),

                // Comentarios con conteo real desde Firestore
                StreamBuilder<int>(
                  stream: SocialService.commentsCountStream(widget.postId),
                  builder: (context, snap) {
                    final count = snap.data ?? 0;
                    return GestureDetector(
                      onTap: () => CommentsScreen.show(
                        context,
                        postId: widget.postId,
                        postAuthorId: widget.postAuthorId,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIcons.chatCircle(),
                            size: 24,
                            color: const Color(0xFF134E4A),
                          ),
                          const SizedBox(width: 5),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              '$count',
                              key: ValueKey(count),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF134E4A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(width: 18),

                // ── Compartir → abre ShareSheet ───────────────────────────
                GestureDetector(
                  onTap: () => ShareSheet.show(
                    context,
                    postId: widget.postId,
                    username: widget.username,
                  ),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      PhosphorIcons.paperPlaneTilt(),
                      size: 24,
                      color: const Color(0xFF134E4A),
                    ),
                  ),
                ),

                const Spacer(),

                // Guardar conectado a Firestore
                SaveButton(postId: widget.postId),
              ],
            ),
          ),

          // ── Caption ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF134E4A),
                  fontSize: 13,
                  height: 1.45,
                ),
                children: [
                  TextSpan(
                    text: "${widget.username} ",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: widget.caption),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }
}
