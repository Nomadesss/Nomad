import 'dart:ui';
import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        title: const Text("Política de privacidad"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          _header(),

          const SizedBox(height: 20),

          _section(
            "Información que recopilamos",
            "Nomad puede recopilar información como nombre, correo electrónico, foto de perfil e identificador de usuario cuando creas una cuenta o utilizas servicios de autenticación como Google.",
          ),

          _section(
            "Información generada por el uso",
            "Podemos recopilar información relacionada con el uso de la aplicación, como interacciones con otros usuarios, preferencias dentro de la aplicación y datos técnicos del dispositivo.",
          ),

          _section(
            "Cómo utilizamos la información",
            "Utilizamos los datos para crear y administrar cuentas, permitir interacciones entre usuarios, mejorar la experiencia dentro de la aplicación y garantizar la seguridad de la plataforma.",
          ),

          _section(
            "Almacenamiento de datos",
            "Los datos pueden almacenarse en servicios de infraestructura seguros utilizados para operar la aplicación, los cuales aplican medidas técnicas para proteger la información.",
          ),

          _section(
            "Compartición de información",
            "Nomad no vende ni comparte información personal con terceros, excepto cuando sea necesario para operar el servicio, cuando lo requiera la ley o cuando el usuario lo autorice.",
          ),

          _section(
            "Seguridad",
            "Nomad implementa medidas de seguridad para proteger la información contra accesos no autorizados. Sin embargo, ningún sistema es completamente seguro.",
          ),

          _section(
            "Derechos del usuario",
            "Los usuarios pueden acceder a sus datos, modificar su información o solicitar la eliminación de su cuenta en cualquier momento.",
          ),

          _section(
            "Eliminación de cuenta",
            "Los usuarios pueden solicitar la eliminación de su cuenta y de los datos asociados a través de la configuración de la aplicación o contactando al soporte.",
          ),

          _section(
            "Cambios en la política",
            "Nomad puede actualizar esta política de privacidad en cualquier momento. Las modificaciones serán comunicadas dentro de la aplicación.",
          ),

          const SizedBox(height: 30),

          _contact(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// HEADER SUPERIOR
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
                Icons.lock_outline,
                color: Colors.white,
                size: 40,
              ),

              SizedBox(height: 10),

              Text(
                "Política de privacidad",
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

  /// SECCION EXPANDIBLE
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

  /// CONTACTO
  Widget _contact() {

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [

          Text(
            "¿Tienes preguntas sobre privacidad?",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: 6),

          Text(
            "privacidad@nomad.app",
            style: TextStyle(
              color: Colors.white70,
            ),
          )
        ],
      ),
    );
  }
}