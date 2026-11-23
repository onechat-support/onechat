import 'package:material_ui/material_ui.dart';

import 'auth_pages.dart';
import 'home_page.dart';
import 'services.dart';
import 'theme.dart';

/// Pantalla de acceso (Documento Maestro, sección 2) — Etapa 1:
/// entrada real como invitado con nickname único, más accesos a
/// crear cuenta e iniciar sesión.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _nicknameController = TextEditingController();
  final _svc = OnechatService();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _enterAsGuest() async {
    final nick = _nicknameController.text.trim();
    final invalid = OnechatService.validateNickname(nick);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await _svc.enterAsGuest(nick);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(profile: profile)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ONEchat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      color: OneChatColors.primary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Salas para conversar, como las de antes.\nEntra, elige tu nickname y a chatear.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _nicknameController,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _busy ? null : _enterAsGuest(),
                    decoration: const InputDecoration(
                      labelText: 'Tu nickname',
                      hintText: 'Ej.: Mario',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _enterAsGuest,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('CHATEAR DIRECTAMENTE'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: OneChatColors.mention),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const SignUpPage()),
                                ),
                        child: const Text('Crear cuenta'),
                      ),
                      const Text('·'),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const SignInPage()),
                                ),
                        child: const Text('Iniciar sesión'),
                      ),
                    ],
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
