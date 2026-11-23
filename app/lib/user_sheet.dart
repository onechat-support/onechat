import 'package:material_ui/material_ui.dart';

import 'services.dart';
import 'theme.dart';

Color nickColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) {
    return OneChatColors.primary;
  }
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? OneChatColors.primary : Color(0xFF000000 | v);
}

/// Ficha pública de un usuario: perfil mínimo + acciones sociales
/// del MVP (favorito, bloquear, reportar).
Future<void> showUserSheet(
  BuildContext context, {
  required Map<String, dynamic> profile,
  String? roomId,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => _UserSheet(profile: profile, roomId: roomId),
  );
}

class _UserSheet extends StatefulWidget {
  const _UserSheet({required this.profile, this.roomId});
  final Map<String, dynamic> profile;
  final String? roomId;

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  final _svc = OnechatService();
  bool? _isFav;
  bool _busy = false;

  String get _uid => widget.profile['uid'] as String;
  bool get _isMe => _uid == _svc.myUid;

  @override
  void initState() {
    super.initState();
    if (!_isMe) {
      _svc.isFavorite(_uid).then((v) {
        if (mounted) setState(() => _isFav = v);
      });
    }
  }

  Future<void> _toggleFav() async {
    if (_isFav == null) return;
    setState(() => _busy = true);
    await _svc.setFavorite(_uid, !_isFav!);
    if (!mounted) return;
    setState(() {
      _isFav = !_isFav!;
      _busy = false;
    });
  }

  Future<void> _block() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bloquear usuario'),
        content: Text(
            'Dejarás de ver los mensajes de ${widget.profile['nickname']}. Puedes desbloquearlo desde tu perfil.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bloquear')),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.block(_uid);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Usuario bloqueado.')),
    );
  }

  Future<void> _report() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reportar usuario'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Motivo del reporte',
            hintText: 'Describe brevemente lo ocurrido',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar reporte')),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    if (ok != true || reason.isEmpty) return;
    await _svc.report(targetUid: _uid, roomId: widget.roomId, reason: reason);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte enviado. Gracias.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final isGuest = p['is_guest'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: nickColor(p['nickname_color'] as String?),
                child: Text(
                  (p['nickname'] as String).substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['nickname'] as String,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: nickColor(p['nickname_color'] as String?),
                      ),
                    ),
                    Text(isGuest ? 'Invitado' : 'Cuenta registrada',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          if ((p['bio'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            Text(p['bio'] as String),
          ],
          if (!_isMe) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _toggleFav,
                  icon: Icon(
                    _isFav == true ? Icons.favorite : Icons.favorite_border,
                    color: OneChatColors.favorite,
                  ),
                  label:
                      Text(_isFav == true ? 'Es tu favorito' : 'Favorito'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _block,
                  icon: const Icon(Icons.block),
                  label: const Text('Bloquear'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _report,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('Reportar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
