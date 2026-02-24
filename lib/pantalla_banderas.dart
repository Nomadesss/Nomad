import 'package:flutter/material.dart';

class PantallaBanderas extends StatelessWidget {
  const PantallaBanderas({super.key});

  // Lista de países iniciales (puedes agregar más después)
  final List<Map<String, String>> paises = const [
    {'nombre': 'Uruguay', 'bandera': '🇺🇾', 'color': '#00A1DF'},
    {'nombre': 'Alemania', 'bandera': '🇩🇪', 'color': '#FFCE00'},
    {'nombre': 'México', 'bandera': '🇲🇽', 'color': '#006847'},
    {'nombre': 'Italia', 'bandera': '🇮🇹', 'color': '#009246'},
    {'nombre': 'España', 'bandera': '🇪🇸', 'color': '#F1BF00'},
    {'nombre': 'Argentina', 'bandera': '🇦🇷', 'color': '#75AADB'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("¿Cuál es tu bandera?"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Conéctate con tu gente en cualquier parte del mundo.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Dos columnas
                childAspectRatio: 1.1,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: paises.length,
              itemBuilder: (context, index) {
                return _itemBandera(context, paises[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(30.0),
            child: OutlinedButton(
              onPressed: () {
                // Aquí abriremos un buscador para el resto de países
              },
              child: const Text("Busca otro país..."),
            ),
          )
        ],
      ),
    );
  }

  Widget _itemBandera(BuildContext context, Map<String, String> pais) {
    return InkWell(
      onTap: () {
        print("Seleccionaste: ${pais['nombre']}");
        // Aquí guardaremos la elección y saltaremos a la Home
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(pais['bandera']!, style: const TextStyle(fontSize: 50)),
            const SizedBox(height: 10),
            Text(
              pais['nombre']!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}