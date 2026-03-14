import 'dart:io';
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

  /// ELEGIR IMAGEN
  Future<void> pickImage(ImageSource source) async {

    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (picked == null) return;

    setState(() {
      imageFile = File(picked.path);
    });
  }

  /// SUBIR FOTO
  Future<void> continueWithoutPhoto() async {

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Si NO hay imagen simplemente continúa
    if (imageFile == null) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const FeedScreen(),
        ),
      );

      return;
    }

    // Si hay imagen intenta subirla
    try {

      setState(() {
        uploading = true;
      });

      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_photos")
          .child("${user.uid}.jpg");

      await ref.putFile(imageFile!);

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set({
        "photo": url
      }, SetOptions(merge: true));

    } catch (e) {

      print("Error subiendo foto: $e");

    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const FeedScreen(),
      ),
    );
  }

  /// DIALOGO CAMARA / GALERIA
  void showPicker() {

    showModalBottomSheet(
      context: context,
      builder: (_) {

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Tomar foto"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.camera);
                },
              ),

              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Elegir de galería"),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.gallery);
                },
              ),

            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),

          child: Column(
            children: [

              const SizedBox(height: 40),

              const Text(
                "Nomad",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Paso final",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "Agrega tu foto de perfil",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              GestureDetector(

                onTap: showPicker,

                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      imageFile != null ? FileImage(imageFile!) : null,
                  child: imageFile == null
                      ? const Icon(
                          Icons.add_a_photo,
                          size: 35,
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Puedes cambiarla luego en tu perfil",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(

                  onPressed: uploading ? null : continueWithoutPhoto,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F6293),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),

                  child: uploading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text(
                          "Continuar",
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}