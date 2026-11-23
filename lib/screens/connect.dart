import 'package:flutter/material.dart';

import '../i18n.dart';
import '../theme.dart';
import '../widgets/breathing_orb.dart';
import '../widgets/common.dart';
import 'preferences.dart';

/// Primera pantalla: conectar la app con la casa.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.alConectar, required this.urlInicial});

  /// Devuelve un mensaje de error, o null si todo ha ido bien.
  final Future<String?> Function(String url, String token) alConectar;
  final String urlInicial;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final _url = TextEditingController(text: widget.urlInicial);
  final _token = TextEditingController();
  bool _verToken = false;
  bool _conectando = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _conectar() async {
    if (_conectando) return;
    setState(() {
      _conectando = true;
      _error = null;
    });
    final error = await widget.alConectar(_url.text.trim(), _token.text.trim());
    if (!mounted) return;
    setState(() {
      _conectando = false;
      _error = error;
    });
  }

  InputDecoration _campo(String texto, {Widget? sufijo}) => InputDecoration(
        labelText: texto,
        labelStyle: sans(14, color: AureColors.gris),
        filled: true,
        fillColor: AureColors.panel,
        suffixIcon: sufijo,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AureColors.linea),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AureColors.dorado),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SelectorIdioma(compacto: true),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: SizedBox.square(
                      dimension: 170,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          BreathingOrb(
                            size: 170,
                            mode: _conectando ? OrbMode.thinking : OrbMode.idle,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      aureLogo(size: 30),
                      const SizedBox(width: 12),
                      Text('AURÉ', style: sans(28, spacing: 10, weight: FontWeight.w300)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('app.lema'),
                    textAlign: TextAlign.center,
                    style: serif(18, color: AureColors.gris),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _url,
                    style: sans(16),
                    keyboardType: TextInputType.url,
                    decoration: _campo(t('conectar.direccion')),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _token,
                    style: sans(16),
                    obscureText: !_verToken,
                    onSubmitted: (_) => _conectar(),
                    decoration: _campo(
                      t('conectar.token'),
                      sufijo: IconButton(
                        tooltip: _verToken ? t('comun.ocultar') : t('comun.mostrar'),
                        onPressed: () => setState(() => _verToken = !_verToken),
                        icon: Icon(
                          _verToken ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AureColors.gris,
                        ),
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _error == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(_error!, style: sans(14, color: const Color(0xFFE8A87C))),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Pressable(
                    label: t('conectar.boton'),
                    onTap: _conectar,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _conectando ? AureColors.panelAlto : AureColors.dorado,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        _conectando ? t('conectar.conectando') : t('conectar.boton'),
                        style: sans(
                          16,
                          weight: FontWeight.w600,
                          color: _conectando ? AureColors.gris : AureColors.negro,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t('conectar.ayuda'),
                    textAlign: TextAlign.center,
                    style: sans(13, color: AureColors.grisOscuro),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
