import 'package:flutter/material.dart';

/// Tokens de diseño de VolutrainMed.
///
/// Identidad visual de Stitch (`design/stitch/DESIGN.md`): primario #0D5C75,
/// secundario #088395, verificación #059669, neutro #0F172A, lienzo #F4FAFB y
/// borde #C5D9E0; Space Grotesk para títulos, Noto Sans para el cuerpo y
/// Space Mono para cifras. Medidas (alturas de botón, teclado, radios) y
/// valores del tema oscuro, del lienzo de Claude (`tokens-components.css`).
/// Todos los pares texto/fondo superan 4,5:1 (comprobado en las pruebas).
abstract final class Fuentes {
  static const titulos = 'SpaceGrotesk';
  static const cuerpo = 'NotoSans';
  static const cifras = 'SpaceMono';
}

/// Colores semánticos que Material no cubre.
@immutable
class VtmColores extends ThemeExtension<VtmColores> {
  const VtmColores({
    required this.lienzo,
    required this.superficie,
    required this.superficie2,
    required this.texto,
    required this.atenuado,
    required this.borde,
    required this.primario,
    required this.primarioTinte,
    required this.exito,
    required this.exitoTinte,
    required this.error,
    required this.errorFuerte,
    required this.errorTinte,
    required this.aviso,
    required this.avisoTinte,
    required this.acento,
    required this.acentoTinte,
  });

  final Color lienzo;
  final Color superficie;
  final Color superficie2;
  final Color texto;
  final Color atenuado;
  final Color borde;
  final Color primario;
  final Color primarioTinte;
  final Color exito;
  final Color exitoTinte;
  final Color error;
  final Color errorFuerte;
  final Color errorTinte;
  final Color aviso;
  final Color avisoTinte;
  final Color acento;
  final Color acentoTinte;

  static const claro = VtmColores(
    lienzo: Color(0xFFF4FAFB),
    superficie: Color(0xFFFFFFFF),
    superficie2: Color(0xFFEAF3F5),
    texto: Color(0xFF0F172A),
    atenuado: Color(0xFF475569),
    borde: Color(0xFFC5D9E0),
    primario: Color(0xFF0D5C75),
    primarioTinte: Color(0xFFE3F1F5),
    exito: Color(0xFF047857),
    exitoTinte: Color(0xFFE6F5EF),
    error: Color(0xFFDC2626),
    errorFuerte: Color(0xFFB91C1C),
    errorTinte: Color(0xFFFDEDED),
    aviso: Color(0xFFB45309),
    avisoTinte: Color(0xFFFDF3E4),
    acento: Color(0xFF92400E),
    acentoTinte: Color(0xFFFEF3D6),
  );

  static const oscuro = VtmColores(
    lienzo: Color(0xFF0B1D24),
    superficie: Color(0xFF12262E),
    superficie2: Color(0xFF1A323B),
    texto: Color(0xFFE6F4F7),
    atenuado: Color(0xFFA8BCC4),
    borde: Color(0xFF2A4550),
    primario: Color(0xFF7DD3EA),
    primarioTinte: Color(0xFF123B47),
    exito: Color(0xFF34D399),
    exitoTinte: Color(0xFF0F382D),
    error: Color(0xFFF87171),
    errorFuerte: Color(0xFFFCA5A5),
    errorTinte: Color(0xFF3B1A1D),
    aviso: Color(0xFFFBBF24),
    avisoTinte: Color(0xFF38290C),
    acento: Color(0xFFFBBF24),
    acentoTinte: Color(0xFF38290C),
  );

  @override
  VtmColores copyWith() => this;

  @override
  VtmColores lerp(ThemeExtension<VtmColores>? other, double t) {
    if (other is! VtmColores) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return VtmColores(
      lienzo: l(lienzo, other.lienzo),
      superficie: l(superficie, other.superficie),
      superficie2: l(superficie2, other.superficie2),
      texto: l(texto, other.texto),
      atenuado: l(atenuado, other.atenuado),
      borde: l(borde, other.borde),
      primario: l(primario, other.primario),
      primarioTinte: l(primarioTinte, other.primarioTinte),
      exito: l(exito, other.exito),
      exitoTinte: l(exitoTinte, other.exitoTinte),
      error: l(error, other.error),
      errorFuerte: l(errorFuerte, other.errorFuerte),
      errorTinte: l(errorTinte, other.errorTinte),
      aviso: l(aviso, other.aviso),
      avisoTinte: l(avisoTinte, other.avisoTinte),
      acento: l(acento, other.acento),
      acentoTinte: l(acentoTinte, other.acentoTinte),
    );
  }

  /// Pares de primer plano y fondo que deben cumplir 4,5:1.
  Map<String, (Color, Color)> get paresDeTexto => {
        'texto/lienzo': (texto, lienzo),
        'texto/superficie': (texto, superficie),
        'texto/superficie2': (texto, superficie2),
        'atenuado/lienzo': (atenuado, lienzo),
        'atenuado/superficie': (atenuado, superficie),
        'primario/superficie': (primario, superficie),
        'primario/lienzo': (primario, lienzo),
        'primario/primarioTinte': (primario, primarioTinte),
        'exito/exitoTinte': (exito, exitoTinte),
        'errorFuerte/errorTinte': (errorFuerte, errorTinte),
        'errorFuerte/superficie': (errorFuerte, superficie),
        'aviso/avisoTinte': (aviso, avisoTinte),
        'acento/acentoTinte': (acento, acentoTinte),
        'texto/exitoTinte': (texto, exitoTinte),
        'texto/errorTinte': (texto, errorTinte),
      };
}

