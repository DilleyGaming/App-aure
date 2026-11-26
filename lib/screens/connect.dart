import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../i18n.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/breathing_orb.dart';
import '../widgets/common.dart';
import 'escanear.dart';
import 'preferences.dart';

bool get puedeEscanear {
  try {
    return Platform.isAndroid || Platform.isIOS;
  } catch (_) {
    return false;
  }
}

/// Primera pantalla: conectar la app con la casa.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({
    super.key,
    required this.alConectar,
    required this.urlInicial,
    this.urlFueraInicial = '',
    this.errorInicial,
  });

  /// Devuelve un mensaje de error, o null si todo ha ido bien.
  final Future<String?> Function(DatosConexion datos) alConectar;
  final String urlInicial;
  final String urlFueraInicial;

  /// Mensaje al abrir (por ejemplo, "tu acceso de invitado ha caducado").
  final String? errorInicial;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final _url = TextEditingController(text: widget.urlInicial);
  late final _fuera = TextEditingController(text: widget.urlFueraInicial);
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _token = TextEditingController();
  bool _verClave = false;
  bool _conToken = false;
  bool _verFuera = false;
  bool _conectando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _verFuera = widget.urlFueraInicial.isNotEmpty;
    _error = widget.errorInicial;
  }

  @override
  void dispose() {
    _url.dispose();
    _fuera.dispose();
    _usuario.dispose();
    _clave.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _conectar() async {
    if (_conectando) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _conectando = true;
      _error = null;
    });
    final error = await widget.alConectar(DatosConexion(
      casa: _url.text,
      fuera: _verFuera ? _fuera.text : '',
      usuario: _conToken ? '' : _usuario.text,
      clave: _conToken ? '' : _clave.text,
      token: _conToken ? _token.text : '',
    ));
    if (!mounted) return;
    setState(() {
      _conectando = false;
      _error = error;
    });
  }

  Future<void> _escanear() async {
    final texto = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const EscanearScreen()),
    );
    if (texto == null || !mounted) return;
    // QR de invitado: entra directamente con su acceso temporal.
    final invitado = Sesion.leerQrInvitado(texto);
    if (invitado != null) {
      if (invitado.invitadoHasta!.isBefore(DateTime.now())) {
        setState(() => _error = t('inv.caducadoTuyo'));
        return;
      }
      setState(() {
        _conectando = true;
        _error = null;
      });
      final error = await widget.alConectar(invitado);
      if (!mounted) return;
      setState(() {
        _conectando = false;
        _error = error;
      });
      return;
    }
    final datos = Sesion.leerQr(texto);
    if (datos == null) {
      setState(() => _error = t('qr.noValido'));
      return;
    }
    setState(() {
      _url.text = datos.$1;
      _fuera.text = datos.$2;
      _verFuera = datos.$2.isNotEmpty;
      _error = null;
    });
  }

  InputDecoration _campo(String texto, {Widget? sufijo, String? ayuda}) => InputDecoration(
        labelText: texto,
        helperText: ayuda,
        helperStyle: sans(12, color: AureColors.grisOscuro),
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

  Widget _enlace(String texto, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        child: Text(texto, style: sans(14, color: AureColors.dorado)),
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
                    child: BreathingOrb(
                      size: 150,
                      mode: _conectando ? OrbMode.thinking : OrbMode.idle,
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
                  Text(t('app.lema'), textAlign: TextAlign.center, style: serif(18, color: AureColors.gris)),
                  const SizedBox(height: 30),
                  if (puedeEscanear) ...[
                    Pressable(
                      label: t('qr.escanear'),
                      onTap: _escanear,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AureColors.dorado.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner, color: AureColors.dorado, size: 20),
                            const SizedBox(width: 10),
                            Text(t('qr.escanear'), style: sans(15, color: AureColors.doradoClaro)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  TextField(
                    controller: _url,
                    style: sans(16),
                    keyboardType: TextInputType.url,
                    decoration: _campo(t('conectar.direccion')),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _verFuera
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: TextField(
                              controller: _fuera,
                              style: sans(16),
                              keyboardType: TextInputType.url,
                              decoration: _campo(t('conectar.fuera'), ayuda: t('conectar.fueraAyuda')),
                            ),
                          )
                        : Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _enlace(t('conectar.anadirFuera'), () => setState(() => _verFuera = true)),
                          ),
                  ),
                  const SizedBox(height: 14),
                  if (_conToken)
                    TextField(
                      controller: _token,
                      style: sans(16),
                      obscureText: !_verClave,
                      onSubmitted: (_) => _conectar(),
                      decoration: _campo(t('conectar.token'), sufijo: _ojo()),
                    )
                  else ...[
                    TextField(
                      controller: _usuario,
                      style: sans(16),
                      autocorrect: false,
                      decoration: _campo(t('conectar.usuario')),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _clave,
                      style: sans(16),
                      obscureText: !_verClave,
                      onSubmitted: (_) => _conectar(),
                      decoration: _campo(t('conectar.clave'), sufijo: _ojo()),
                    ),
                  ],
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
                  const SizedBox(height: 10),
                  Center(
                    child: _enlace(
                      _conToken ? t('conectar.usarUsuario') : t('conectar.usarToken'),
                      () => setState(() {
                        _conToken = !_conToken;
                        _error = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _conToken ? t('conectar.ayuda') : t('conectar.ayudaUsuario'),
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

  Widget _ojo() => IconButton(
        tooltip: _verClave ? t('comun.ocultar') : t('comun.mostrar'),
        onPressed: () => setState(() => _verClave = !_verClave),
        icon: Icon(
          _verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AureColors.gris,
        ),
      );
}
