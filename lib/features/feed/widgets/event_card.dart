import 'package:flutter/material.dart';

class EventCard extends StatelessWidget {

  final String title;
  final String location;
  final String date;

  const EventCard({
    super.key,
    required this.title,
    required this.location,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: const Color(0xFFF0F4FF),
        borderRadius: BorderRadius.circular(14),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const Text(
            "Evento cercano",
            style: TextStyle(
              fontSize: 12,
              color: Colors.blueGrey,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            location,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            date,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: () {},
            child: const Text("Ver evento"),
          )
        ],
      ),
    );
  }
}