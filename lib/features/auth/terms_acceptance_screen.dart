import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../feed/feed_screen.dart';

class TermsAcceptanceScreen extends StatefulWidget {
  const TermsAcceptanceScreen({super.key});

  @override
  State<TermsAcceptanceScreen> createState() =>
      _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState
    extends State<TermsAcceptanceScreen> {

  bool accepted = false;

  Future<void> _acceptTerms() async {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .set({

      "email": user.email,
      "name": user.displayName,
      "photo": user.photoURL,

      "acceptedTerms": true,
      "acceptedAt": Timestamp.now(),

      "createdAt": Timestamp.now(),

    });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const FeedScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Text(
              "Aceptar y continuar",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [

                Checkbox(
                  value: accepted,
                  onChanged: (value) {
                    setState(() {
                      accepted = value!;
                    });
                  },
                ),

                const Expanded(
                  child: Text(
                    "Acepto los Términos de uso y la Política de privacidad",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: accepted ? _acceptTerms : null,
              child: const Text("Aceptar y continuar"),
            )
          ],
        ),
      ),
    );
  }
}