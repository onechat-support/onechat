import 'package:material_ui/material_ui.dart';

import 'config.dart';
import 'services.dart';
import 'strings.dart';
import 'theme.dart';
import 'web_links.dart';

Color nickColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) {
    return OneChatColors.primary;
  }
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? OneChatColors.primary : Color(0xFF000000 | v);
}

/// Ficha pública de un usuario: perfil mínimo + acciones sociales
/// (favorito, bloquear, reportar) y de la Etapa 2 (susurrar dentro
/// de la sala, mensaje privado 1:1).
Future<void> showUserSheet(
  BuildContext context, {
  required Map<String, dynamic> profile,
  String? roomId,
  void Function(Map<String, dynamic> profile)? onWhisper,
  void Function(Map<String, dynamic> profile)? onPrivateMessage,
  bool canModerate = false,
  bool canManageRoles = false,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => _UserSheet(
      profile: profile,
      roomId: roomId,
      onWhisper: onWhisper,
      onPrivateMessage: onPrivateMessage,
      canModerate: canModerate,
      canManageRoles: canManageRoles,
    ),
  );
}

class _UserSheet extends StatefulWidget {
  const _UserSheet(
      {required this.profile,
      this.roomId,
      this.onWhisper,
      this.onPrivateMessage,
      this.canModerate = false,
      this.canManageRoles = false});
  final Map<String, dynamic> profile;
  final String? roomId;
  final void Function(Map<String, dynamic> profile)? onWhisper;
  final void Function(Map<String, dynamic> profile)? onPrivateMessage;
  final bool canModerate;
  final bool canManageRoles;

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  final _svc = OnechatService();
  bool? _isFav;
  bool _busy = false;
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _lastConn;
  String _myRole = 'user';
  List<Map<String, dynamic>> _bans = [];

  String get _uid => widget.profile['uid'] as String;
  bool get _isMe => _uid == _svc.myUid;

  @override
  void initState() {
    super.initState();
    if (!_isMe) {
      _svc.isFavorite(_uid).then((v) {
        if (mounted) setState(() => _isFav = v);
      });
      if (widget.roomId != null && widget.canModerate) {
        _svc.memberState(widget.roomId!, _uid).then((m) {
          if (mounted) setState(() => _member = m);
        });
      }
      // Última IP registrada: la base solo la entrega al
      // Staff global y al dueño (RLS); a los demás, null.
      _svc.lastConnection(_uid).then((c) {
        if (mounted) setState(() => _lastConn = c);
      });
      // Destierro: mi rol manda si la sección existe.
      _svc.myGlobalRole().then((r) {
        if (mounted) setState(() => _myRole = r);
      });
      _reloadBans();
    }
  }

  bool get _canExile =>
      !_isMe && (_myRole == 'staff' || _myRole == 'owner');

  Future<void> _reloadBans() async {
    final bans = await _svc.activeBansFor(_uid);
    if (mounted) setState(() => _bans = bans);
  }

  String _kindLabel(String kind) => switch (kind) {
        'account' => t('exile.kindAccount'),
        'device' => t('exile.kindDevice'),
        'ip' => t('exile.kindIp'),
        _ => kind,
      };

