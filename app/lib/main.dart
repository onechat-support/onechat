import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_pages.dart';
import 'config.dart';
import 'home_page.dart';
import 'revoked_page.dart';
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
        builder: (context, lang, _) => ValueListenableBuilder<String>(
          valueListenable: appSkin,
          builder: (context, skin, _) => MaterialApp(
            title: 'ONEchat',
            debugShowCheckedModeBanner: false,
            // Skin nostálgico activo (v1.28): manda su tema claro.
            theme: skin == 'mensajero'
                ? buildMessengerTheme()
                : buildOneChatLightTheme(),
            darkTheme: buildOneChatDarkTheme(),
            themeMode: skin == 'mensajero' ? ThemeMode.light : mode,
            home: const SessionGate(),
          ),
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
  // Veredicto de la puerta (registro + Destierro), por uid.
  String? _entryUid;
  Future<Map<String, dynamic>>? _entryFuture;

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
        if (profile == null) {
          // Sin perfil. La pantalla de nickname SOLO tiene sentido
          // para un registro con correo recién confirmado cuyo
          // nickname sigue libre; todo lo demás es una sesión
          // huérfana o duplicada (invitado a mitad de entrada, una
          // segunda cuenta sin terminar, el dueño real entrando
          // por otra vía) y debe volver al acceso bueno, siempre.
          if (snap.hasError) return const NicknameSetupPage();
          final user = svc.currentUser;
          if (user == null || user.isAnonymous) {
            return const _ResetToWelcome();
          }
          final metaNick = user.userMetadata?['nickname'] as String?;
          if (metaNick == null || metaNick.isEmpty) {
            return const _ResetToWelcome();
          }
          return _NicknameCompletionGate(nickname: metaNick);
        }
        // Puerta de entrada: registra la conexión y aplica
        // el Destierro (cuenta + dispositivo + IP) antes de
        // mostrar el interior de la app.
        final uid = profile['uid'] as String;
        if (_entryUid != uid) {
          _entryUid = uid;
          _entryFuture = svc.entryCheck();
        }
        return FutureBuilder<Map<String, dynamic>>(
          future: _entryFuture,
          builder: (context, es) {
            if (es.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final verdict = es.data ?? const {'ok': true};
            if (verdict['banned'] == true) {
              return RevokedPage(verdict: verdict);
            }
            return HomePage(profile: profile);
          },
        );
      },
    );
  }
}

/// Cierra una sesión anónima huérfana (sin perfil) y muestra la
/// pantalla de acceso. Así el login bueno es la puerta única:
/// nadie queda atrapado en «Elige tu nickname» por la sesión
/// vacía de una visita anterior (pedido de Mario, 2026-11-26).
class _ResetToWelcome extends StatefulWidget {
  const _ResetToWelcome();

  @override
  State<_ResetToWelcome> createState() => _ResetToWelcomeState();
}

class _ResetToWelcomeState extends State<_ResetToWelcome> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        await OnechatService().signOut();
      } catch (_) {
        // Aunque la red falle, mostramos el acceso igualmente.
      }
      if (mounted) setState(() => _done = true);
    }();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const WelcomePage();
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Decide si una sesión de correo sin perfil es un registro
/// legítimo por completar (su nickname sigue libre → pantalla de
/// nickname) o una sesión duplicada/huérfana (su nickname ya lo
/// tiene otra cuenta → volver al acceso bueno). Sin esta salida,
/// el dueño real de un nickname quedaba atrapado viendo
/// «ese nickname ya está en uso» en cada visita (Mario, 2026-11-26).
class _NicknameCompletionGate extends StatelessWidget {
  const _NicknameCompletionGate({required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: OnechatService().nicknameStatus(nickname),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || snap.data == 'free') {
          return const NicknameSetupPage();
        }
        return const _ResetToWelcome();
      },
    );
  }
}
