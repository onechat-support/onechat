import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dm_pages.dart';
import 'services.dart';
import 'strings.dart';
import 'theme.dart';
import 'user_sheet.dart';

/// Sala de chat (MVP): historial + tiempo real + presencia básica.
/// Los mensajes de usuarios bloqueados no se muestran.
class ChatPage extends StatefulWidget {
  const ChatPage(
      {super.key,
      required this.room,
      required this.myProfile,
      this.embedded = false,
      this.onExit});
  final Map<String, dynamic> room;
  final Map<String, dynamic> myProfile;

  /// Incrustada como pestaña (la Sala General al entrar): no es una
  /// ruta, así que «salir» cambia de pestaña en vez de hacer pop.
  final bool embedded;
  final VoidCallback? onExit;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _svc = OnechatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final Map<String, Map<String, dynamic>> _profiles = {};
  final Set<int> _knownIds = {};
  final Set<int> _knownWhisperIds = {};
  Set<String> _blocked = {};
  List<Map<String, dynamic>> _occupants = [];
  RealtimeChannel? _msgChannel;
  RealtimeChannel? _presenceChannel;
  RealtimeChannel? _whisperChannel;
  Map<String, dynamic>? _whisperTo;
  bool _loading = true;
  bool _sending = false;

  // Moderación (Etapa 3): mi fila de miembro y la de todos (roles y
  // destacados); los poderes se derivan de ellas y del rol global.
  Map<String, dynamic>? _myMember;
  Map<String, Map<String, dynamic>> _membersInfo = {};

  bool get _isStaffGlobal =>
      widget.myProfile['global_role'] == 'staff' ||
      widget.myProfile['global_role'] == 'owner';
  bool get _isRoomOwner => widget.room['owner_uid'] == _svc.myUid;

  bool get _canModerate =>
      _isStaffGlobal ||
      _isRoomOwner ||
      _myMember?['role'] == 'owner' ||
      _myMember?['role'] == 'moderator';

  bool get _canManageRoles => _isStaffGlobal || _isRoomOwner;

  bool get _iAmBanned => _myMember?['banned_at'] != null;

  DateTime? get _myMutedUntil {
    final raw = _myMember?['muted_until'] as String?;
    if (raw == null) return null;
    final t = DateTime.tryParse(raw);
    return (t != null && t.isAfter(DateTime.now())) ? t : null;
  }

  String get _roomId => widget.room['id'] as String;

  @override
  void initState() {
    super.initState();
    _profiles[widget.myProfile['uid'] as String] = widget.myProfile;
    _init();
  }

  /// Prepara un susurro para la línea de tiempo: guarda los perfiles
  /// incluidos y lo marca como susurro.
  Map<String, dynamic> _prepareWhisper(Map<String, dynamic> raw) {
    final row = Map<String, dynamic>.from(raw);
    final sender = row.remove('sender');
    final target = row.remove('target');
    final sUid = row['sender_uid'] as String?;
    final tUid = row['target_uid'] as String?;
    if (sUid != null && sender is Map) {
      _profiles[sUid] = {'uid': sUid, ...Map<String, dynamic>.from(sender)};
    }
    if (tUid != null && target is Map) {
      _profiles[tUid] = {'uid': tUid, ...Map<String, dynamic>.from(target)};
    }
    row['is_whisper'] = true;
    return row;
  }

