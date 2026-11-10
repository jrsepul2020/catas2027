import 'package:flutter_lucide/flutter_lucide.dart';

/// Tamaños de icono unificados (trazo Lucide, stroke ≈ 2).
abstract final class VirtusIcono {
  /// Barra inferior / NavigationBar.
  static const nav = 22.0;

  /// Baldosas de Gestión rápida.
  static const baldosa = 26.0;

  /// Cabeceras (AppBar, acciones de título).
  static const cabecera = 20.0;

  /// Chips e indicadores inline.
  static const chip = 14.0;

  /// Iconos medios (tarjetas de estado, conexión).
  static const medio = 22.0;
}

/// Catálogo único: Lucide de trazo fino (nunca Material relleno).
///
/// El color lo pone el tema / estado. Grosor visual = el del set Lucide (~2).
abstract final class Iconos {
  static const inicio = LucideIcons.house;
  static const directo = LucideIcons.radio;
  static const mesas = LucideIcons.layout_grid;
  static const puntuaciones = LucideIcons.table;
  static const tandas = LucideIcons.list_ordered;
  static const incidencias = LucideIcons.triangle_exclamation_point;
  static const catadores = LucideIcons.users;
  static const muestras = LucideIcons.wine;
  static const medallero = LucideIcons.medal;
  static const auditoria = LucideIcons.clipboard_check;
  static const sync = LucideIcons.refresh_cw;
  static const ajustes = LucideIcons.settings;
  static const logout = LucideIcons.log_out;
  static const volver = LucideIcons.arrow_left;
  static const chevron = LucideIcons.chevron_right;
  static const play = LucideIcons.play;
  static const check = LucideIcons.circle_check;
  static const reloj = LucideIcons.clock;
  static const tablet = LucideIcons.tablet;
  static const nube = LucideIcons.cloud;
  static const nubeOff = LucideIcons.cloud_off;
  static const calendario = LucideIcons.calendar;
  static const enviar = LucideIcons.send;
  static const aviso = LucideIcons.circle_exclamation_point;
  static const anular = LucideIcons.circle_x;
  static const editar = LucideIcons.pencil;
  static const mas = LucideIcons.plus;
  static const info = LucideIcons.info;
  static const arrastrar = LucideIcons.grip_vertical;
  static const candado = LucideIcons.lock;
  static const candadoAbierto = LucideIcons.lock_open;
  static const bajar = LucideIcons.download;
  static const subir = LucideIcons.upload;
  static const laboratorio = LucideIcons.flask_conical;
  static const borrar = LucideIcons.trash;
  static const copiar = LucideIcons.copy;
  static const pegar = LucideIcons.clipboard_paste;
  static const servidor = LucideIcons.server;
  static const buscar = LucideIcons.search;
  static const ver = LucideIcons.eye;
  static const ocultar = LucideIcons.eye_off;
  static const usuario = LucideIcons.user_round;
  static const intercambiar = LucideIcons.arrow_left_right;
  static const afinar = LucideIcons.sliders_horizontal;
  static const bug = LucideIcons.bug;
  static const sensores = LucideIcons.activity;
  static const ayuda = LucideIcons.info;
  static const masOpciones = LucideIcons.ellipsis;
  static const asiento = LucideIcons.armchair;
}
