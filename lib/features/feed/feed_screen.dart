import 'package:flutter/material.dart';
import '../profile/perfil_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Hero(
          tag: "logo",
          child: Text(
            "Nomad",
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),

      body: Center(
        child: ElevatedButton(
          child: const Text("Ir al perfil"),
          onPressed: () {

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PantallaPerfil(),
              ),
            );

          },
        ),
      ),
    );
  }
}