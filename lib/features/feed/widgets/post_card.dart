import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'like_button.dart';

class PostCard extends StatefulWidget {
  final String username;
  final List<String> images;
  final String caption;
  final int likes;

  const PostCard({
    super.key,
    required this.username,
    required this.images,
    required this.caption,
    required this.likes,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {

  bool liked = false;
  bool showHeart = false;
  int currentPage = 0;
  
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// HEADER DEL POST
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [

                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFEAEAEA),
                  child: Icon(
                    Icons.person,
                    size: 22,
                    color: Colors.black54,
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

                const Spacer(),

                const Icon(
                  Icons.more_horiz,
                  size: 22,
                ),
              ],
            ),
          ),

          /// IMAGEN / CAROUSEL
          Stack(
            alignment: Alignment.center,
            children: [

              GestureDetector(
                onDoubleTap: () {

                  setState(() {
                    liked = true;
                    showHeart = true;
                  });

                  Future.delayed(
                    const Duration(milliseconds: 700),
                    () {
                      if (mounted) {
                        setState(() {
                          showHeart = false;
                        });
                      }
                    },
                  );
                },

                child: SizedBox(
                  height: 320,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (index) {
                      setState(() {
                        currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {

                      return Image.network(
                        widget.images[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                      );
                    },
                  ),
                ),
              ),

              /// CORAZÓN ANIMADO
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: showHeart ? 1 : 0,
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 120,
                ),
              ),

              /// INDICADOR DE PÁGINAS
              if (widget.images.length > 1)
                Positioned(
                  bottom: 10,
                  child: Row(
                    children: List.generate(
                      widget.images.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: currentPage == index ? 8 : 6,
                        height: currentPage == index ? 8 : 6,
                        decoration: BoxDecoration(
                          color: currentPage == index
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

          /// ACCIONES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [

                LikeButton(
                  liked: liked,
                  onTap: () {
                    setState(() {
                      liked = !liked;
                    });
                  },
                ),

                const SizedBox(width: 18),

                Icon(
                  PhosphorIcons.chatCircle(),
                  size: 24,
                ),

                const SizedBox(width: 18),

                Icon(
                  PhosphorIcons.paperPlaneTilt(),
                  size: 24,
                ),

                const Spacer(),

                Icon(
                  PhosphorIcons.bookmarkSimple(),
                  size: 24,
                ),
              ],
            ),
          ),

          /// CONTADOR DE LIKES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              "${widget.likes + (liked ? 1 : 0)} likes",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 6),

          /// CAPTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 13,
                  height: 1.45,
                ),
                children: [

                  TextSpan(
                    text: "${widget.username} ",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  TextSpan(
                    text: widget.caption,
                  ),
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