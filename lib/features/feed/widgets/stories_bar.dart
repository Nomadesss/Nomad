import 'package:flutter/material.dart';

class StoriesBar extends StatelessWidget {
  const StoriesBar({super.key});

  @override
  Widget build(BuildContext context) {

    final List<Map<String, dynamic>> stories = [
      {"name": "Mi historia", "isCreate": true},
      {"name": "Carlos", "viewed": false},
      {"name": "Sofía", "viewed": true},
      {"name": "Lucas", "viewed": false},
      {"name": "Valentina", "viewed": true},
      {"name": "Andrés", "viewed": false},
    ];

    /// ORDENAR HISTORIAS
    stories.sort((a, b) {

      final aCreate = (a["isCreate"] as bool?) ?? false;
      final bCreate = (b["isCreate"] as bool?) ?? false;

      /// Mi historia siempre primero
      if (aCreate) return -1;
      if (bCreate) return 1;

      final aViewed = (a["viewed"] as bool?) ?? false;
      final bViewed = (b["viewed"] as bool?) ?? false;

      /// No vistas primero
      if (aViewed == bViewed) return 0;
      return aViewed ? 1 : -1;
    });

    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: stories.length,
        itemBuilder: (context, index) {

          final story = stories[index];

          return _StoryBubble(
            name: story["name"] as String,
            isCreate: (story["isCreate"] as bool?) ?? false,
            viewed: (story["viewed"] as bool?) ?? false,
          );
        },
      ),
    );
  }
}

class _StoryBubble extends StatefulWidget {

  final String name;
  final bool isCreate;
  final bool viewed;

  const _StoryBubble({
    required this.name,
    this.isCreate = false,
    this.viewed = false,
  });

  @override
  State<_StoryBubble> createState() => _StoryBubbleState();
}

class _StoryBubbleState extends State<_StoryBubble> {

  bool pressed = false;

  @override
  Widget build(BuildContext context) {

    const gradient = LinearGradient(
      colors: [
        const Color(0xFF2DD4BF),
        const Color(0xFF0D9488),
        const Color(0xFF0F766E),
      ],
    );

    return GestureDetector(
      onTapDown: (_) {
        setState(() => pressed = true);
      },
      onTapUp: (_) {
        setState(() => pressed = false);
        _handleTap(context);
      },
      onTapCancel: () {
        setState(() => pressed = false);
      },

      child: AnimatedScale(
        scale: pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 120),

        child: Container(
          width: 76,
          margin: const EdgeInsets.only(right: 10),

          child: Column(
            children: [

              /// AVATAR
              Container(
                padding: const EdgeInsets.all(3),

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  gradient: widget.isCreate
                      ? null
                      : widget.viewed
                          ? null
                          : gradient,

                  color: widget.viewed
                      ? const Color(0xFFCCFBF1)
                      : null,
                ),

                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      )
                    ],
                  ),

                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFE6FAF8),

                    child: widget.isCreate
                        ? const Icon(
                            Icons.add,
                            size: 28,
                            color: const Color(0xFF0D9488),
                          )
                        : const Icon(
                            Icons.person,
                            size: 28,
                            color: Colors.grey,
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              /// NOMBRE
              Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {

    if (widget.isCreate) {
      _openCreateMenu(context);
    } else {
      /// Aquí abrirías la historia del usuario
    }
  }

  void _openCreateMenu(BuildContext context) {

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),

      builder: (context) {

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const SizedBox(height: 10),

              ListTile(
                leading: const Icon(Icons.history),
                title: const Text("Nueva historia"),
                onTap: () {},
              ),

              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Nueva publicación"),
                onTap: () {},
              ),

              ListTile(
                leading: const Icon(Icons.event),
                title: const Text("Crear evento"),
                onTap: () {},
              ),

              ListTile(
                leading: const Icon(Icons.campaign),
                title: const Text("Mensaje a la comunidad"),
                onTap: () {},
              ),

              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
}