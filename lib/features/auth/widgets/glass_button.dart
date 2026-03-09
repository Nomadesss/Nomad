import 'dart:ui';
import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {

  final String icon;
  final String text;
  final VoidCallback onTap;

  const GlassButton({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 320,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.35),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                Image.asset(icon, width: 22),

                const SizedBox(width: 10),

                Text(text),

              ],
            ),
          ),
        ),
      ),
    );
  }
}