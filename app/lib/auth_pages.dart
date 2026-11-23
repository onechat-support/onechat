import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'services.dart';
import 'theme.dart';

String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nick = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _svc = OnechatService();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _nick.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nick = _nick.text.trim();
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
      final profile = await _svc.signUp(
        email: _email.text.trim(),
        password: _pass.text,
        nickname: nick,
      );
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _busy = false;
          _info =
              'Cuenta creada. Te enviamos un correo de confirmación: ábrelo y toca el enlace (vuelves a la app). Luego inicia sesión y tu nickname «$nick» se reservará automáticamente a tu nombre. Si el correo no era el tuyo, no confirmes nada: ese nickname seguirá libre.';
        });
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomePage(profile: profile)),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AuthException ? friendlyAuthError(e) : _clean(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nick,
                    decoration: const InputDecoration(
                      labelText: 'Nickname (único, queda reservado)',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Creando…' : 'CREAR CUENTA'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: OneChatColors.mention)),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 14),
                    Text(_info!,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: OneChatColors.secondary)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla a la que llega el enlace de «¿Olvidaste tu contraseña?»:
/// el enlace abre una sesión de recuperación y aquí se fija la clave
/// nueva. Al terminar se cierra esa sesión para entrar ya con la
/// clave nueva desde la pantalla de acceso.
class UpdatePasswordPage extends StatefulWidget {
  const UpdatePasswordPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<UpdatePasswordPage> createState() => _UpdatePasswordPageState();
}

class _UpdatePasswordPageState extends State<UpdatePasswordPage> {
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _svc = OnechatService();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p1 = _pass.text;
    if (p1.length < 8) {
      setState(() => _error = 'Usa al menos 8 caracteres.');
      return;
    }
    if (p1 != _pass2.text) {
      setState(() => _error = 'Las dos contraseñas no coinciden.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _svc.updatePassword(p1);
      await _svc.signOut();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is AuthException ? friendlyAuthError(e) : _clean(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = _svc.isSignedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_done) ...[
                    const Icon(Icons.check_circle_outline,
                        size: 56, color: OneChatColors.primary),
                    const SizedBox(height: 16),
                    const Text(
                      'Contraseña actualizada. Ahora entra con tu nickname y tu clave nueva.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: widget.onDone,
                      child: const Text('IR A LA PANTALLA DE ACCESO'),
                    ),
                  ] else if (!hasSession) ...[
                    const Text(
                      'Este enlace ya se usó o venció. Pide uno nuevo: en la pantalla de acceso escribe tu nickname, toca «CHATEAR DIRECTAMENTE» y luego «¿Olvidaste tu contraseña?».',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: widget.onDone,
                      child: const Text('IR A LA PANTALLA DE ACCESO'),
                    ),
                  ] else ...[
                    const Text(
                      'Escribe tu contraseña nueva. La vas a usar junto con tu nickname para entrar.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _pass,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña nueva',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _pass2,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Repite la contraseña nueva',
                        prefixIcon: Icon(Icons.lock_reset),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Guardando…' : 'GUARDAR CONTRASEÑA'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: OneChatColors.mention)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Para cuentas que iniciaron sesión sin perfil (p. ej. registro con
/// confirmación de correo): aquí eligen su nickname y queda reservado.
class NicknameSetupPage extends StatefulWidget {
  const NicknameSetupPage({super.key});

  @override
  State<NicknameSetupPage> createState() => _NicknameSetupPageState();
}

class _NicknameSetupPageState extends State<NicknameSetupPage> {
  final _nick = TextEditingController();
  final _svc = OnechatService();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Si eligió nickname al registrarse, viaja con su cuenta:
    // se intenta reservar automáticamente sin que lo reescriba.
    final saved = _svc.currentUser?.userMetadata?['nickname'] as String?;
    if (saved != null && saved.isNotEmpty) {
      _nick.text = saved;
      WidgetsBinding.instance.addPostFrameCallback((_) => _submit());
    }
  }

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nick = _nick.text.trim();
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
      final profile = await _svc.completeProfile(nick);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomePage(profile: profile)),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is Exception &&
                e.toString().contains('23505')
            ? 'Ese nickname ya está en uso. Prueba con otro.'
            : _clean(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elige tu nickname')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tu cuenta ya entró. Falta tu nickname: será único y quedará reservado para ti.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nick,
                    decoration: const InputDecoration(
                      labelText: 'Tu nickname',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_busy ? 'Guardando…' : 'CONTINUAR'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: OneChatColors.mention)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