  Future<void> _liftBan(int id) async {
    setState(() => _busy = true);
    try {
      final ok = await _svc.liftPlatformBan(id);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('exile.lifted'))));
        await _reloadBans();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('exile.failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showExileDialog() async {
    final reasonCtrl = TextEditingController();
    int? hours = 168; // 7 días por defecto
    final isOwner = _myRole == 'owner';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(t('exile.title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('exile.warn'), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              DropdownButton<int?>(
                value: hours,
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: 24, child: Text(t('exile.h24'))),
                  DropdownMenuItem(value: 168, child: Text(t('exile.d7'))),
                  DropdownMenuItem(value: 720, child: Text(t('exile.d30'))),
                  DropdownMenuItem(
                    value: null,
                    enabled: isOwner,
                    child: Text(t('exile.permanent')),
                  ),
                ],
                onChanged: (v) => setLocal(() => hours = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: t('exile.reason'),
                  hintText: t('exile.reasonHint'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('sheet.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('exile.apply')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final reason = reasonCtrl.text.trim();
    if (reason.length < 3) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('exile.failed'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final layers = await _svc.applyPlatformBan(_uid, hours, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('exile.applied', {'n': '$layers'}))));
      await _reloadBans();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('exile.failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _connWhen(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  // ---------- Moderación (Etapa 3) ----------

  bool get _mutedActive {
    final until = _member?['muted_until'] as String?;
    if (until == null) return false;
    final t = DateTime.tryParse(until);
    return t != null && t.isAfter(DateTime.now());
  }

  bool get _banned => _member?['banned_at'] != null;

  bool get _featuredActive {
    final until = _member?['featured_until'] as String?;
    if (until == null) return false;
    final t = DateTime.tryParse(until);
    return t != null && t.isAfter(DateTime.now());
  }

  Future<void> _moderate(String action,
      {int? minutes, String? detail, String? confirm}) async {
    if (confirm != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('sheet.confirmTitle')),
          content: Text(confirm),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('sheet.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('sheet.yesApply'))),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _busy = true);
    final done = await _svc.moderateMember(
      roomId: widget.roomId!,
      targetUid: _uid,
      action: action,
      minutes: minutes,
      detail: detail,
    );
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(done
              ? t('sheet.modApplied')
              : t('sheet.modFailed'))),
    );
  }

  Future<void> _muteDialog() async {
    final choice = await showDialog<(int, String)>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(t('sheet.muteTitle', {'nick': '${widget.profile['nickname']}'})),
        children: [
          for (final (mins, label) in [
            (10, t('sheet.dur10')),
            (60, t('sheet.dur60')),
            (1440, t('sheet.dur1440')),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, (mins, label)),
              child: Text(label),
            ),
        ],
      ),
    );
    if (choice == null) return;
    await _moderate('mute',
        minutes: choice.$1, detail: t('sheet.muteDetail', {'dur': choice.$2}));
  }

  Future<void> _setRole(String role, String label) async {
    setState(() => _busy = true);
    final done = await _svc.setRoomRole(
        roomId: widget.roomId!, targetUid: _uid, role: role);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(done
              ? t('sheet.roleNow',
                  {'nick': '${widget.profile['nickname']}', 'role': label})
              : t('sheet.roleFailed'))),
    );
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
        title: Text(t('sheet.blockTitle')),
        content: Text(t('sheet.blockBody',
            {'nick': '${widget.profile['nickname']}'})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('sheet.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('sheet.blockAction'))),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.block(_uid);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('sheet.blocked'))),
    );
  }

  Future<void> _report() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('sheet.reportTitle')),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: t('sheet.reportReason'),
            hintText: t('sheet.reportHint'),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('sheet.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('sheet.reportSend'))),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    if (ok != true || reason.isEmpty) return;
    await _svc.report(targetUid: _uid, roomId: widget.roomId, reason: reason);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('sheet.reported'))),
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
                    Text(isGuest ? t('profile.guest') : t('profile.registered'),
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
          if (_lastConn != null) ...[
            const SizedBox(height: 10),
            Text(
              t('sheet.lastConnection', {
                'ip': _lastConn!['ip'] as String,
                'when': _connWhen(_lastConn!['created_at'] as String),
              }),
              style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
          if (!_isMe) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: [
                if (widget.onPrivateMessage != null)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onPrivateMessage!(widget.profile);
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(t('sheet.privateMessage')),
                  ),
                if (widget.roomId != null && widget.onWhisper != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onWhisper!(widget.profile);
                    },
                    icon: const Icon(Icons.voice_over_off_outlined),
                    label: Text(t('sheet.whisper')),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _toggleFav,
                  icon: Icon(
                    _isFav == true ? Icons.favorite : Icons.favorite_border,
                    color: OneChatColors.favorite,
                  ),
                  label: Text(
                      _isFav == true ? t('sheet.isFavorite') : t('sheet.favorite')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _block,
                  icon: const Icon(Icons.block),
                  label: Text(t('sheet.block')),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _report,
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(t('sheet.report')),
                ),
                if (!isGuest)
                  OutlinedButton.icon(
                    onPressed: () => openExternalUrl(
                        '${AppConfig.siteBaseUrl}/u/${Uri.encodeComponent(p['nickname'] as String)}'),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(t('sheet.viewPage')),
                  ),
              ],
            ),
            if (widget.roomId != null && widget.canModerate) ...[
              const SizedBox(height: 20),
              const Divider(),
              Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(t('mod.panelTitle'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              if (_banned)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(t('sheet.bannedState'),
                      style: const TextStyle(color: Colors.redAccent)),
                )
              else if (_mutedActive)
                Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(t('sheet.mutedState'),
                      style: const TextStyle(color: Colors.orangeAccent)),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_banned)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _moderate('unban'),
                      icon: const Icon(Icons.lock_open_outlined, size: 18),
                      label: Text(t('sheet.unban')),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _moderate('ban',
                              confirm: t('sheet.banConfirm',
                                  {'nick': '${widget.profile['nickname']}'})),
                      icon: const Icon(Icons.gavel, size: 18),
                      label: Text(t('sheet.ban')),
                    ),
                    if (_mutedActive)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _moderate('unmute'),
                        icon: const Icon(Icons.volume_up_outlined, size: 18),
                        label: Text(t('sheet.unmute')),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _muteDialog,
                        icon: const Icon(Icons.volume_off_outlined, size: 18),
                        label: Text(t('sheet.mute')),
                      ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _moderate('kick',
                              confirm: t('sheet.kickConfirm',
                                  {'nick': '${widget.profile['nickname']}'})),
                      icon: const Icon(Icons.exit_to_app, size: 18),
                      label: Text(t('sheet.kick')),
                    ),
                  ],
                  if (_featuredActive)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _moderate('unfeature'),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: Text(t('sheet.unfeature')),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _moderate('feature'),
                      icon: const Icon(Icons.star_border, size: 18),
                      label: Text(t('sheet.feature')),
                    ),
                  if (widget.canManageRoles && !_banned)
                    if (_member?['role'] == 'moderator')
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _setRole('member', t('sheet.roleMember')),
                        icon: const Icon(Icons.shield_outlined, size: 18),
                        label: Text(t('sheet.removeMod')),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _setRole('moderator', t('sheet.roleModerator')),
                        icon: const Icon(Icons.shield, size: 18),
                        label: Text(t('sheet.makeMod')),
                      ),
                ],
              ),
            ],
            // ===== Destierro global (S1): solo Staff/dueño =====
            if (_canExile) ...[
              const SizedBox(height: 20),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.gavel, size: 18, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Text(t('exile.title'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              if (_bans.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(t('exile.activeTitle'),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                for (final b in _bans)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_kindLabel(b['kind'] as String)} · '
                            '${b['expires_at'] == null ? t('exile.permanentLabel') : t('exile.until', {'when': _connWhen(b['expires_at'] as String)})}'
                            ' · ${b['reason']}',
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _liftBan((b['id'] as num).toInt()),
                          child: Text(t('exile.lift')),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _showExileDialog,
                icon: const Icon(Icons.block, size: 18, color: Colors.redAccent),
                label: Text(t('exile.button'),
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
