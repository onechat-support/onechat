import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_pages.dart';
import 'config.dart';
import 'home_page.dart';
import 'services.dart';
import 'theme.dart';
import 'welcome_page.dart';

bool backendReady = false;

/// ONEchat — punto de entrada.
/// Etapa 1 (MVP): inicializa Supabase y decide la primera pantalla
/// según la sesión del usuario.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      title: 'ONEchat',
      debugShowCheckedModeBanner: false,
      theme: buildOneChatLightTheme(),
      darkTheme: buildOneChatDarkTheme(),
      themeMode: ThemeMode.system, // system | dark | light (Doc. Maestro §9)
      home: const SessionGate(),
    );
  }
}

/// Sin sesión → bienvenida. Con sesión y perfil → inicio.
/// Con sesión sin perfil → completar nickname.
class SessionGate extends StatelessWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!backendReady) return const WelcomePage();
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
