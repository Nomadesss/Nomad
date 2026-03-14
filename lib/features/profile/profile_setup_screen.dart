import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../feed/feed_screen.dart';
import '../profile/profile_photo_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {

  int step = 0;

  final usernameController = TextEditingController();

  String usernameError = "";
  bool usernameAvailable = false;
  bool checkingUsername = false;

  String? selectedCountry;
  String? countryCode;

  Position? userPosition;
  String? detectedCity;
  String? detectedCountry;

  bool amistad = false;
  bool citas = false;
  bool servicios = false;
  bool foros = false;

  Future<void> validateUsername() async {

    final username = usernameController.text.trim();
    final regex = RegExp(r'^[a-zA-Z0-9_]{6,15}$');

    if (!regex.hasMatch(username)) {
      setState(() {
        usernameError = "Debe tener entre 6 y 15 caracteres";
        usernameAvailable = false;
      });
      return;
    }

    setState(() {
      checkingUsername = true;
    });

    final result = await FirebaseFirestore.instance
        .collection("users")
        .where("username", isEqualTo: username)
        .get();

    if (result.docs.isNotEmpty) {

      setState(() {
        usernameError = "Username ya utilizado";
        usernameAvailable = false;
        checkingUsername = false;
      });

    } else {

      setState(() {
        usernameError = "";
        usernameAvailable = true;
        checkingUsername = false;
      });
    }
  }

  Future<void> getLocation() async {

    try {

      LocationPermission permission =
          await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );

      final place = placemarks.first;

      setState(() {
        userPosition = pos;
        detectedCity = place.locality;
        detectedCountry = place.country;
      });

    } catch (e) {

      print("Error obteniendo ubicación: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo obtener la ubicación"),
        ),
      );
    }
  }

  Future<void> saveProfile() async {

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .set({

      "username": usernameController.text.trim(),

      "country": selectedCountry,
      "countryCode": countryCode,

      "location": {
        "lat": userPosition?.latitude,
        "lng": userPosition?.longitude,
        "city": detectedCity,
        "country": detectedCountry,
        "accuracy": userPosition?.accuracy,
        "timestamp": DateTime.now().millisecondsSinceEpoch
      },

      "interests": {
        "amistad": amistad,
        "citas": citas,
        "servicios": servicios,
        "foros": foros
      }

    }, SetOptions(merge: true));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const FeedScreen(),
      ),
    );
  }

  void nextStep() {

    if (step == 0 && !usernameAvailable) return;

    if (step < 3) {
      setState(() {
        step++;
      });
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfilePhotoScreen(),
        ),
      );
    }
  }

  /// INDICADOR DE PASOS

  Widget progressIndicator() {

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {

        bool active = index <= step;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: active ? 28 : 12,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF3F6293)
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }),
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

              const SizedBox(height: 20),

              const Text(
                "Nomad",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Paso ${step + 1} de 4",
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 16),

              progressIndicator(),

              const SizedBox(height: 40),

              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: buildStep(),
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                height: 55,

                child: ElevatedButton(
                  onPressed: nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F6293),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    step == 3 ? "Finalizar" : "Continuar",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20)
            ],
          ),
        ),
      ),
    );
  }

  Widget buildStep() {

    switch (step) {
      case 0:
        return usernameStep();
      case 1:
        return countryStep();
      case 2:
        return locationStep();
      case 3:
        return interestsStep();
      default:
        return Container();
    }
  }

  Widget usernameStep() {

    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [

        const Text(
          "Elige tu username",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        TextField(
          controller: usernameController,
          onChanged: (_) => validateUsername(),

          decoration: InputDecoration(
            hintText: "username",

            prefixIcon: const Icon(Icons.person_outline),

            suffixIcon: checkingUsername
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2),
                  )
                : usernameAvailable
                    ? const Icon(Icons.check_circle,
                        color: Colors.green)
                    : null,

            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),

        const SizedBox(height: 6),

        if (usernameError.isNotEmpty)
          Text(
            usernameError,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget countryStep() {

    void openCountrySelector() {

      final countries = CountryService().getAll();
      final suggested = ["UY", "AR", "BR", "CL", "ES", "US"];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        builder: (context) {

          TextEditingController searchController =
              TextEditingController();

          List<Country> filtered = countries;

          return StatefulBuilder(
            builder: (context, setModalState) {

              void filter(String value) {

                setModalState(() {
                  filtered = countries
                      .where((c) => c.name
                          .toLowerCase()
                          .contains(value.toLowerCase()))
                      .toList();
                });
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),

                child: Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  padding: const EdgeInsets.all(20),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const Text(
                        "Selecciona tu país",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// BUSCADOR
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: filter,

                        decoration: InputDecoration(
                          hintText: "Buscar país",
                          prefixIcon: const Icon(Icons.search),

                          filled: true,
                          fillColor: Colors.grey.shade100,

                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// LISTA COMPLETA
                      Expanded(
                        child: ListView(
                          children: [

                            /// SUGERIDOS
                            if (searchController.text.isEmpty) ...[
                              const Text(
                                "Sugeridos",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),

                              const SizedBox(height: 10),

                              ...suggested.map((code) {

                                final c = countries.firstWhere(
                                  (e) => e.countryCode == code,
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),

                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade50,
                                  ),

                                  child: ListTile(
                                    leading: Text(
                                      c.flagEmoji,
                                      style: const TextStyle(fontSize: 22),
                                    ),

                                    title: Text(
                                      c.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),

                                    onTap: () {

                                      Navigator.pop(context);

                                      setState(() {
                                        selectedCountry = c.name;
                                        countryCode = c.countryCode;
                                      });
                                    },
                                  ),
                                );
                              }),

                              const Divider(height: 30),

                              const Text(
                                "Todos los países",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),

                              const SizedBox(height: 10),
                            ],

                            /// LISTA COMPLETA SIN DUPLICADOS
                            ...filtered
                                .where((country) =>
                                    searchController.text.isNotEmpty ||
                                    !suggested.contains(country.countryCode))
                                .map((country) {

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),

                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey.shade50,
                                ),

                                child: ListTile(
                                  leading: Text(
                                    country.flagEmoji,
                                    style: const TextStyle(fontSize: 22),
                                  ),

                                  title: Text(
                                    country.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),

                                  onTap: () {

                                    Navigator.pop(context);

                                    setState(() {
                                      selectedCountry = country.name;
                                      countryCode = country.countryCode;
                                    });
                                  },
                                ),
                              );
                            }).toList(),

                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          "¿De qué país eres?",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        GestureDetector(
          onTap: openCountrySelector,

          child: Container(
            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),

            child: Row(
              children: [

                const Icon(Icons.public),

                const SizedBox(width: 10),

                Row(
                  children: [
                    if (countryCode != null)
                      Text(
                        Country.parse(countryCode!).flagEmoji,
                        style: const TextStyle(fontSize: 20),
                      ),

                    if (countryCode != null)
                      const SizedBox(width: 8),

                    Text(
                      selectedCountry ?? "Seleccionar país",
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget locationStep() {

    return Column(
      key: const ValueKey(2),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Icon(
          Icons.location_on,
          size: 60,
          color: Color(0xFF3F6293),
        ),

        const SizedBox(height: 20),

        const Text(
          "Detectar tu ubicación actual",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          "Esto nos ayuda a conectarte con personas "
          "de tu país que viven cerca de ti.",
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 30),

        Center(
          child: ElevatedButton.icon(
            onPressed: getLocation,
            icon: const Icon(Icons.my_location),
            label: const Text("Usar mi ubicación"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF3F6293),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: const BorderSide(
                  color: Color(0xFF3F6293),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (userPosition != null)
          Center(
            child: Column(
              children: [

                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 28,
                ),

                const SizedBox(height: 6),

                Text(
                  "Ubicación detectada correctamente",
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  "$detectedCity, $detectedCountry",
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget interestsStep() {

    return Column(
      key: const ValueKey(3),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        const Text(
          "¿Qué buscas en Nomad?",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 20),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [

            interestChip("Amistad", amistad,
                () => setState(() => amistad = !amistad)),

            interestChip("Citas", citas,
                () => setState(() => citas = !citas)),

            interestChip("Servicios", servicios,
                () => setState(() => servicios = !servicios)),

            interestChip("Foros", foros,
                () => setState(() => foros = !foros)),
          ],
        ),
      ],
    );
  }

  Widget interestChip(
      String label,
      bool selected,
      VoidCallback onTap) {

    return GestureDetector(

      onTap: onTap,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),

          color: selected
              ? const Color(0xFF3F6293)
              : Colors.grey.shade200,
        ),

        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}