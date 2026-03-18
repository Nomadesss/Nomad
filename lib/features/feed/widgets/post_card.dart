import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'like_button.dart';
import 'comments_screen.dart';
import 'user_profile_trigger.dart';
import 'user_profile_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PostCard — tarjeta de publicación conectada a Firebase.
//
// Cambios respecto a la versión anterior:
//  - postId y postAuthorId son ahora campos requeridos
//  - LikeButton delega todo a SocialService (likes reales)
//  - El ícono de comentario abre CommentsScreen
//  - El avatar/nombre usa UserProfileTrigger (popover/bottomsheet)
//  - El campo "likes" como int ya no es necesario (viene del stream)
// ─────────────────────────────────────────────────────────────────────────────

class PostCard extends StatefulWidget {
  final String postId;
  final String postAuthorId;
  final String username;
  final List<String> images;
  final String caption;

  // Datos opcionales para el popover de perfil
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
                    username:     widget.username,
                    fullName:     widget.username,
                    countryFlag:  widget.userCountryFlag,
                    city:         widget.userCity,
                    bio:          widget.userBio,
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
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
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

              // Corazón animado al hacer doble tap
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: showHeart ? 1 : 0,
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 120,
                ),
              ),

              // Indicador de páginas
              if (widget.images.length > 1)
                Positioned(
                  bottom: 10,
                  child: Row(
                    children: List.generate(
                      widget.images.length,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width:  currentPage == i ? 8 : 6,
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
                  postId:       widget.postId,
                  postAuthorId: widget.postAuthorId,
                ),

                const SizedBox(width: 18),

                // Comentario → abre CommentsScreen
                GestureDetector(
                  onTap: () => CommentsScreen.show(
                    context,
                    postId:       widget.postId,
                    postAuthorId: widget.postAuthorId,
                  ),
                  child: Icon(
                    PhosphorIcons.chatCircle(),
                    size: 24,
                    color: const Color(0xFF134E4A),
                  ),
                ),

                const SizedBox(width: 18),

                Icon(
                  PhosphorIcons.paperPlaneTilt(),
                  size: 24,
                  color: const Color(0xFF134E4A),
                ),

                const Spacer(),

                Icon(
                  PhosphorIcons.bookmarkSimple(),
                  size: 24,
                  color: const Color(0xFF134E4A),
                ),
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