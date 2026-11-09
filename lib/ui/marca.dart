import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme.dart';

/// Nombre comercial visible (no confundir con applicationId / paquete).
abstract final class MarcaApp {
  static const nombre = 'CATARIS Gestión';
  static const corto = 'CATARIS';
  static const assetLogo = 'assets/icon/cataris_logo.png';
}

/// Logo + nombre de la marca (login, rail, cabeceras).
class LogoCataris extends StatelessWidget {
  const LogoCataris({
    super.key,
    this.tamano = 96,
    this.mostrarNombre = true,
    this.nombreClaro = false,
    this.eje = CrossAxisAlignment.center,
  });

  final double tamano;
  final bool mostrarNombre;
  final bool nombreClaro;
  final CrossAxisAlignment eje;

  @override
  Widget build(BuildContext context) {
    final colorNombre = nombreClaro ? Colors.white : Virtus.texto;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: eje,
      children: [
        Image.asset(
          MarcaApp.assetLogo,
          width: tamano,
          height: tamano,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, _, _) => Icon(Icons.workspace_premium, size: tamano * 0.85, color: Virtus.accion),
        ),
        if (mostrarNombre) ...[
          SizedBox(height: tamano > 64 ? 12 : 6),
          Text(
            MarcaApp.nombre,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: tamano > 64 ? 28 : (tamano > 40 ? 16 : 13),
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: colorNombre,
            ),
          ),
        ],
      ],
    );
  }
}

/// Solo el pictograma (AppBar / NavigationRail).
class IconoCataris extends StatelessWidget {
  const IconoCataris({super.key, this.tamano = 32, this.fondoOscuro = false});
  final double tamano;
  final bool fondoOscuro;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      MarcaApp.assetLogo,
      width: tamano,
      height: tamano,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) =>
          Icon(Icons.workspace_premium, size: tamano, color: fondoOscuro ? Colors.white : Virtus.accion),
    );
  }
}
