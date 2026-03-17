import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  @override
  Widget build(BuildContext context) {

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.black,
      unselectedItemColor: Colors.black54,
      showSelectedLabels: false,
      showUnselectedLabels: false,

      items: const [

        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: "",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.map),
          label: "",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: "",
        ),

        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: "",
        ),
      ],
    );
  }
}