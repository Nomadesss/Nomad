import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaPerfil extends StatelessWidget {
  const PantallaPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    /// nombre fallback
    final String nombreUsuario =
        user?.displayName ??
        (user?.email != null ? user!.email!.split('@')[0] : "Usuario");

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          /// HEADER IMAGE
          Container(
            height: MediaQuery.of(context).size.height * 0.40,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                ),
              ),
            ),
          ),

          /// CONTENT
          SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 60),

                /// TOP ICONS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.favorite_border, color: Colors.white),
                      const SizedBox(width: 20),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          Navigator.pushReplacementNamed(context, '/');
                        },
                      ),
                    ],
                  ),
                ),

                /// PROFILE PHOTO (HERO)
                Hero(
                  tag: "profile-photo",
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 52,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              nombreUsuario.isNotEmpty
                                  ? nombreUsuario.substring(0, 1).toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                /// USER NAME (HERO)
                Hero(
                  tag: "profile-name",
                  child: Material(
                    color: Colors.transparent,
                    child: Text(
                      nombreUsuario,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                Text(
                  user?.email ?? "",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),

                const SizedBox(height: 30),

                /// OPTION GROUP 1
                _buildOptionGroup([
                  _buildOptionItem(Icons.location_on_outlined, "Mi Dirección"),
                  _buildOptionItem(Icons.person_outline, "Cuenta"),
                ]),

                const SizedBox(height: 20),

                /// OPTION GROUP 2
                _buildOptionGroup([
                  _buildOptionItem(Icons.notifications_none, "Notificaciones"),
                  _buildOptionItem(Icons.devices_outlined, "Dispositivos"),
                  _buildOptionItem(Icons.vpn_key_outlined, "Contraseñas"),
                  _buildOptionItem(Icons.language, "Idioma"),
                ]),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),

      /// BOTTOM NAV
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        currentIndex: 3,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.flash_on), label: 'Shop'),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            label: 'Brands',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  /// OPTION GROUP
  Widget _buildOptionGroup(List<Widget> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: items),
    );
  }

  /// OPTION ITEM
  Widget _buildOptionItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: () {},
    );
  }
}
