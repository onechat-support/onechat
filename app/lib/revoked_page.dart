import 'package:material_ui/material_ui.dart';

import 'main.dart';
import 'services.dart';
import 'strings.dart';

/// Pantalla de acceso revocado (Fase S1, el Destierro).
/// Se muestra cuando la cuenta, el dispositivo o la IP
/// están desterrados. A propósito NO dice qué capa lo
/// detectó ni el motivo interno: solo el hecho, la
/// duración y el canal de apelación.
class RevokedPage extends StatelessWidget {
  const RevokedPage({super.key, required this.verdict});

  final Map<String, dynamic> verdict;

  String _fmtWhen(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final permanent = verdict['permanent'] == true;
    final expires = verdict['expires_at'] as String?;
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/logo_onechat.jpg',
                      fit: BoxFit.fitWidth,
                      semanticLabel: 'ONEchat',
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Icon(Icons.block, size: 44, color: Color(0xFFFF5252)),
                  const SizedBox(height: 14),
                  Text(
                    t('revoked.title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    permanent || expires == null
                        ? t('revoked.bodyPermanent')
                        : t('revoked.bodyUntil',
                            {'when': _fmtWhen(expires)}),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('revoked.help'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 26),
                  OutlinedButton(
                    onPressed: () async {
                      await OnechatService().signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const SessionGate()),
                        (_) => false,
                      );
                    },
                    child: Text(t('revoked.signOut')),
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
