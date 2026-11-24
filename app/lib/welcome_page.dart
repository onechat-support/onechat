import 'package:material_ui/material_ui.dart';

import 'auth_pages.dart';
import 'home_page.dart';
import 'services.dart';
import 'strings.dart';
import 'theme.dart';

/// Pantalla de acceso unificada (pedido de Mario, 2026-11-23):
/// solo se pide el nickname. Si es de una cuenta registrada, ahí
/// mismo se habilita la contraseña y se entra con nickname + clave.
/// Si está libre o es de invitado, se entra directo a chatear.
/// El correo vive solo en el registro y en la recuperación.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _svc = OnechatService();
  bool _busy = false;
  bool _needsPassword = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _nicknameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _nick => _nicknameController.text.trim();

  Future<void> _continue() async {
    if (_needsPassword) {
      await _loginRegistered();
      return;
    }
    final invalid = OnechatService.validateNickname(_nick);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final status = await _svc.nicknameStatus(_nick);
      if (!mounted) return;
      if (status == 'registered') {
        setState(() {
          _busy = false;
          _needsPassword = true;
          _info = t('welcome.registeredNotice');
        });
        return;
      }
      await _enterAsGuest();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = t('welcome.checkFailed');
      });
    }
  }

  Future<void> _enterAsGuest() async {
    try {
      final profile = await _svc.enterAsGuest(_nick);
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

  Future<void> _loginRegistered() async {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = t('welcome.typePassword'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final profile =
          await _svc.loginWithNickname(_nick, _passwordController.text);
      if (!mounted) return;
      if (profile == null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const NicknameSetupPage()),
          (_) => false,
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage(profile: profile)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Diálogo de recuperación: el correo solo se usa para esto y para
  /// el registro, nunca como identificación de acceso.
  Future<void> _recoveryDialog({required bool isReset}) async {
    final emailController = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isReset
            ? t('welcome.resetTitle')
            : t('welcome.resend')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isReset
                ? t('welcome.resetBody')
                : t('welcome.resendBody')),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: t('welcome.accountEmail'),
                prefixIcon: const Icon(Icons.mail_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('welcome.cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(emailController.text.trim()),
            child: Text(t('welcome.send')),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (isReset) {
        await _svc.recoverPassword(email);
      } else {
        await _svc.resendConfirmation(email);
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _info = isReset
            ? t('welcome.resetSent', {'email': email})
            : t('welcome.resendSent', {'email': email});
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is Exception ? friendlyAuthError(e) : t('welcome.genericError');
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (final lang in ['es', 'en'])
                        TextButton(
                          onPressed: () =>
                              setState(() => appLanguage.value = lang),
                          child: Text(
                            lang.toUpperCase(),
                            style: TextStyle(
                              fontWeight: appLanguage.value == lang
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: appLanguage.value == lang
                                  ? OneChatColors.primary
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Logo definitivo de la plataforma (Mario,
                  // 2026-11-24): wordmark blanco sobre el degradado
                  // oficial, con la píldora de Early Access.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/logo_onechat.jpg',
                      fit: BoxFit.fitWidth,
                      semanticLabel: 'ONEchat',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('welcome.tagline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  TextField(
                    controller: _nicknameController,
                    textInputAction: _needsPassword
                        ? TextInputAction.next
                        : TextInputAction.go,
                    onSubmitted: (_) => _busy ? null : _continue(),
                    onChanged: (_) {
                      if (_needsPassword) {
                        setState(() {
                          _needsPassword = false;
                          _info = null;
                          _error = null;
                          _passwordController.clear();
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: t('welcome.nickname'),
                      hintText: t('welcome.nicknameHint'),
                      prefixIcon: const Icon(Icons.alternate_email),
                    ),
                  ),
                  if (_needsPassword) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _busy ? null : _continue(),
                      decoration: InputDecoration(
                        labelText: t('welcome.password'),
                        prefixIcon: const Icon(Icons.lock_outline),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _continue,
                    child: _busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(_needsPassword
                            ? t('welcome.enterAccount')
                            : t('welcome.enterChat')),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: OneChatColors.mention),
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _info!,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: OneChatColors.secondary),
                    ),
                  ],
                  if (_needsPassword) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _recoveryDialog(isReset: true),
                          child: Text(t('welcome.forgot')),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _recoveryDialog(isReset: false),
                          child: Text(t('welcome.resend')),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SignUpPage()),
                              ),
                      child: Text(t('welcome.createAccount')),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Aviso de privacidad del registro de IP
                  // (v1.14): quien entra sabe que su conexión
                  // queda registrada, y para qué.
                  Text(
                    t('welcome.privacyNote'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
