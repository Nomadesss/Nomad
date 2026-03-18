import 'package:flutter/material.dart';

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [

                CircleAvatar(radius: 20),

                SizedBox(width: 10),

                Expanded(
                  child: SizedBox(
                    height: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: const Color(0xFFCCFBF1)),
                    ),
                  ),
                )
              ],
            ),
          ),

          Container(
            height: 260,
            color: const Color(0xFFCCFBF1),
          ),

          const SizedBox(height: 10),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(color: const Color(0xFFCCFBF1)),
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}