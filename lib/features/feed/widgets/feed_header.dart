import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class FeedHeader extends StatelessWidget {
  const FeedHeader({super.key});

  @override
  Widget build(BuildContext context) {

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFEAEAEA),
            width: 1,
          ),
        ),
      ),

      child: Row(
        children: [

          /// IZQUIERDA
          Expanded(
            child: Row(
              children: [

                _HeaderIcon(
                  icon: PhosphorIcons.heart(),
                  onTap: () {},
                ),

                const SizedBox(width: 6),

                _HeaderIcon(
                  icon: PhosphorIcons.handHeart(),
                  onTap: () {},
                ),
              ],
            ),
          ),

          /// LOGO
          Expanded(
            child: Center(
              child: SvgPicture.asset(
                "assets/logo/nomad_logo.svg",
                height: 42,
              ),
            ),
          ),

          /// DERECHA
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [

                /// NOTIFICACIONES
                Stack(
                  clipBehavior: Clip.none,
                  children: [

                    _HeaderIcon(
                      icon: PhosphorIcons.bell(),
                      onTap: () {},
                    ),

                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF3B30),
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: const Center(
                          child: Text(
                            "3",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 6),

                _HeaderIcon(
                  icon: PhosphorIcons.chatCircle(),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {

  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 22,
          color: const Color(0xFF134E4A),
        ),
      ),
    );
  }
}