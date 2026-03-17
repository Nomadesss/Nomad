import 'package:flutter/material.dart';

class LikeButton extends StatelessWidget {

  final bool liked;
  final VoidCallback onTap;

  const LikeButton({
    super.key,
    required this.liked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Icon(
          liked ? Icons.favorite : Icons.favorite_border,
          key: ValueKey(liked),
          color: liked ? Colors.red : Colors.black,
          size: 28,
        ),
      ),
    );
  }
}