import 'package:flutter/material.dart';

import '../feed/widgets/bottom_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
// map_screen.dart  –  Nomad App
// Pantalla de mapa — placeholder hasta implementar la funcionalidad.
// ─────────────────────────────────────────────────────────────────────────────

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, size: 64, color: Color(0xFF0D9488)),
            SizedBox(height: 16),
            Text(
              'Mapa',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF134E4A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Próximamente',
              style: TextStyle(fontSize: 14, color: Color(0xFF5EEAD4)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}
