import 'package:flutter/services.dart' as fservices;
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard_pages.dart';
import 'dm_pages.dart';
import 'fx.dart';
import 'report_pages.dart';
import 'services.dart';
import 'strings.dart';
import 'theme.dart';
import 'user_sheet.dart';
import 'youtube_card.dart';

/// Sala de chat (MVP): historial + tiempo real + presencia básica.
/// Los mensajes de usuarios bloqueados no se muestran.
class ChatPage extends StatefulWidget {
  const ChatPage(
      {super.key,
      required this.room,
      required this.myProfile,
      this.embedded = false,
      this.onExit,
      this.extraActions});
  final Map<String, dynamic> room;
  final Map<String, dynamic> myProfile;

  /// Acciones extra en la barra (p. ej. el icono de Ayuda del Staff
  /// cuando esta sala es la pestaña General).
  final List<Widget>? extraActions;

  /// Incrustada como pestaña (la Sala General al entrar): no es una
  /// ruta, así que «salir» cambia de pestaña en vez de hacer pop.
  final bool embedded;
  final VoidCallback? onExit;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final _svc = OnechatService();
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _mentionHints = [];
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

  // Lote C: última altura del teclado (para subir la conversación
  // cuando se abre, punto 5) y freno del sonido de recepción.
  double _lastInset = 0;
  DateTime _lastReceiveSound = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _soundOn => widget.myProfile['sound_enabled'] != false;
  bool get _vibrateOn => widget.myProfile['vibrate_enabled'] != false;

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view =
        WidgetsBinding.instance.platformDispatcher.views.first;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final opened = inset > _lastInset + 80;
    _lastInset = inset;
    if (opened) {
      // El teclado terminó de abrir: la conversación sube con él.
      Future.delayed(const Duration(milliseconds: 280), _jumpToBottom);
    }
  }

  /// Sonidos del chat (punto 16): mención (con vibración) y
  /// recepción con freno para salas movidas.
  void _soundForIncoming(Map<String, dynamic> row, {bool whisper = false}) {
    if (!_soundOn && !_vibrateOn) return;
    final myNick =
        (widget.myProfile['nickname'] as String? ?? '').toLowerCase();
    final body = (row['body'] as String? ?? '').toLowerCase();
    final mentionsMe = whisper ||
        (myNick.isNotEmpty && body.contains('@$myNick'));
    if (mentionsMe) {
      if (_soundOn) playSound('mention');
      if (_vibrateOn) buzz();
      return;
    }
    if (!_soundOn) return;
    final now = DateTime.now();
    if (now.difference(_lastReceiveSound) <
        const Duration(milliseconds: 2500)) {
      return;
    }
    _lastReceiveSound = now;
    playSound('receive');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setWakelock(true); // Punto 6: pantalla encendida en el chat.
    _profiles[widget.myProfile['uid'] as String] = widget.myProfile;
    _input.addListener(_updateMentionHints);
    _init();
  }

  /// Punto 7: si mi perfil cambia en la pestaña Perfil (p. ej. el
  /// color del nick), la sala ya montada — la General sobre todo —
  /// debe reflejarlo al instante, no con la foto vieja del inicio.
  @override
  void didUpdateWidget(ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.myProfile['nickname_color'] !=
            widget.myProfile['nickname_color'] ||
        oldWidget.myProfile['nickname'] != widget.myProfile['nickname']) {
      _profiles[widget.myProfile['uid'] as String] = widget.myProfile;
      if (mounted) setState(() {});
    }
  }

  // ---------- Menciones (punto 1) ----------

  /// Inserta «@Nick » en el campo de texto, donde va el cursor.
  void _mention(Map<String, dynamic> profile) {
    final nick = profile['nickname'] as String;
    final text = _input.text;
    final sel = _input.selection;
    final at = (sel.start >= 0 && sel.start <= text.length)
        ? sel.start
        : text.length;
    final insert = '@$nick ';
    _input.value = TextEditingValue(
      text: text.replaceRange(at, at, insert),
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
    _inputFocus.requestFocus();
  }

  /// Autocompletado: si la palabra que se está escribiendo empieza
  /// con @, sugiere nicks de la sala que coincidan.
  void _updateMentionHints() {
    final text = _input.text;
    final cursor = _input.selection.start;
    if (cursor < 0 || cursor > text.length) return;
    final upto = text.substring(0, cursor);
    final match = RegExp(r'@([A-Za-z0-9_]*)$').firstMatch(upto);
    if (match == null) {
      if (_mentionHints.isNotEmpty) {
        setState(() => _mentionHints = []);
      }
      return;
    }
    final partial = match.group(1)!.toLowerCase();
    final seen = <String>{};
    final hints = <Map<String, dynamic>>[];
    for (final p in _profiles.values) {
      final nick = p['nickname'] as String?;
      if (nick == null) continue;
      final lower = nick.toLowerCase();
      if (p['uid'] == _svc.myUid || seen.contains(lower)) continue;
      if (lower.startsWith(partial)) {
        seen.add(lower);
        hints.add(p);
      }
    }
    hints.sort((a, b) => (a['nickname'] as String)
        .toLowerCase()
        .compareTo((b['nickname'] as String).toLowerCase()));
    final top = hints.take(6).toList();
    if (top.length != _mentionHints.length ||
        (top.isNotEmpty &&
            _mentionHints.isNotEmpty &&
            top.first['uid'] != _mentionHints.first['uid']) ||
        (top.isEmpty != _mentionHints.isEmpty)) {
      setState(() => _mentionHints = top);
    }
  }

  void _pickMentionHint(Map<String, dynamic> profile) {
    final nick = profile['nickname'] as String;
    final text = _input.text;
    final cursor = _input.selection.start;
    if (cursor < 0 || cursor > text.length) return;
    final upto = text.substring(0, cursor);
    final match = RegExp(r'@([A-Za-z0-9_]*)$').firstMatch(upto);
    if (match == null) return;
    final start = cursor - match.group(0)!.length;
    final insert = '@$nick ';
    _input.value = TextEditingValue(
      text: text.replaceRange(start, cursor, insert) +
          text.substring(cursor),
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    _inputFocus.requestFocus();
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
      if (row['target_uid'] == _svc.myUid &&
          row['sender_uid'] != _svc.myUid) {
        _soundForIncoming(row, whisper: true);
      }
      for (final uid in [row['sender_uid'], row['target_uid']]) {
        if (uid is String && !_profiles.containsKey(uid)) {
          final p = await _svc.profileByUid(uid);
          if (p != null) _profiles[uid] = p;
        }
      }
      if (!mounted) return;
      if (id is int && _knownWhisperIds.contains(id)) return;
      setState(() {
        final prepared = _prepareWhisper(row);
        // Si el eco es de MI susurro y aún está el temporal, lo
        // reemplazo en su lugar (sin parpadeo de duplicado).
        final ti = row['sender_uid'] == _svc.myUid
            ? _messages.indexWhere((m) =>
                (m['id'] is int && (m['id'] as int) < 0) &&
                m['is_whisper'] == true &&
                m['body'] == row['body'])
            : -1;
        if (ti >= 0) {
          _messages[ti] = prepared;
        } else {
          _messages.add(prepared);
        }
        if (id is int) _knownWhisperIds.add(id);
      });
      _jumpToBottom();
    });

    _msgChannel = _svc.subscribeMessages(_roomId, (row) async {
      final id = row['id'];
      if (id is int && _knownIds.contains(id)) return; // ya lo mostré (eco)
      if (_isBlocked(row)) return;
      if (row['sender_uid'] != _svc.myUid && row['kind'] == 'text') {
        _soundForIncoming(row);
      }
      final sender = row['sender_uid'] as String?;
      if (sender != null && !_profiles.containsKey(sender)) {
        final p = await _svc.profileByUid(sender);
        if (p != null) _profiles[sender] = p;
      }
      if (!mounted) return;
      if (id is int && _knownIds.contains(id)) return;
      setState(() {
        // Si el eco es de MI mensaje y aún está el temporal, lo
        // reemplazo en su lugar (sin parpadeo de duplicado).
        final ti = row['sender_uid'] == _svc.myUid
            ? _messages.indexWhere((m) =>
                (m['id'] is int && (m['id'] as int) < 0) &&
                m['body'] == row['body'])
            : -1;
        if (ti >= 0) {
          _messages[ti] = row;
        } else {
          _messages.add(row);
        }
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

    // Punto 12: aviso de sistema «se conectó» (con freno de 10 min
    // para no spamear al entrar y salir de la sala).
    if (_myMember?['banned_at'] == null) {
      final already = await _svc.recentOwnSystemNotice(_roomId, 'join');
      if (!already) {
        final row = await _svc.sendSystemNotice(_roomId, 'join');
        if (row != null && mounted) {
          final id = row['id'];
          if (id is int) _knownIds.add(id);
          setState(() => _messages.add(row));
        }
      }
    }
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
    WidgetsBinding.instance.removeObserver(this);
    setWakelock(false);
    // Punto 12: aviso «se desconectó» (mejor esfuerzo al salir).
    if (_myMember?['banned_at'] == null) {
      _svc.sendSystemNotice(_roomId, 'leave');
    }
    final a = _msgChannel;
    final b = _presenceChannel;
    final c = _whisperChannel;
    if (a != null) _svc.unsubscribe(a);
    if (b != null) _svc.unsubscribe(b);
    if (c != null) _svc.unsubscribe(c);
    _input.removeListener(_updateMentionHints);
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Aviso del sistema dentro de la sala (punto 12): centrado y
  /// discreto. Las sanciones NO muestran el nick del castigado.
  Widget _systemTile(Map<String, dynamic> m) {
    final code = m['body'] as String? ?? '';
    final nick = m['sender_nickname'] as String? ?? '';
    final text = switch (code) {
      'join' => t('chat.systemJoined', {'nick': nick}),
      'leave' => t('chat.systemLeft', {'nick': nick}),
      'mod:mute' => t('chat.systemMuted'),
      'mod:ban' => t('chat.systemBanned'),
      _ => code,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _startWhisper(Map<String, dynamic> profile) {
    setState(() => _whisperTo = profile);
  }

  Future<void> _startDm(Map<String, dynamic> profile) async {
    // Punto 11: si la persona cerró sus privados (y no soy su
    // favorito), se avisa aquí en vez de abrir un chat condenado.
    final allowed = await _svc.canDm(profile['uid'] as String);
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('chat.dmClosed'))),
        );
      }
      return;
    }
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
        // Si el eco en tiempo real llegó antes que la respuesta del
        // servidor, la fila real ya está en la lista: se quita el
        // temporal en vez de reemplazarlo (sin esto, el emisor veía
        // su propio mensaje duplicado, a veces sí y a veces no).
        final dup = _messages
            .indexWhere((m) => m['id'] == realId && !identical(m, temp));
        if (dup >= 0) {
          _messages.remove(temp);
        } else {
          final i = _messages.indexOf(temp);
          if (i >= 0) _messages[i] = {...inserted, 'is_whisper': true};
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.remove(temp));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$e'.contains('whispers_closed')
                ? t('chat.whisperClosed')
                : t('chat.whisperFailed', {'e': '$e'}))),
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
      if (_soundOn) playSound('send');
      final realId = inserted['id'];
      if (realId is int) _knownIds.add(realId);
      if (!mounted) return;
      setState(() {
        // Si el eco en tiempo real llegó antes que la respuesta del
        // servidor, la fila real ya está en la lista: se quita el
        // temporal en vez de reemplazarlo (sin esto, el emisor veía
        // su propio mensaje duplicado, a veces sí y a veces no).
        final dup = _messages
            .indexWhere((m) => m['id'] == realId && !identical(m, temp));
        if (dup >= 0) {
          _messages.remove(temp);
        } else {
          final i = _messages.indexOf(temp);
          if (i >= 0) _messages[i] = inserted;
        }
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

  // Ventana flotante de YouTube: el video no se despliega en
  // la conversación; flota sobre el chat (youtube_card.dart).
  String? _floatVideo;

  /// Mantener presionado un mensaje: traducirlo al idioma del
  /// perfil (o volver al original si ya estaba traducido).
  Future<void> _translateMenu(String key, String body) async {
    final has = _translations.containsKey(key);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: Text(t('chat.copy')),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title:
                  Text(has ? t('chat.showOriginal') : t('chat.translate')),
              onTap: () => Navigator.pop(context, 'go'),
            ),
          ],
        ),
      ),
    );
    if (action == 'copy') {
      // Punto 15: copiar el mensaje al portapapeles.
      await fservices.Clipboard.setData(
          fservices.ClipboardData(text: body));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('chat.copied'))),
        );
      }
      return;
    }
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
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text('${o['nickname'] ?? ''}')),
                    for (final icon in rankIcons(
                        profile: _profiles[o['uid'] as String?],
                        member: _membersInfo[o['uid'] as String?],
                        isRoomOwner:
                            widget.room['owner_uid'] == o['uid'])) ...[
                      const SizedBox(width: 4),
                      icon,
                    ],
                  ],
                ),
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
                        onMention: _mention,
                        memberInfo: _membersInfo[uid],
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
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: t('report.button'),
            onPressed: () => showReportSheet(
              context,
              roomId: widget.room['id'] as String,
              roomName: widget.room['name'] as String,
            ),
          ),
          if (_canModerate)
            IconButton(
              icon: const Icon(Icons.shield_outlined),
              tooltip: t('chat.modTooltip'),
              onPressed: _showModerationPanel,
            ),
          if (_canModerate)
            IconButton(
              icon: const Icon(Icons.dashboard_outlined),
              tooltip: t('dash.roomPanel'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoomDashboardPage(
                    roomId: widget.room['id'] as String,
                    roomName: widget.room['name'] as String,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: t('chat.occupantsTooltip'),
            onPressed: _showOccupants,
          ),
          ...?widget.extraActions,
        ],
      ),
      body: Stack(
        children: [
          Column(
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
                          if (m['kind'] == 'system') {
                            // Punto 12: avisos del sistema, solo si
                            // el usuario los tiene activados.
                            if (widget.myProfile['show_system_notices'] ==
                                false) {
                              return const SizedBox.shrink();
                            }
                            return _systemTile(m);
                          }
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
                                    onMention: _mention,
                                    memberInfo:
                                        _membersInfo[p['uid'] as String],
                                    canModerate: _canModerate,
                                    canManageRoles: _canManageRoles),
                            onLongPress: () => _translateMenu(
                                'm${m['id']}', m['body'] as String),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                text: TextSpan(
                                  style: DefaultTextStyle.of(context).style,
                                  children: [
                                    TextSpan(
                                      text: '$nick',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: nickColor(
                                            p?['nickname_color'] as String?),
                                      ),
                                    ),
                                    for (final icon in rankIcons(
                                        profile: p,
                                        member: sender == null
                                            ? null
                                            : _membersInfo[sender],
                                        isRoomOwner:
                                            widget.room['owner_uid'] ==
                                                sender,
                                        size: 13))
                                      WidgetSpan(
                                        alignment:
                                            PlaceholderAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                              left: 3),
                                          child: icon,
                                        ),
                                      ),
                                    const TextSpan(text: ': '),
                                    TextSpan(
                                      text: bodyWithoutYoutubeUrl(
                                          m['body'] as String),
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
                                  // Enlace de YouTube bajo el
                                  // mensaje, sin previsualización:
                                  // «YouTube - título», abre la
                                  // ventana flotante (2026-11-27).
                                  if (youtubeIdFromText(
                                          m['body'] as String) !=
                                      null)
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                          maxWidth: 340),
                                      child: YoutubeTitleLink(
                                          videoId: youtubeIdFromText(
                                              m['body'] as String)!,
                                          onPlay: (id) => setState(
                                              () => _floatVideo = id)),
                                    ),
                                ],
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
          if (_mentionHints.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final h in _mentionHints)
                    ActionChip(
                      avatar: const Icon(Icons.alternate_email, size: 14),
                      label: Text(h['nickname'] as String),
                      onPressed: () => _pickMentionHint(h),
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
                      focusNode: _inputFocus,
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
          if (_floatVideo != null)
            FloatingVideoPlayer(
              videoId: _floatVideo!,
              onClose: () => setState(() => _floatVideo = null),
            ),
        ],
      ),
    );
  }
}
