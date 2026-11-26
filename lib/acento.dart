import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Estilos de color de Auré. Todos mantienen la esencia (negro profundo y luz cálida):
///  - champán: el original, negro y oro champán.
///  - bronce: oro más oscuro y cálido.
///  - perla: blanco roto cálido sobre negro, muy sobrio.
///  - esmeralda: fondo verde muy profundo con oro.
///  - azul: azul noche con oro, como un salón de hotel clásico.
/// Se aplica como un filtro de color sobre toda la app.
enum Acento { champan, bronce, perla, esmeralda, azul }

class AcentoStore extends ChangeNotifier {
  AcentoStore._();

  static final AcentoStore i = AcentoStore._();
  static const _almacen = FlutterSecureStorage();

  Acento acento = Acento.champan;

  Future<void> cargar() async {
    final v = await _almacen.read(key: 'acento');
    // Los antiguos "rosa" y "plata" ya no existen: vuelven al champán.
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

  /// Matrices calculadas para que cada color de la marca caiga en su versión del estilo
  /// (negro, paneles, oro, crema y grises), sin cambiar la luz ni el contraste.
  static List<double> matrizDe(Acento a) => switch (a) {
        Acento.champan => _identidad,
        Acento.bronce => const [
            0.793, -0.0517, 0.2669, 0, 1.52,
            -0.3583, 0.9084, 0.4615, 0, -1.86,
            -0.2305, -0.0614, 1.3028, 0, -6.24,
            0, 0, 0, 1, 0,
          ],
        Acento.perla => const [
            1.1276, 0.0192, -0.1637, 0, -0.28,
            0.3308, 1.0653, -0.4161, 0, 1.16,
            0.7321, 0.1744, 0.0843, 0, 0.82,
            0, 0, 0, 1, 0,
          ],
        Acento.esmeralda => const [
            1.0557, 0.0288, -0.0719, 0, -9.34,
            -0.0328, 0.9765, 0.0206, 0, 9.02,
            -0.0015, 0.0013, 0.9961, 0, 0.88,
            0, 0, 0, 1, 0,
          ],
        Acento.azul => const [
            1.0809, 0.0303, -0.117, 0, -7.97,
            0.0285, 1.0063, -0.039, 0, -0.29,
            -0.0701, -0.0291, 1.0925, 0, 14.13,
            0, 0, 0, 1, 0,
          ],
      };

  List<double> get matriz => matrizDe(acento);

  /// La matriz contraria: deshace el estilo actual (para enseñar las muestras con su color real).
  List<double> get matrizInversa {
    final m = matriz;
    final a = [
      [m[0], m[1], m[2]],
      [m[5], m[6], m[7]],
      [m[10], m[11], m[12]],
    ];
    final b = [m[4], m[9], m[14]];
    final det = a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) -
        a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
        a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]);
    if (det.abs() < 1e-6) return _identidad;
    final inv = [
      [
        (a[1][1] * a[2][2] - a[1][2] * a[2][1]) / det,
        (a[0][2] * a[2][1] - a[0][1] * a[2][2]) / det,
        (a[0][1] * a[1][2] - a[0][2] * a[1][1]) / det,
      ],
      [
        (a[1][2] * a[2][0] - a[1][0] * a[2][2]) / det,
        (a[0][0] * a[2][2] - a[0][2] * a[2][0]) / det,
        (a[0][2] * a[1][0] - a[0][0] * a[1][2]) / det,
      ],
      [
        (a[1][0] * a[2][1] - a[1][1] * a[2][0]) / det,
        (a[0][1] * a[2][0] - a[0][0] * a[2][1]) / det,
        (a[0][0] * a[1][1] - a[0][1] * a[1][0]) / det,
      ],
    ];
    final off = [
      for (var r = 0; r < 3; r++) -(inv[r][0] * b[0] + inv[r][1] * b[1] + inv[r][2] * b[2]),
    ];
    return [
      inv[0][0], inv[0][1], inv[0][2], 0, off[0],
      inv[1][0], inv[1][1], inv[1][2], 0, off[1],
      inv[2][0], inv[2][1], inv[2][2], 0, off[2],
      0, 0, 0, 1, 0,
    ];
  }
}

/// Muestra de cada estilo: (estilo, clave del nombre, fondo, acento).
const muestrasAcento = <(Acento, String, Color, Color)>[
  (Acento.champan, 'acento.champan', Color(0xFF0E0E10), Color(0xFFD4B57A)),
  (Acento.bronce, 'acento.bronce', Color(0xFF0F0D0C), Color(0xFFBE8C5C)),
  (Acento.perla, 'acento.perla', Color(0xFF0D0D0E), Color(0xFFE2DBCE)),
  (Acento.esmeralda, 'acento.esmeralda', Color(0xFF081511), Color(0xFFD4B57A)),
  (Acento.azul, 'acento.azul', Color(0xFF090E1B), Color(0xFFD6B87E)),
];

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

/// Enseña lo que contiene con sus colores reales, sin el filtro del estilo actual.
class SinFiltroAcento extends StatelessWidget {
  const SinFiltroAcento({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AcentoStore.i,
      builder: (context, _) => ColorFiltered(
        colorFilter: ColorFilter.matrix(AcentoStore.i.matrizInversa),
        child: child,
      ),
    );
  }
}
