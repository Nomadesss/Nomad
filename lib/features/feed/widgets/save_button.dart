import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../services/social_service.dart';

class SaveButton extends StatefulWidget {
  final String postId;

  const SaveButton({super.key, required this.postId});

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      lowerBound: 0.85,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    debugPrint('[SaveButton] tapped — postId: ${widget.postId}');
    await _controller.reverse();
    await _controller.forward();
    try {
      await SocialService.toggleSave(widget.postId);
      debugPrint('[SaveButton] toggleSave OK');
    } catch (e) {
      debugPrint('[SaveButton] ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: SocialService.savedStream(widget.postId),
      builder: (context, snap) {
        final isSaved = snap.data ?? false;

        return GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Icon(
                isSaved
                    ? PhosphorIcons.bookmarkSimple(PhosphorIconsStyle.fill)
                    : PhosphorIcons.bookmarkSimple(),
                size: 24,
                color: const Color(0xFF0D9488),
              ),
            ),
          ),
        );
      },
    );
  }
}