extension TemaVtm on BuildContext {
  VtmColores get vtm => Theme.of(this).extension<VtmColores>() ?? VtmColores.claro;
  TextTheme get textos => Theme.of(this).textTheme;
}

/// Estilo de cifras (Space Mono, numerales tabulares).
TextStyle estiloCifra(BuildContext context, {double size = 18, FontWeight weight = FontWeight.w700, Color? color}) => TextStyle(
      fontFamily: Fuentes.cifras,
      fontSize: size,
      fontWeight: weight,
      color: color ?? context.vtm.texto,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// Contraste WCAG entre dos colores opacos.
double contraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la > lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

ThemeData construirTema(Brightness brillo, {bool altoContraste = false}) {
  final c = brillo == Brightness.light ? VtmColores.claro : VtmColores.oscuro;
  final borde = altoContraste ? c.texto : c.borde;
  final esquema = ColorScheme(
    brightness: brillo,
    primary: c.primario,
    onPrimary: brillo == Brightness.light ? Colors.white : const Color(0xFF062A33),
    primaryContainer: c.primarioTinte,
    onPrimaryContainer: c.primario,
    secondary: brillo == Brightness.light ? const Color(0xFF066A78) : const Color(0xFF67E8F9),
    onSecondary: brillo == Brightness.light ? Colors.white : const Color(0xFF062A33),
    tertiary: c.exito,
    onTertiary: brillo == Brightness.light ? Colors.white : const Color(0xFF052E22),
    error: c.errorFuerte,
    onError: brillo == Brightness.light ? Colors.white : const Color(0xFF3B0A0A),
    errorContainer: c.errorTinte,
    onErrorContainer: c.errorFuerte,
    surface: c.superficie,
    onSurface: c.texto,
    onSurfaceVariant: c.atenuado,
    surfaceContainerLowest: c.superficie,
    surfaceContainerLow: c.lienzo,
    surfaceContainer: c.superficie2,
    surfaceContainerHigh: c.superficie2,
    surfaceContainerHighest: c.superficie2,
    outline: borde,
    outlineVariant: c.borde,
  );

  TextStyle t(String f, double s, double h, FontWeight w, {double ls = 0}) =>
      TextStyle(fontFamily: f, fontSize: s, height: h / s, fontWeight: w, letterSpacing: ls, color: c.texto);

  final textos = TextTheme(
    displaySmall: t(Fuentes.titulos, 32, 40, FontWeight.w700, ls: -0.3),
    headlineMedium: t(Fuentes.titulos, 28, 36, FontWeight.w700),
    headlineSmall: t(Fuentes.titulos, 24, 32, FontWeight.w600),
    titleLarge: t(Fuentes.titulos, 20, 28, FontWeight.w600),
    titleMedium: t(Fuentes.titulos, 17, 24, FontWeight.w600),
    titleSmall: t(Fuentes.titulos, 15, 20, FontWeight.w600),
    bodyLarge: t(Fuentes.cuerpo, 18, 28, FontWeight.w400),
    bodyMedium: t(Fuentes.cuerpo, 16, 24, FontWeight.w400),
    bodySmall: t(Fuentes.cuerpo, 14, 20, FontWeight.w400),
    labelLarge: t(Fuentes.titulos, 16, 20, FontWeight.w600),
    labelMedium: t(Fuentes.titulos, 13, 16, FontWeight.w500),
    labelSmall: t(Fuentes.titulos, 12, 16, FontWeight.w600, ls: 0.6),
  );

  final redondo12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return ThemeData(
    useMaterial3: true,
    brightness: brillo,
    colorScheme: esquema,
    scaffoldBackgroundColor: c.lienzo,
    fontFamily: Fuentes.cuerpo,
    textTheme: textos,
    extensions: [c],
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: c.lienzo,
      foregroundColor: c.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textos.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: c.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borde)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: redondo12,
        textStyle: textos.labelLarge?.copyWith(fontSize: 17),
        disabledBackgroundColor: c.superficie2,
        disabledForegroundColor: c.atenuado,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: redondo12,
        foregroundColor: c.primario,
        side: BorderSide(color: borde),
        textStyle: textos.labelLarge?.copyWith(fontSize: 17),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: c.primario,
        textStyle: textos.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.superficie,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borde)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borde)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.primario, width: 2)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.superficie2,
      labelStyle: textos.labelMedium,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.superficie,
      indicatorColor: c.primarioTinte,
      labelTextStyle: WidgetStatePropertyAll(textos.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.primario : c.atenuado)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.superficie,
      indicatorColor: c.primarioTinte,
      selectedIconTheme: IconThemeData(color: c.primario),
      unselectedIconTheme: IconThemeData(color: c.atenuado),
      selectedLabelTextStyle: textos.labelMedium?.copyWith(color: c.primario),
      unselectedLabelTextStyle: textos.labelMedium?.copyWith(color: c.atenuado),
    ),
    dividerTheme: DividerThemeData(color: c.borde, thickness: 1, space: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.superficie,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.texto,
      contentTextStyle: textos.bodyMedium?.copyWith(color: c.lienzo),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? esquema.onPrimary : c.atenuado),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primario : c.superficie2),
    ),
  );
}
