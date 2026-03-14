import 'dart:ui';
import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text("Términos de uso"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          _header(),

          const SizedBox(height: 20),

          _section(
            "Descripción del servicio",
            "Nomad es una plataforma diseñada para ayudar a las personas a conectar con otras personas y generar relaciones sociales.",
          ),

          _section(
            "Requisitos para usar la aplicación",
            "Para utilizar Nomad debes tener al menos 18 años, proporcionar información veraz y utilizar la aplicación de forma responsable.",
          ),

          _section(
            "Conducta del usuario",
            "No está permitido acosar, intimidar, publicar contenido ofensivo, enviar spam o realizar actividades ilegales dentro de la plataforma.",
          ),

          _section(
            "Contenido del usuario",
            "Los usuarios son responsables del contenido que publiquen dentro de la aplicación.",
          ),

          _section(
            "Seguridad de la cuenta",
            "El usuario es responsable de mantener la seguridad de su cuenta.",
          ),

          _section(
            "Limitación de responsabilidad",
            "Nomad proporciona la plataforma tal como está sin garantías de ningún tipo.",
          ),

          _section(
            "Cambios en los términos",
            "Nomad puede actualizar estos términos en cualquier momento.",
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _header() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
            ),
          ),
          child: const Column(
            children: [

              Icon(
                Icons.description_outlined,
                color: Colors.white,
                size: 40,
              ),

              SizedBox(height: 10),

              Text(
                "Términos de uso",
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 6),

              Text(
                "Última actualización: 10 marzo 2026",
                style: TextStyle(
                  color: Colors.white70,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String text) {

    return Card(
      color: Colors.white.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      margin: const EdgeInsets.only(bottom: 12),

      child: ExpansionTile(
        iconColor: Colors.white,
        collapsedIconColor: Colors.white,

        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),

        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                height: 1.5,
              ),
            ),
          )
        ],
      ),
    );
  }
}