  Future<void> _init() async {
    // En paralelo: bloqueos e historial (con perfiles incluidos) en un
    // solo viaje cada uno; la unión a la sala no espera a nadie.
    _svc.joinRoom(_roomId);
    final results = await Future.wait([
      _svc.fetchBlockedUids(),
      _svc.fetchMessagesWithProfiles(_roomId),
      _svc.fetchWhispers(_roomId),
      _svc.memberState(_roomId, _svc.myUid!),
      _svc.roomMembersInfo(_roomId),
    ]);
    _blocked = results[0] as Set<String>;
    final (rows, profiles) =
        results[1] as (List<Map<String, dynamic>>, Map<String, Map<String, dynamic>>);
    _profiles.addAll(profiles);
    final whisperRows = results[2] as List<Map<String, dynamic>>;
    _myMember = results[3] as Map<String, dynamic>?;
    _membersInfo = results[4] as Map<String, Map<String, dynamic>>;
    if (!mounted) return;
    setState(() {
      for (final r in rows.where((r) => !_isBlocked(r))) {
        _messages.add(r);
        final id = r['id'];
        if (id is int) _knownIds.add(id);
      }
      for (final w in whisperRows.where((w) => !_isBlocked(w))) {
        _messages.add(_prepareWhisper(w));
        final id = w['id'];
        if (id is int) _knownWhisperIds.add(id);
      }
      // Línea de tiempo única: mensajes y susurros por hora.
      _messages.sort((a, b) => '${a['created_at'] ?? ''}'
          .compareTo('${b['created_at'] ?? ''}'));
      _loading = false;
    });
    _jumpToBottom();

    _whisperChannel = _svc.subscribeWhispers(_roomId, (row) async {
      final id = row['id'];
      if (id is int && _knownWhisperIds.contains(id)) return;
      if (_isBlocked(row)) return;
      for (final uid in [row['sender_uid'], row['target_uid']]) {
        if (uid is String && !_profiles.containsKey(uid)) {
          final p = await _svc.profileByUid(uid);
          if (p != null) _profiles[uid] = p;
        }
      }
      if (!mounted) return;
      setState(() {
        _messages.add(_prepareWhisper(row));
        if (id is int) _knownWhisperIds.add(id);
      });
      _jumpToBottom();
    });

    _msgChannel = _svc.subscribeMessages(_roomId, (row) async {
      final id = row['id'];
      if (id is int && _knownIds.contains(id)) return; // ya lo mostré (eco)
      if (_isBlocked(row)) return;
      final sender = row['sender_uid'] as String?;
      if (sender != null && !_profiles.containsKey(sender)) {
        final p = await _svc.profileByUid(sender);
        if (p != null) _profiles[sender] = p;
      }
      if (!mounted) return;
      setState(() {
        _messages.add(row);
        if (id is int) _knownIds.add(id);
      });
      _jumpToBottom();
    });

    _presenceChannel = _svc.joinPresence(
      roomId: _roomId,
      me: {
        'uid': _svc.myUid,
        'nickname': widget.myProfile['nickname'],
        'nickname_color': widget.myProfile['nickname_color'],
      },
      onSync: (occupants) {
        if (!mounted) return;
        setState(() => _occupants = occupants);
      },
    );
  }

