import 'package:flutter/material.dart';

class PantallaBanderas extends StatefulWidget {
  const PantallaBanderas({super.key});

  @override
  State<PantallaBanderas> createState() => _PantallaBanderasState();
}

class _PantallaBanderasState extends State<PantallaBanderas> {
  // Lista principal de países (puedes seguir agregando aquí)
  final List<Map<String, String>> paises = const [
    {'nombre': 'Uruguay', 'bandera': '🇺🇾', 'color': '#00A1DF'},
    {'nombre': 'Alemania', 'bandera': '🇩🇪', 'color': '#FFCE00'},
    {'nombre': 'México', 'bandera': '🇲🇽', 'color': '#006847'},
    {'nombre': 'Italia', 'bandera': '🇮🇹', 'color': '#009246'},
    {'nombre': 'España', 'bandera': '🇪🇸', 'color': '#F1BF00'},
    {'nombre': 'Argentina', 'bandera': '🇦🇷', 'color': '#75AADB'},
    {'nombre': 'Brasil', 'bandera': '🇧🇷', 'color': '#47B14C'},
    {'nombre': 'Colombia', 'bandera': '🇨🇴', 'color': '#F7D117'},
    {'nombre': 'Chile', 'bandera': '🇨🇱', 'color': '#0039A6'},
    {'nombre': 'Perú', 'bandera': '🇵🇪', 'color': '#D91023'},
  ];

  // Función para mostrar el buscador tipo Pop-up
  void _mostrarBuscadorPaises(BuildContext context) {
    // Copia local para filtrar dentro del modal
    List<Map<String, String>> paisesFiltrados = List.from(paises);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text("Busca tu país"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400, // Altura del cuadro de búsqueda
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: "Escribe el nombre...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onChanged: (value) {
                        // Esto actualiza la lista dentro del Pop-up
                        setStateModal(() {
                          paisesFiltrados = paises
                              .where(
                                (p) => p['nombre']!.toLowerCase().contains(
                                  value.toLowerCase(),
                                ),
                              )
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: paisesFiltrados.isEmpty
                          ? const Center(
                              child: Text("No se encontraron países"),
                            )
                          : ListView.builder(
                              itemCount: paisesFiltrados.length,
                              itemBuilder: (context, index) {
                                final p = paisesFiltrados[index];
                                return ListTile(
                                  leading: Text(
                                    p['bandera']!,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  title: Text(p['nombre']!),
                                  onTap: () {
                                    print(
                                      "Seleccionado desde buscador: ${p['nombre']}",
                                    );
                                    Navigator.pop(
                                      context,
                                    ); // Cierra el buscador
                                    // Aquí puedes navegar a la Home
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "¿Cuál es tu nacionalidad?", // Cambio de texto solicitado
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
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
                crossAxisCount: 2,
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () =>
                  _mostrarBuscadorPaises(context), // Acción del botón
              child: const Text(
                "Busca otro país...",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemBandera(BuildContext context, Map<String, String> pais) {
    return InkWell(
      onTap: () {
        print("Seleccionaste: ${pais['nombre']}");
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
            ),
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
