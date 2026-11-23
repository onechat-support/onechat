import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services.dart';
import 'theme.dart';
import 'user_sheet.dart';

/// Sala de chat (MVP): historial + tiempo real + presencia básica.
/// Los mensajes de usuarios bloqueados no se muestran.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.room, required this.myProfile});
  final Map<String, dynamic> room;
  final Map<String, dynamic> myProfile;

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
  Set<String> _blocked = {};
  List<Map<String, dynamic>> _occupants = [];
  RealtimeChannel? _msgChannel;
  RealtimeChannel? _presenceChannel;
  bool _loading = true;
  bool _sending = false;

  String get _roomId => widget.room['id'] as String;

  @override
  void initState() {
    super.initState();
    _profiles[widget.myProfile['uid'] as String] = widget.myProfile;
    _init();
  }

  Future<void> _init() async {
    // En paralelo: bloqueos e historial (con perfiles incluidos) en un
    // solo viaje cada uno; la unión a la sala no espera a nadie.
    _svc.joinRoom(_roomId);
    final results = await Future.wait([
      _svc.fetchBlockedUids(),
      _svc.fetchMessagesWithProfiles(_roomId),
    ]);
    _blocked = results[0] as Set<String>;
    final (rows, profiles) =
        results[1] as (List<Map<String, dynamic>>, Map<String, Map<String, dynamic>>);
    _profiles.addAll(profiles);
    if (!mounted) return;
    setState(() {
      for (final r in rows.where((r) => !_isBlocked(r))) {
        _messages.add(r);
        final id = r['id'];
        if (id is int) _knownIds.add(id);
      }
      _loading = false;
    });
    _jumpToBottom();

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
    if (a != null) _svc.unsubscribe(a);
    if (b != null) _svc.unsubscribe(b);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
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
        SnackBar(content: Text('No se pudo enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
            Text('En la sala (${_occupants.length})',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_occupants.isEmpty)
              const Text('Solo estás tú por ahora.'),
            for (final o in _occupants)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle,
                    size: 10, color: OneChatColors.primary),
                title: Text('${o['nickname'] ?? ''}'),
                onTap: () async {
                  Navigator.pop(context);
                  final uid = o['uid'] as String?;
                  if (uid == null) return;
                  final p = _profiles[uid] ?? await _svc.profileByUid(uid);
                  if (p != null && mounted) {
                    showUserSheet(context, profile: p, roomId: _roomId);
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room['name'] as String),
            Text(
              _occupants.isEmpty
                  ? 'Sala pública'
                  : '${_occupants.length} en línea',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Quién está en la sala',
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
                    ? const Center(
                        child: Text('Sé la primera persona en saludar.'))
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
                          final mentionsMe = (m['mentions'] as List?)
                                  ?.contains(_svc.myUid) ==
                              true;
                          return InkWell(
                            onTap: p == null
                                ? null
                                : () => showUserSheet(context,
                                    profile: p, roomId: _roomId),
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
                                      const TextSpan(
                                        text: '  (tú)',
                                        style: TextStyle(
                                            fontSize: 11,
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje… (@nickname menciona)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Enviar',
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
