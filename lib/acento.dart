import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Color de acento de la casa: oro champán (por defecto), oro rosa o plata.
/// Se aplica como un filtro de color sobre toda la app.
enum Acento { champan, rosa, plata }

class AcentoStore extends ChangeNotifier {
  AcentoStore._();

  static final AcentoStore i = AcentoStore._();
  static const _almacen = FlutterSecureStorage();

  Acento acento = Acento.champan;

  Future<void> cargar() async {
    final v = await _almacen.read(key: 'acento');
    for (final a in Acento.values) {
      if (a.name == v) acento = a;
    }
  }

  Future<void> cambiar(Acento nuevo) async {
    acento = nuevo;
    notifyListeners();
    await _almacen.write(key: 'acento', value: nuevo.name);
  }

  static const _identidad = <double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 1, 0,
  ];

  /// Matriz de color. En oro champán es neutra (no cambia nada).
  List<double> get matriz {
    switch (acento) {
      case Acento.champan:
        return _identidad;
      case Acento.plata:
        // Quita casi toda la saturación: el dorado pasa a plata y el crema a blanco roto.
        const s = 0.12;
        const lr = 0.2126 * (1 - s), lg = 0.7152 * (1 - s), lb = 0.0722 * (1 - s);
        return const [
          lr + s, lg, lb, 0, 6,
          lr, lg + s, lb, 0, 6,
          lr, lg, lb + s, 0, 10,
          0, 0, 0, 1, 0,
        ];
      case Acento.rosa:
        // Desplaza el dorado hacia un oro rosado.
        return const [
          1.0, 0.08, 0.0, 0, 8,
          0.0, 0.86, 0.0, 0, 0,
          0.04, 0.06, 0.92, 0, 6,
          0, 0, 0, 1, 0,
        ];
    }
  }
}

/// Aplica el acento a todo lo que contiene.
class FiltroAcento extends StatelessWidget {
  const FiltroAcento({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AcentoStore.i,
      builder: (context, _) {
        // Siempre el mismo widget: así la app no se reorganiza al cambiar de acento.
        return ColorFiltered(colorFilter: ColorFilter.matrix(AcentoStore.i.matriz), child: child);
      },
    );
  }
}
