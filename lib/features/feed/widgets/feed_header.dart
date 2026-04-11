import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../community/community_hub_screen.dart';
import '../../notifications/notifications_screen.dart';
import '../../chat/chat_list_screen.dart';
import '../../discover/discover_screen.dart';

class FeedHeader extends StatelessWidget {
  const FeedHeader({super.key});

  // ── Stream: notificaciones no leídas del usuario actual ───────────────────
  Stream<int> _unreadNotificationsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ── Stream: chats con mensajes no leídos ──────────────────────────────────
  Stream<int> _unreadChatsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
          int count = 0;
          for (final doc in snap.docs) {
            final unreadMap =
                doc.data()['unreadCount'] as Map<String, dynamic>? ?? {};
            final myUnread = (unreadMap[userId] as num?)?.toInt() ?? 0;
            if (myUnread > 0) count++;
          }
          return count;
        });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFDFD),
        border: Border(bottom: BorderSide(color: Color(0xFFEAEAEA), width: 1)),
      ),
      child: Row(
        children: [
          // ── IZQUIERDA ────────────────────────────────────────────────────
          Expanded(
            child: Row(
              children: [
                _HeaderIcon(
                  icon: PhosphorIcons.heart(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                  ),
                ),
                const SizedBox(width: 6),
                _HeaderIcon(
                  icon: PhosphorIcons.handHeart(),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CommunityHubScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── LOGO ANIMADO ─────────────────────────────────────────────────
          const Expanded(child: Center(child: _NomadAnimatedLogo())),

          // ── DERECHA ──────────────────────────────────────────────────────
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Campanita con badge dinámico
                if (userId != null)
                  StreamBuilder<int>(
                    stream: _unreadNotificationsStream(userId),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return _BadgeIcon(
                        icon: PhosphorIcons.bell(),
                        count: count,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                      );
                    },
                  )
                else
                  _HeaderIcon(icon: PhosphorIcons.bell(), onTap: () {}),

                const SizedBox(width: 6),

                // Chat con badge dinámico
                if (userId != null)
                  StreamBuilder<int>(
                    stream: _unreadChatsStream(userId),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return _BadgeIcon(
                        icon: PhosphorIcons.chatCircle(),
                        count: count,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChatListScreen(),
                          ),
                        ),
                      );
                    },
                  )
                else
                  _HeaderIcon(icon: PhosphorIcons.chatCircle(), onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: ícono con badge numérico reutilizable
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HeaderIcon(icon: icon, onTap: onTap),
        if (count > 0)
          Positioned(
            right: 2,
            top: 2,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF3B30),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Center(
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo animado — sin cambios
// ─────────────────────────────────────────────────────────────────────────────

class _NomadAnimatedLogo extends StatefulWidget {
  const _NomadAnimatedLogo();

  @override
  State<_NomadAnimatedLogo> createState() => _NomadAnimatedLogoState();
}

class _NomadAnimatedLogoState extends State<_NomadAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _cycleDuration = Duration(seconds: 8);
  static const _letters = ['N', 'o', 'm', 'a', 'd'];
  static const _letterDelay = 0.08;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _cycleDuration)
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: List.generate(_letters.length, (i) {
            return _AnimatedLetter(
              letter: _letters[i],
              progress: _ctrl.value,
              delay: i * _letterDelay,
            );
          }),
        );
      },
    );
  }
}

class _AnimatedLetter extends StatelessWidget {
  final String letter;
  final double progress;
  final double delay;

  const _AnimatedLetter({
    required this.letter,
    required this.progress,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final p = ((progress - delay) % 1.0 + 1.0) % 1.0;

    double opacity;
    double translateY;

    if (p < 0.05) {
      opacity = 0.0;
      translateY = 10.0;
    } else if (p < 0.25) {
      final t = _easeOut((p - 0.05) / 0.20);
      opacity = t;
      translateY = 10.0 * (1 - t);
    } else if (p < 0.65) {
      opacity = 1.0;
      translateY = 0.0;
    } else if (p < 0.82) {
      final t = _easeIn((p - 0.65) / 0.17);
      opacity = 1.0 - t;
      translateY = -10.0 * t;
    } else {
      opacity = 0.0;
      translateY = -10.0;
    }

    return Transform.translate(
      offset: Offset(0, translateY),
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Text(
          letter,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0D9488),
            height: 1.0,
          ),
        ),
      ),
    );
  }

  double _easeOut(double t) => 1 - (1 - t) * (1 - t);
  double _easeIn(double t) => t * t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Ícono base del header — sin cambios
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: const Color(0xFF134E4A)),
      ),
    );
  }
}