  bool _isBlocked(Map<String, dynamic> row) {
    final s = row['sender_uid'] as String?;
    return s != null && _blocked.contains(s);
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    final a = _msgChannel;
    final b = _presenceChannel;
    final c = _whisperChannel;
    if (a != null) _svc.unsubscribe(a);
    if (b != null) _svc.unsubscribe(b);
    if (c != null) _svc.unsubscribe(c);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startWhisper(Map<String, dynamic> profile) {
    setState(() => _whisperTo = profile);
  }

  Future<void> _startDm(Map<String, dynamic> profile) async {
    final conv = await _svc.getOrCreateConversation(profile['uid'] as String);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DmChatPage(
          conversationId: conv['id'] as String,
          other: profile,
          myProfile: widget.myProfile,
        ),
      ),
    );
  }

  Future<void> _sendWhisper(String text) async {
    final target = _whisperTo!;
    final temp = <String, dynamic>{
      'id': -DateTime.now().microsecondsSinceEpoch,
      'room_id': _roomId,
      'sender_uid': _svc.myUid,
      'target_uid': target['uid'],
      'body': text,
      'is_whisper': true,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() {
      _messages.add(temp);
      _sending = true;
    });
    _jumpToBottom();
    try {
      final inserted = await _svc.sendWhisper(
        roomId: _roomId,
        targetUid: target['uid'] as String,
        body: text,
      );
      final realId = inserted['id'];
      if (realId is int) _knownWhisperIds.add(realId);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexOf(temp);
        if (i >= 0) _messages[i] = {...inserted, 'is_whisper': true};
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.remove(temp));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('chat.whisperFailed', {'e': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    if (_whisperTo != null) {
      await _sendWhisper(text);
      return;
    }
    // Eco optimista: el mensaje se pinta al instante, sin esperar al
    // servidor; si el envío falla, se retira y se avisa.
    final temp = <String, dynamic>{
      'id': -DateTime.now().microsecondsSinceEpoch,
      'room_id': _roomId,
      'sender_uid': _svc.myUid,
      'sender_nickname': widget.myProfile['nickname'],
      'body': text,
      'mentions': <String>[],
      'kind': 'text',
    };
    setState(() {
      _messages.add(temp);
      _sending = true;
    });
    _jumpToBottom();
    try {
      final inserted = await _svc.sendMessage(
        roomId: _roomId,
        body: text,
        blockedUids: _blocked,
        senderNickname: widget.myProfile['nickname'] as String,
      );
      final realId = inserted['id'];
      if (realId is int) _knownIds.add(realId);
      if (!mounted) return;
      setState(() {
        final i = _messages.indexOf(temp);
        if (i >= 0) _messages[i] = inserted;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.remove(temp));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('chat.sendFailed', {'e': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Traducciones pedidas en esta sesión de sala (Etapa 5):
  /// clave `m<id>` mensajes, `w<id>` susurros.
  final Map<String, String> _translations = {};

  /// Mantener presionado un mensaje: traducirlo al idioma del
  /// perfil (o volver al original si ya estaba traducido).
  Future<void> _translateMenu(String key, String body) async {
    final has = _translations.containsKey(key);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.translate),
          title: Text(has ? t('chat.showOriginal') : t('chat.translate')),
          onTap: () => Navigator.pop(context, 'go'),
        ),
      ),
    );
    if (action != 'go' || !mounted) return;
    if (has) {
      setState(() => _translations.remove(key));
      return;
    }
    try {
      final r = await _svc.translateText(body);
      if (!mounted) return;
      final detected = r['detected'] as String? ?? '';
      if (detected == appLanguage.value) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('chat.alreadyYourLanguage'))),
        );
        return;
      }
      final translated = r['translated'] as String? ?? '';
      if (translated.isEmpty) throw Exception('empty');
      setState(() => _translations[key] = translated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('chat.translateFailed'))),
      );
    }
  }

  /// Un susurro en la línea de tiempo: morado y en cursiva, solo lo
  /// ven emisor y destinatario. Tocar = responder susurrando.
  Widget _whisperTile(Map<String, dynamic> m, Map<String, dynamic>? p) {
    final senderUid = m['sender_uid'] as String?;
    final targetUid = m['target_uid'] as String?;
    final isMe = senderUid == _svc.myUid;
    final otherUid = isMe ? targetUid : senderUid;
    final other = otherUid == null ? null : _profiles[otherUid];
    final otherNick = other?['nickname'] as String? ?? '···';
    final senderNick = p?['nickname'] as String? ?? '···';
    return InkWell(
      onLongPress: () =>
          _translateMenu('w${m['id']}', m['body'] as String),
      onTap: other == null
          ? null
          : () async {
              final full = await _svc.profileByUid(otherUid!) ?? other;
              if (mounted) _startWhisper(full);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                text: isMe
                    ? t('chat.whisperTo', {'nick': otherNick})
                    : t('chat.whisperFrom', {'nick': senderNick}),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  color: OneChatColors.whisper,
                ),
              ),
              TextSpan(
                text: m['body'] as String,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: OneChatColors.whisper,
                ),
              ),
              if (_translations['w${m['id']}'] != null)
                TextSpan(
                  text: '\n🌐 ${_translations['w${m['id']}']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Etiqueta bajo el nombre en la lista de ocupantes: rol en la
  /// sala o destacado vigente.
  Widget? _occupantBadge(String? uid) {
    if (uid == null) return null;
    final info = _membersInfo[uid];
    if (info == null) return null;
    if (widget.room['owner_uid'] == uid) return Text(t('chat.roleRoomOwner'));
    final role = info['role'] as String?;
    if (role == 'moderator') return Text(t('chat.roleModerator'));
    if (role == 'owner') return Text(t('chat.roleRoomOwner'));
    final feat = info['featured_until'] as String?;
    if (feat != null) {
      final until = DateTime.tryParse(feat);
      if (until != null && until.isAfter(DateTime.now())) {
        return Text(t('chat.featured'));
      }
    }
    return null;
  }

  String _verb(String action) => t('mod.verb.$action');

  /// Panel de moderación de la sala: sanciones vigentes (con opción
  /// de levantarlas) y registro de auditoría.
  void _showModerationPanel() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<List<dynamic>> load() => Future.wait([
                _svc.fetchSanctioned(_roomId),
                _svc.fetchModActions(_roomId),
              ]);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            builder: (_, scroll) => FutureBuilder<List<dynamic>>(
              future: load(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final sanctioned =
                    snap.data![0] as List<Map<String, dynamic>>;
                final actions = snap.data![1] as List<Map<String, dynamic>>;
                return ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                  children: [
                    Text(t('mod.panelTitle'),
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(t('mod.activeSanctions'),
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (sanctioned.isEmpty)
                      Text(t('mod.noSanctions')),
                    for (final s in sanctioned)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${(s['member'] as Map?)?['nickname'] ?? '···'}'),
                        subtitle: Text(s['banned_at'] != null
                            ? t('mod.bannedState')
                            : t('mod.mutedState')),
                        trailing: TextButton(
                          child: Text(s['banned_at'] != null
                              ? t('mod.liftBan')
                              : t('mod.liftMute')),
                          onPressed: () async {
                            await _svc.moderateMember(
                              roomId: _roomId,
                              targetUid: s['uid'] as String,
                              action:
                                  s['banned_at'] != null ? 'unban' : 'unmute',
                            );
                            setSheet(() {});
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text(t('mod.logTitle'),
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (actions.isEmpty)
                      Text(t('mod.noLog')),
                    for (final a in actions)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${(a['actor'] as Map?)?['nickname'] ?? '···'} '
                          '${_verb(a['action'] as String)} '
                          '${(a['target'] as Map?)?['nickname'] ?? '···'}'
                          '${a['detail'] != null ? ' (${a['detail']})' : ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showOccupants() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('chat.occupantsTitle', {'n': '${_occupants.length}'}),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_occupants.isEmpty)
              Text(t('chat.onlyYou')),
            for (final o in _occupants)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle,
                    size: 10, color: OneChatColors.primary),
                title: Text('${o['nickname'] ?? ''}'),
                subtitle: _occupantBadge(o['uid'] as String?),
                onTap: () async {
                  Navigator.pop(context);
                  final uid = o['uid'] as String?;
                  if (uid == null) return;
                  final p = _profiles[uid] ?? await _svc.profileByUid(uid);
                  if (p != null && mounted) {
                    showUserSheet(context,
                        profile: p,
                        roomId: _roomId,
                        onWhisper: _startWhisper,
                        onPrivateMessage: _startDm,
                        canModerate: _canModerate,
                        canManageRoles: _canManageRoles);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_iAmBanned) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.room['name'] as String)),
        body: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gavel, size: 44, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                t('chat.bannedTitle'),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                t('chat.bannedBody'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (widget.onExit != null) {
                    widget.onExit!();
                  } else {
                    Navigator.of(context).pop();
                  }
                },
                child: Text(t('chat.backToRooms')),
              ),
            ],
          ),
        ),
      );
    }
    final mutedUntil = _myMutedUntil;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room['name'] as String),
            Text(
              _occupants.isEmpty
                  ? t('chat.publicRoom')
                  : t('chat.online', {'n': '${_occupants.length}'}),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (_canModerate)
            IconButton(
              icon: const Icon(Icons.shield_outlined),
              tooltip: t('chat.modTooltip'),
              onPressed: _showModerationPanel,
            ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: t('chat.occupantsTooltip'),
            onPressed: _showOccupants,
          ),
        ],
      ),
      body: Column(
        children: [
          if ((widget.room['welcome_msg'] as String?)?.isNotEmpty == true)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(widget.room['welcome_msg'] as String,
                  textAlign: TextAlign.center),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(t('chat.empty')))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final sender = m['sender_uid'] as String?;
                          final p = sender == null ? null : _profiles[sender];
                          // El perfil manda si existe; si el autor ya no
                          // tiene perfil (invitado que salió), se usa la
                          // foto del nickname guardada en el mensaje.
                          final nick = p?['nickname'] as String? ??
                              m['sender_nickname'] as String? ??
                              '···';
                          final isMe = sender == _svc.myUid;
                          if (m['is_whisper'] == true) {
                            return _whisperTile(m, p);
                          }
                          final mentionsMe = (m['mentions'] as List?)
                                  ?.contains(_svc.myUid) ==
                              true;
                          return InkWell(
                            onTap: p == null
                                ? null
                                : () => showUserSheet(context,
                                    profile: p,
                                    roomId: _roomId,
                                    onWhisper: _startWhisper,
                                    onPrivateMessage: _startDm,
                                    canModerate: _canModerate,
                                    canManageRoles: _canManageRoles),
                            onLongPress: () => _translateMenu(
                                'm${m['id']}', m['body'] as String),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text: '$nick: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: nickColor(
                                            p?['nickname_color'] as String?),
                                      ),
                                    ),
                                    TextSpan(
                                      text: m['body'] as String,
                                      style: TextStyle(
                                        color: mentionsMe
                                            ? OneChatColors.mention
                                            : null,
                                        fontWeight: mentionsMe
                                            ? FontWeight.w600
                                            : null,
                                      ),
                                    ),
                                    if (isMe)
                                      TextSpan(
                                        text: t('chat.youSuffix'),
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey),
                                      ),
                                    if (_translations['m${m['id']}'] != null)
                                      TextSpan(
                                        text:
                                            '\n🌐 ${_translations['m${m['id']}']}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_whisperTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.lock_outline,
                      size: 16, color: OneChatColors.whisper),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('chat.whisperingTo', {'nick': '${_whisperTo!['nickname']}'}),
                      style: const TextStyle(
                          color: OneChatColors.whisper,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: t('chat.cancelWhisper'),
                    onPressed: () => setState(() => _whisperTo = null),
                  ),
                ],
              ),
            ),
          if (mutedUntil != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Icon(Icons.volume_off_outlined,
                      size: 16, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('chat.mutedBanner', {
                        'time':
                            '${mutedUntil.toLocal().hour.toString().padLeft(2, '0')}:${mutedUntil.toLocal().minute.toString().padLeft(2, '0')}'
                      }),
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: mutedUntil == null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: mutedUntil != null
                            ? t('chat.mutedHint')
                            : _whisperTo != null
                                ? t('chat.hintWhisper')
                                : t('chat.hintMessage'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending || mutedUntil != null ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: t('chat.sendTooltip'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
