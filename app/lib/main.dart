import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_pages.dart';
import 'config.dart';
import 'home_page.dart';
import 'services.dart';
import 'strings.dart';
import 'theme.dart';
import 'welcome_page.dart';

bool backendReady = false;

/// ¿La app se abrió desde el enlace de «¿Olvidaste tu contraseña?»?
/// Se detecta en la dirección ANTES de que Supabase la procese y la
/// limpie; si no, la pantalla de cambio de clave nunca aparece.
bool startInRecovery = false;

/// ONEchat — punto de entrada.
/// Etapa 1 (MVP): inicializa Supabase y decide la primera pantalla
/// según la sesión del usuario.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  startInRecovery = Uri.base.toString().contains('type=recovery');
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabasePublishableKey,
  );
  backendReady = true;
  runApp(const OneChatApp());
}

class OneChatApp extends StatelessWidget {
  const OneChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeMode,
      builder: (context, mode, _) => ValueListenableBuilder<String>(
        valueListenable: appLanguage,
        builder: (context, lang, _) => MaterialApp(
          title: 'ONEchat',
          debugShowCheckedModeBanner: false,
          theme: buildOneChatLightTheme(),
          darkTheme: buildOneChatDarkTheme(),
          themeMode: mode, // el del perfil: system | dark | light (§9)
          home: const SessionGate(),
        ),
      ),
    );
  }
}

/// Sin sesión → bienvenida. Con sesión y perfil → inicio.
/// Con sesión sin perfil → completar nickname.
/// Si se llegó por el enlace de recuperación → nueva contraseña.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  StreamSubscription<AuthState>? _sub;
  bool _recovery = startInRecovery;

  @override
  void initState() {
    super.initState();
    if (backendReady) {
      _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery && mounted) {
          setState(() => _recovery = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!backendReady) return const WelcomePage();
    if (_recovery) {
      return UpdatePasswordPage(
        onDone: () => setState(() => _recovery = false),
      );
    }
    final svc = OnechatService();
    if (!svc.isSignedIn) return const WelcomePage();
    return FutureBuilder<Map<String, dynamic>?>(
      future: svc.fetchMyProfile(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final profile = snap.data;
        if (profile == null) return const NicknameSetupPage();
        return HomePage(profile: profile);
      },
    );
  }
}
