import 'package:flutter/material.dart';

class RegistroEmailScreen extends StatelessWidget {
  const RegistroEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear cuenta")),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          children: [
            const Text(
              "Ingresa tus datos para empezar a conectarte.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            const TextField(
              decoration: InputDecoration(
                labelText: "Correo electrónico o Celular",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Contraseña",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
              ),
              onPressed: () {
                // Después de validar, lo mandamos a las banderas
                Navigator.pushNamed(context, '/banderas');
              },
              child: const Text("Continuar", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}