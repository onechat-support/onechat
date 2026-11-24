import 'package:material_ui/material_ui.dart';

/// Tema oficial ONEchat (Documento Maestro, sección 9).
class OneChatColors {
  static const primary = Color(0xFF00C2A8); // turquesa
  static const secondary = Color(0xFF4F8CFF); // azul
  static const darkBg = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkCard = Color(0xFF242424);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0B0);

  // Colores semánticos sociales
  static const mention = Color(0xFFFF5252);
  static const whisper = Color(0xFFB388FF);
  static const favorite = Color(0xFFFF6B6B);
  static const moderator = Color(0xFFFFB74D);
  static const roomOwner = Color(0xFFFFD54F);
  static const staff = Color(0xFF00E5C4);
}

/// Modo de tema activo de la app (Etapa 4). Parte en oscuro — la
/// cara de la marca en la bienvenida — y al entrar se aplica el
/// guardado en el perfil (system | dark | light).
final appThemeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);

void applyProfileTheme(Map<String, dynamic>? profile) {
  final saved = profile?['theme_mode'] as String?;
  appThemeMode.value = switch (saved) {
    'light' => ThemeMode.light,
    'system' => ThemeMode.system,
    _ => ThemeMode.dark,
  };
}

ThemeData buildOneChatDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: OneChatColors.primary,
    brightness: Brightness.dark,
    surface: OneChatColors.darkSurface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: OneChatColors.darkBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: OneChatColors.darkSurface,
      foregroundColor: OneChatColors.textPrimary,
    ),
    cardTheme: const CardThemeData(color: OneChatColors.darkCard),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OneChatColors.darkSurface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: OneChatColors.primary,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

ThemeData buildOneChatLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: OneChatColors.primary,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: OneChatColors.primary,
        foregroundColor: Colors.black,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
