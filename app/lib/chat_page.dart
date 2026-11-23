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
    _blocked = await _svc.fetchBlockedUids();
    await _svc.joinRoom(_roomId);
    final rows = await _svc.fetchMessages(_roomId);
    final senderUids =
        rows.map((r) => r['sender_uid'] as String?).whereType<String>().toSet();
    final profiles = await _svc.profilesByUids(senderUids.toList());
    for (final p in profiles) {
      _profiles[p['uid'] as String] = p;
    }
    if (!mounted) return;
    setState(() {
      _messages.addAll(rows.where((r) => !_isBlocked(r)));
      _loading = false;
    });
    _jumpToBottom();

    _msgChannel = _svc.subscribeMessages(_roomId, (row) async {
      if (_isBlocked(row)) return;
      final sender = row['sender_uid'] as String?;
      if (sender != null && !_profiles.containsKey(sender)) {
        final p = await _svc.profileByUid(sender);
        if (p != null) _profiles[sender] = p;
      }
      if (!mounted) return;
      setState(() => _messages.add(row));
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
    setState(() => _sending = true);
    try {
      await _svc.sendMessage(
          roomId: _roomId, body: text, blockedUids: _blocked);
      _input.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar: $e')),
        );
      }
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
                          final nick = p?['nickname'] as String? ?? '···';
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
