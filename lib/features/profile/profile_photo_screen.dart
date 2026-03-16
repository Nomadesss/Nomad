import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../feed/feed_screen.dart';

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  File? imageFile;
  bool uploading = false;

  final picker = ImagePicker();

  Future<void> pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() => imageFile = File(picked.path));
  }

  Future<void> continueWithoutPhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (imageFile == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FeedScreen()),
      );
      return;
    }

    try {
      setState(() => uploading = true);

      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_photos")
          .child("${user.uid}.jpg");

      await ref.putFile(imageFile!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection("users").doc(user.uid).set({
        "photo": url,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error subiendo foto: $e");
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const FeedScreen()),
    );
  }

  void showPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF5C6EF5),
              ),
              title: const Text(
                "Tomar foto",
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Color(0xFF5C6EF5),
              ),
              title: const Text(
                "Elegir de galería",
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          // Fondo imagen ciudad difuminada
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=60',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF0F0F1A),
                      Color(0xFF1A1A2E),
                      Color(0xFF0F1A14),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(color: Colors.black.withValues(alpha: 0.55)),
            ),
          ),

          // Degradado inferior
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0xCC0F0F14),
                    Color(0xFF0F0F14),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Contenido
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Logo
                  const Text(
                    "Nomad",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Paso final",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Título
                  const Text(
                    "Agregá tu foto de perfil",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Podés cambiarla luego en tu perfil",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Avatar
                  GestureDetector(
                    onTap: showPicker,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Círculo exterior decorativo
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(
                                0xFF5C6EF5,
                              ).withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                        ),
                        // Avatar principal
                        CircleAvatar(
                          radius: 70,
                          backgroundColor: const Color(0xFF1E3A5F),
                          backgroundImage: imageFile != null
                              ? FileImage(imageFile!)
                              : null,
                          child: imageFile == null
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_rounded,
                                      size: 36,
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Agregar foto",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white.withValues(
                                          alpha: 0.55,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        // Badge de edición
                        if (imageFile != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                color: Color(0xFF5C6EF5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Botón continuar
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: uploading ? null : continueWithoutPhoto,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5C6EF5),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(
                          0xFF5C6EF5,
                        ).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: uploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              imageFile == null
                                  ? "Continuar sin foto"
                                  : "Continuar",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
