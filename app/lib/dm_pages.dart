import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services.dart';
import 'strings.dart';
import 'user_sheet.dart';

String _when(String? iso) {
  if (iso == null) return '';
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final now = DateTime.now();
  final hhmm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return hhmm;
  }
  return '${t.day}/${t.month} $hhmm';
}

/// Pestaña «Privados»: mis conversaciones 1:1 (Etapa 2).
class ConversationsTab extends StatefulWidget {
  const ConversationsTab({super.key, required this.myProfile});
  final Map<String, dynamic> myProfile;

  @override
  State<ConversationsTab> createState() => _ConversationsTabState();
}

class _ConversationsTabState extends State<ConversationsTab> {
  final _svc = OnechatService();
  late Future<List<Map<String, dynamic>>> _convs = _svc.fetchConversations();

  void _reload() => setState(() => _convs = _svc.fetchConversations());

  Future<void> _open(Map<String, dynamic> c) async {
    final other = c['other'] as Map<String, dynamic>?;
    if (other == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DmChatPage(
          conversationId: c['id'] as String,
          other: other,
          myProfile: widget.myProfile,
        ),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _convs,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
              child:
                  Text(t('dm.errorLoading', {'e': '${snap.error}'})));
        }
        final convs = snap.data ?? [];
        if (convs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                t('dm.empty'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _convs;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: convs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = convs[i];
              final other = c['other'] as Map<String, dynamic>?;
              final last = c['last'] as Map<String, dynamic>?;
              final unread = c['unread'] as int? ?? 0;
              final nick = other?['nickname'] as String? ?? '···';
              final lastMine = last != null &&
                  last['sender_uid'] == widget.myProfile['uid'];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      nickColor(other?['nickname_color'] as String?),
                  child: Text(
                    nick.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(nick,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: nickColor(other?['nickname_color'] as String?),
                    )),
                subtitle: Text(
                  last == null
                      ? t('dm.created')
                      : '${lastMine ? t('dm.youPrefix') : ''}${last['body'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight:
                          unread > 0 ? FontWeight.bold : FontWeight.normal),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_when(last?['created_at'] as String? ??
                        c['created_at'] as String?),
                        style: const TextStyle(fontSize: 12)),
                    if (unread > 0) ...[
                      const SizedBox(height: 4),
                      Badge(label: Text('$unread')),
                    ],
                  ],
                ),
                onTap: () => _open(c),
              );
            },
          ),
        );
      },
    );
  }
}

/// Chat privado 1:1: historial + tiempo real + leídos (Etapa 2).
/// Solo los dos participantes pueden verlo (RLS).
class DmChatPage extends StatefulWidget {
  const DmChatPage({
    super.key,
    required this.conversationId,
    required this.other,
    required this.myProfile,
  });
  final String conversationId;
  final Map<String, dynamic> other;
  final Map<String, dynamic> myProfile;

  @override
  State<DmChatPage> createState() => _DmChatPageState();
}

class _DmChatPageState extends State<DmChatPage> {
  final _svc = OnechatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final Set<int> _knownIds = {};
  final Map<int, String> _translations = {};
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;

  String get _otherUid => widget.other['uid'] as String;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final rows = await _svc.fetchDirectMessages(widget.conversationId);
    await _svc.markConversationRead(widget.conversationId);
    if (!mounted) return;
    setState(() {
      for (final r in rows) {
        _messages.add(r);
        final id = r['id'];
        if (id is int) _knownIds.add(id);
      }
      _loading = false;
    });
    _jumpToBottom();
    _channel = _svc.subscribeDirectMessages(widget.conversationId, (row) {
      final id = row['id'];
      if (id is int && _knownIds.contains(id)) return;
      if (!mounted) return;
      setState(() {
        _messages.add(row);
        if (id is int) _knownIds.add(id);
      });
      _jumpToBottom();
      if (row['sender_uid'] != _svc.myUid) {
        _svc.markConversationRead(widget.conversationId);
      }
    });
  }

  /// Mantener presionado un mensaje privado: traducirlo al idioma
  /// del perfil (o volver al original). Igual que en las salas.
  Future<void> _translateMenu(int id, String body) async {
    final has = _translations.containsKey(id);
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
      setState(() => _translations.remove(id));
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
      setState(() => _translations[id] = translated);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('chat.translateFailed'))),
      );
    }
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
    final ch = _channel;
    if (ch != null) _svc.unsubscribe(ch);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    final temp = <String, dynamic>{
      'id': -DateTime.now().microsecondsSinceEpoch,
      'conversation_id': widget.conversationId,
      'sender_uid': _svc.myUid,
      'body': text,
      'kind': 'text',
    };
    setState(() {
      _messages.add(temp);
      _sending = true;
    });
    _jumpToBottom();
    try {
      final inserted = await _svc.sendDirectMessage(
        conversationId: widget.conversationId,
        otherUid: _otherUid,
        body: text,
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

  @override
  Widget build(BuildContext context) {
    final otherNick = widget.other['nickname'] as String;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(otherNick,
                style: TextStyle(
                    color:
                        nickColor(widget.other['nickname_color'] as String?))),
            Text(t('dm.privateChat'),
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                            t('dm.greeting', {'nick': otherNick})))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final isMe = m['sender_uid'] == _svc.myUid;
                          final nick = isMe
                              ? widget.myProfile['nickname'] as String
                              : otherNick;
                          final colorHex = isMe
                              ? widget.myProfile['nickname_color'] as String?
                              : widget.other['nickname_color'] as String?;
                          return GestureDetector(
                            onLongPress: () => _translateMenu(
                                m['id'] as int, m['body'] as String? ?? ''),
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
                                      color: nickColor(colorHex),
                                    ),
                                  ),
                                  TextSpan(text: m['body'] as String? ?? ''),
                                  if (isMe)
                                    TextSpan(
                                      text: t('chat.youSuffix'),
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey),
                                    ),
                                  if (_translations[m['id']] != null)
                                    TextSpan(
                                      text:
                                          '\n🌐 ${_translations[m['id']]}',
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
                      decoration: InputDecoration(
                        hintText: t('dm.hint'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
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
