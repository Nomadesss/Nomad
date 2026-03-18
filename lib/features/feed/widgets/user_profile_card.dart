import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ── Modelo de datos del usuario ───────────────────────────────────────────────
// En producción estos datos vendrían de Firestore.
// Por ahora se pasan directamente al widget.

class UserProfileData {
  final String username;
  final String? fullName;
  final String? country;
  final String? countryFlag;
  final String? city;
  final String? bio;
  final int postsCount;
  final int friendsCount;
  final bool isFollowing;

  const UserProfileData({
    required this.username,
    this.fullName,
    this.country,
    this.countryFlag,
    this.city,
    this.bio,
    this.postsCount = 0,
    this.friendsCount = 0,
    this.isFollowing = false,
  });
}

// ── Tarjeta de perfil (contenido compartido entre BottomSheet y Popover) ──────

class UserProfileCard extends StatefulWidget {
  final UserProfileData user;

  const UserProfileCard({super.key, required this.user});

  @override
  State<UserProfileCard> createState() => _UserProfileCardState();
}

class _UserProfileCardState extends State<UserProfileCard> {
  late bool _following;

  @override
  void initState() {
    super.initState();
    _following = widget.user.isFollowing;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [

        // ── Avatar + nombre + país ────────────────────────────────────────────
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFCCFBF1),
              child: const Icon(
                Icons.person,
                size: 28,
                color: Color(0xFF0D9488),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Row(
                    children: [
                      Text(
                        widget.user.fullName ?? widget.user.username,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF134E4A),
                        ),
                      ),
                      if (widget.user.countryFlag != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          widget.user.countryFlag!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ],
                  ),

                  Text(
                    "@${widget.user.username}",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0D9488),
                    ),
                  ),

                  if (widget.user.city != null)
                    Row(
                      children: [
                        Icon(
                          PhosphorIcons.mapPin(),
                          size: 12,
                          color: const Color(0xFF5EEAD4),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          widget.user.city!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5EEAD4),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Bio ───────────────────────────────────────────────────────────────
        if (widget.user.bio != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.user.bio!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF134E4A),
                height: 1.5,
              ),
            ),
          ),

        if (widget.user.bio != null) const SizedBox(height: 16),

        // ── Stats ─────────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAF9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(label: "Publicaciones", value: widget.user.postsCount),
              _StatDivider(),
              _Stat(label: "Amigos", value: widget.user.friendsCount),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Acciones ──────────────────────────────────────────────────────────
        Row(
          children: [

            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 42,
                decoration: BoxDecoration(
                  color: _following
                      ? const Color(0xFFE6FAF8)
                      : const Color(0xFF0D9488),
                  borderRadius: BorderRadius.circular(10),
                  border: _following
                      ? Border.all(color: const Color(0xFF5EEAD4))
                      : null,
                ),
                child: TextButton(
                  onPressed: () => setState(() => _following = !_following),
                  child: Text(
                    _following ? "Siguiendo" : "Seguir",
                    style: TextStyle(
                      color: _following
                          ? const Color(0xFF0D9488)
                          : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF5EEAD4)),
              ),
              child: IconButton(
                onPressed: () {},
                icon: Icon(
                  PhosphorIcons.chatCircle(),
                  size: 20,
                  color: const Color(0xFF0D9488),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "$value",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0D9488),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF5EEAD4),
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFF5EEAD4),
    );
  }
}