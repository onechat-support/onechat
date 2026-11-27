import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart' as fservices;
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cine_catalog.dart';
import 'fx.dart';
import 'services.dart';
import 'strings.dart';
import 'theme.dart';
import 'user_sheet.dart';
import 'youtube_card.dart';

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
  State<ConversationsTab> createState() => ConversationsTabState();
}

class ConversationsTabState extends State<ConversationsTab> {
  final _svc = OnechatService();
  late Future<List<Map<String, dynamic>>> _convs = _svc.fetchConversations();
  RealtimeChannel? _inbox;

  @override
  void initState() {
    super.initState();
    // Si me escriben con la app abierta, la lista se refresca sola
    // (antes solo cargaba una vez y los privados nuevos no salían).
    _inbox = _svc.subscribeInbox((row) {
      if (row['sender_uid'] != _svc.myUid && mounted) _reload();
    });
  }

  @override
  void dispose() {
    final ch = _inbox;
    if (ch != null) _svc.unsubscribe(ch);
    super.dispose();
  }

  /// Recarga pedida desde fuera (al volver a la pestaña).
  void reload() => _reload();

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
                      : last['kind'] == 'nudge'
                          ? t('dm.nudgePreview')
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

class _DmChatPageState extends State<DmChatPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _svc = OnechatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  final Set<int> _knownIds = {};
  final Map<int, String> _translations = {};
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;

  // Gato 1 vs 1 dentro del privado
  Map<String, dynamic>? _game;
  Map<String, int>? _vsRecord;
  RealtimeChannel? _gameChannel;
  bool _gameBusy = false;
  final Set<String> _dismissedGames = {};

  // Ventana flotante de YouTube en el privado (como en salas).
  String? _floatVideo;

  // Zumbido estilo MSN (v1.27): sacudida de la ventana, sonido
  // y vibración al recibirlo; espera de 20 s entre envíos.
  late final AnimationController _shakeCtrl;
  bool _nudgeCooling = false;

  // Cine juntos Premium (punto 17, migración v1.24)
  Map<String, dynamic>? _cine;
  RealtimeChannel? _cineChannel;
  RealtimeChannel? _cineConvChannel;
  bool _cineBusy = false;
  Timer? _cineTicker;
  // El video parte solo y EN SILENCIO al aceptarse (los
  // navegadores no dejan que arranque con sonido sin un toque
  // en ESE teléfono); el chip «Activar sonido» lo desmutea y
  // re-sincroniza. _cinePrimedFor: sesión ya llevada a la
  // posición compartida tras cargar el reproductor.
  bool _cineSoundOn = false;
  String? _cinePrimedFor;

  String get _otherUid => widget.other['uid'] as String;

  // Lote C: teclado (punto 5) y sonidos (punto 16), como en salas.
  double _lastInset = 0;
  bool get _soundOn => widget.myProfile['sound_enabled'] != false;

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final inset = view.viewInsets.bottom / view.devicePixelRatio;
    final opened = inset > _lastInset + 80;
    _lastInset = inset;
    if (opened) {
      Future.delayed(const Duration(milliseconds: 280), _jumpToBottom);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    setWakelock(true);
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _init();
  }

  bool get _vibrateOn => widget.myProfile['vibrate_enabled'] != false;

  /// Sacude la ventana del privado, como el zumbido de MSN.
  void _shake() {
    if (_shakeCtrl.isAnimating) return;
    _shakeCtrl.forward(from: 0);
  }

  Future<void> _sendNudge() async {
    if (_nudgeCooling) return;
    // Si el otro desactivó los zumbidos, ni lo intentamos.
    if (!await _svc.canNudge(_otherUid)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t('chat.nudgesClosed',
              {'nick': widget.other['nickname'] as String}))));
      return;
    }
    setState(() => _nudgeCooling = true);
    _shake();
    if (_soundOn) playSound('nudge');
    if (_vibrateOn) buzz();
    try {
      await _svc.sendNudge(
          conversationId: widget.conversationId, otherUid: _otherUid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'.contains('nudges_closed')
                ? t('chat.nudgesClosed',
                    {'nick': widget.other['nickname'] as String})
                : '$e'.contains('dm_closed')
                    ? t('chat.dmClosed')
                    : t('chat.sendFailed', {'e': '$e'}))));
      }
    }
    await Future.delayed(const Duration(seconds: 20));
    if (mounted) setState(() => _nudgeCooling = false);
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
    _loadGame();
    _loadCine();
    // La invitación de cine aparece en vivo aunque ya estés
    // dentro del privado (no genera ningún mensaje).
    _cineConvChannel =
        _svc.subscribeConversationCine(widget.conversationId, () {
      if (mounted) _loadCine();
    });
    _channel = _svc.subscribeDirectMessages(widget.conversationId, (row) {
      _loadGame();
      _loadCine();
      final id = row['id'];
      if (id is int && _knownIds.contains(id)) return;
      if (!mounted) return;
      setState(() {
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
      if (row['sender_uid'] != _svc.myUid) {
        if (row['kind'] == 'nudge') {
          // Zumbido entrante: sacudida + sonido + vibración,
          // respetando los interruptores del perfil.
          _shake();
          if (_soundOn) playSound('nudge');
          if (_vibrateOn) buzz();
        } else if (_soundOn) {
          playSound('receive');
        }
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
    WidgetsBinding.instance.removeObserver(this);
    setWakelock(false);
    _cineTicker?.cancel();
    final cc = _cineChannel;
    if (cc != null) _svc.unsubscribe(cc);
    final cvc = _cineConvChannel;
    if (cvc != null) _svc.unsubscribe(cvc);
    final ch = _channel;
    if (ch != null) _svc.unsubscribe(ch);
    final gch = _gameChannel;
    if (gch != null) _svc.unsubscribe(gch);
    _input.dispose();
    _scroll.dispose();
    _shakeCtrl.dispose();
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
        SnackBar(
            content: Text('$e'.contains('dm_closed')
                ? t('chat.dmClosed')
                : t('chat.sendFailed', {'e': '$e'}))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _loadGame() async {
    _loadVsRecord();
    final g = await _svc.fetchPairGame(_otherUid);
    if (!mounted) return;
    if (g == null || g['status'] == 'declined' ||
        _dismissedGames.contains(g['id'])) {
      if (_game != null) setState(() => _game = null);
      return;
    }
    setState(() => _game = g);
    _subscribeGame(g['id'] as String);
  }

  void _subscribeGame(String gameId) {
    if (_gameChannel != null) return;
    _gameChannel = _svc.subscribeGame(gameId, (row) {
      if (!mounted) return;
      final justFinished =
          row['status'] == 'finished' && _game?['status'] != 'finished';
      setState(() => _game = {...?_game, ...row});
      if (justFinished) _loadVsRecord();
    });
  }

  /// Récord vs contra esta persona (v1.26): se carga al abrir el
  /// privado y cada vez que termina una partida.
  Future<void> _loadVsRecord() async {
    final r = await _svc.gameRecordVs(_otherUid);
    if (mounted) setState(() => _vsRecord = r);
  }

  Widget _vsLine() {
    final r = _vsRecord;
    if (r == null) return const SizedBox.shrink();
    final total = r['wins']! + r['losses']! + r['draws']!;
    if (total == 0) return const SizedBox.shrink();
    return Text(
      t('game.vsScore', {
        'nick': widget.other['nickname'] as String,
        'w': '${r['wins']}',
        'l': '${r['losses']}',
        'd': r['draws'].toString(),
      }),
      style: TextStyle(
          fontSize: 12.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }

  Future<void> _refreshGame() async {
    final id = _game?['id'] as String?;
    if (id == null) return;
    final g = await _svc.fetchGameById(id);
    if (!mounted || g == null) return;
    if (g['status'] == 'declined') {
      setState(() => _game = null);
    } else {
      setState(() => _game = g);
    }
  }

  Future<void> _invite() async {
    setState(() => _gameBusy = true);
    try {
      final id = await _svc.inviteGame(_otherUid);
      if (id != null) {
        final g = await _svc.fetchGameById(id);
        if (mounted && g != null) {
          setState(() => _game = g);
          _subscribeGame(id);
        }
      }
    } finally {
      if (mounted) setState(() => _gameBusy = false);
    }
  }

  Future<void> _respond(bool accept) async {
    final id = _game?['id'] as String?;
    if (id == null) return;
    setState(() => _gameBusy = true);
    try {
      await _svc.respondGame(id, accept);
      await _refreshGame();
    } finally {
      if (mounted) setState(() => _gameBusy = false);
    }
  }

  Future<void> _move(int cell) async {
    final g = _game;
    if (g == null || _gameBusy) return;
    if (g['turn_uid'] != _svc.myUid) return;
    setState(() => _gameBusy = true);
    try {
      final r = await _svc.moveGame(g['id'] as String, cell);
      if (r != null) await _refreshGame();
    } finally {
      if (mounted) setState(() => _gameBusy = false);
    }
  }

  Future<void> _resign() async {
    final id = _game?['id'] as String?;
    if (id == null) return;
    await _svc.resignGame(id);
    await _refreshGame();
  }

  // ---------- Cine juntos Premium (punto 17) ----------

  /// Posición actual del video según el estado compartido:
  /// la posición guardada más lo transcurrido si está sonando.
  double _cinePosition() {
    final c = _cine;
    if (c == null) return 0;
    final base = (c['position_sec'] as num?)?.toDouble() ?? 0;
    if (c['play_state'] != 'playing') return base;
    final upd = DateTime.tryParse(c['updated_at'] as String? ?? '');
    if (upd == null) return base;
    final elapsed =
        DateTime.now().toUtc().difference(upd).inMilliseconds / 1000.0;
    return base + (elapsed > 0 ? elapsed : 0);
  }

  String _cineClock() {
    final s = _cinePosition().floor();
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _setCine(Map<String, dynamic>? session) {
    _cineTicker?.cancel();
    _cineTicker = null;
    if (session == null || session['id'] != _cine?['id']) {
      _cineSoundOn = false;
    }
    setState(() => _cine = session);
    if (session != null &&
        session['status'] == 'active' &&
        _cinePrimedFor != session['id']) {
      // Recién activada (o recién abierta a media sesión): el
      // reproductor parte solo desde 0; hay que llevarlo a la
      // posición compartida en cuanto carga.
      _cinePrimedFor = session['id'] as String;
      final id = _cinePrimedFor!;
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted || _cine?['id'] != id) return;
        cineCommand(id, 'seekTo', _cinePosition());
        cineCommand(id,
            _cine?['play_state'] == 'playing' ? 'playVideo' : 'pauseVideo');
      });
    }
    if (session != null && session['status'] == 'active') {
      // Toques sobre el video: el primero activa el sonido; los
      // siguientes pausan/reanudan para ambos.
      final sid = session['id'] as String;
      setCineTapHandler(sid, () {
        if (!mounted || _cine?['id'] != sid) return;
        if (!_cineSoundOn) {
          _enableCineSound(sid);
        } else if (!_cineBusy) {
          _cineTogglePlay();
        }
      });
      // Reloj de la posición mientras suena (solo redibuja).
      _cineTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _cine?['play_state'] == 'playing') {
          setState(() {});
        }
      });
    }
  }

  Future<void> _loadCine() async {
    final s = await _svc.fetchConversationCine(widget.conversationId);
    if (!mounted) return;
    if (s == null) {
      if (_cine != null) _setCine(null);
      return;
    }
    _setCine(s);
    _subscribeCine(s['id'] as String);
  }

  void _subscribeCine(String sessionId) {
    if (_cineChannel != null) return;
    _cineChannel = _svc.subscribeCine(sessionId, (row) {
      if (!mounted) return;
      final status = row['status'] as String?;
      if (status == 'ended' || status == 'declined') {
        final ch = _cineChannel;
        _cineChannel = null;
        if (ch != null) _svc.unsubscribe(ch);
        _setCine(null);
        return;
      }
      final wasActive = _cine?['status'] == 'active';
      _setCine({...?_cine, ...row});
      // Si el cambio lo hizo la otra persona, mi reproductor
      // obedece: salta a la posición compartida y suena o pausa.
      if (row['updated_by'] != _svc.myUid &&
          (status == 'active' || wasActive)) {
        final target = _cinePosition();
        cineCommand(sessionId, 'seekTo', target);
        cineCommand(sessionId,
            row['play_state'] == 'playing' ? 'playVideo' : 'pauseVideo');
      }
    });
  }

  Future<void> _inviteCine() async {
    final me = widget.myProfile;
    final canHost = me['is_premium'] == true ||
        me['global_role'] == 'owner' ||
        me['global_role'] == 'staff';
    if (!canHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('cine.premiumOnly'))),
      );
      return;
    }
    final ctrl = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('cine.inviteTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, 'CATALOG'),
              icon: const Icon(Icons.movie_outlined, size: 19),
              label: Text(t('cine.catalog')),
            ),
            const SizedBox(height: 14),
            Text(t('cine.orLink'),
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(hintText: t('cine.linkHint')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('cine.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'SEND'),
            child: Text(t('cine.sendInvite')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'CATALOG') {
      final picked = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const CineCatalogPage()),
      );
      if (picked != null && mounted) {
        await _inviteCineWithId(picked);
      }
      return;
    }
    if (action != 'SEND') return;
    final videoId = youtubeIdFromText(ctrl.text.trim());
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('cine.invalidLink'))),
      );
      return;
    }
    await _inviteCineWithId(videoId);
  }

  Future<void> _inviteCineWithId(String videoId) async {
    setState(() => _cineBusy = true);
    try {
      final id =
          await _svc.inviteCine(widget.conversationId, _otherUid, videoId);
      if (!mounted) return;
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('cine.inviteFailed'))),
        );
        return;
      }
      final s = await _svc.fetchCineById(id);
      if (mounted && s != null) {
        _setCine(s);
        _subscribeCine(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('cine.inviteSent'))),
        );
      }
    } finally {
      if (mounted) setState(() => _cineBusy = false);
    }
  }

  Future<void> _respondCine(bool accept) async {
    final id = _cine?['id'] as String?;
    if (id == null) return;
    setState(() => _cineBusy = true);
    try {
      await _svc.respondCine(id, accept);
      var s = await _svc.fetchCineById(id);
      if (!mounted) return;
      if (s != null && accept && s['status'] == 'active') {
        // Al aceptar, el video ARRANCA SOLO en los dos teléfonos
        // (en silencio; el sonido se activa con un toque): el
        // estado compartido parte en «playing» desde 0.
        await _svc.controlCine(id, 'playing', 0);
        s = await _svc.fetchCineById(id);
        if (!mounted) return;
      }
      if (s == null ||
          s['status'] == 'declined' ||
          s['status'] == 'ended') {
        _setCine(null);
      } else {
        _setCine(s);
      }
    } finally {
      if (mounted) setState(() => _cineBusy = false);
    }
  }

  /// Chip «Activar sonido»: desmutea (gesto del usuario en su
  /// propio teléfono, lo que el navegador exige) y re-sincroniza
  /// al segundo compartido.
  void _enableCineSound(String id) {
    cineCommand(id, 'unMute');
    cineCommand(id, 'seekTo', _cinePosition());
    if (_cine?['play_state'] == 'playing') {
      cineCommand(id, 'playVideo');
    }
    setState(() => _cineSoundOn = true);
  }

  Future<void> _endCine() async {
    final id = _cine?['id'] as String?;
    if (id == null) return;
    await _svc.endCine(id);
    if (mounted) _setCine(null);
  }

  Future<void> _cineTogglePlay() async {
    final c = _cine;
    if (c == null || _cineBusy) return;
    final id = c['id'] as String;
    final playing = c['play_state'] == 'playing';
    final pos = _cinePosition();
    // Mi reproductor responde al instante; el estado compartido
    // lleva el cambio al otro lado.
    if (playing) {
      cineCommand(id, 'pauseVideo');
    } else {
      cineCommand(id, 'seekTo', pos);
      cineCommand(id, 'playVideo');
    }
    setState(() => _cineBusy = true);
    try {
      await _svc.controlCine(id, playing ? 'paused' : 'playing', pos);
    } finally {
      if (mounted) setState(() => _cineBusy = false);
    }
  }

  Future<void> _cineSeek(double delta) async {
    final c = _cine;
    if (c == null || _cineBusy) return;
    final id = c['id'] as String;
    var pos = _cinePosition() + delta;
    if (pos < 0) pos = 0;
    cineCommand(id, 'seekTo', pos);
    setState(() => _cineBusy = true);
    try {
      await _svc.controlCine(
          id, c['play_state'] as String? ?? 'paused', pos);
    } finally {
      if (mounted) setState(() => _cineBusy = false);
    }
  }

  Widget _cineArea() {
    final otherNick = widget.other['nickname'] as String;
    final c = _cine;
    if (c == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _cineBusy ? null : _inviteCine,
            icon: const Icon(Icons.movie_outlined, size: 18),
            label: Text(t('cine.button')),
          ),
        ),
      );
    }
    final me = _svc.myUid;
    final iAmHost = c['host_uid'] == me;
    final status = c['status'] as String;
    final videoId = c['video_id'] as String;
    if (status == 'invited') {
      final header = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(height: 90),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            iAmHost
                ? t('cine.waiting', {'nick': otherNick})
                : t('cine.invitedBy', {'nick': otherNick}),
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      );
      final actions = iAmHost
          ? [
              _gameButton(
                  t('cine.cancel'), _cineBusy ? null : () => _respondCine(false)),
            ]
          : [
              _gameButton(
                  t('cine.accept'), _cineBusy ? null : () => _respondCine(true),
                  primary: true),
              const SizedBox(width: 8),
              _gameButton(t('cine.decline'),
                  _cineBusy ? null : () => _respondCine(false)),
            ];
      return _gameCard(header, actions, null);
    }
    // Activa: reproductor + controles compartidos.
    final playing = c['play_state'] == 'playing';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.movie, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t('cine.watchingWith', {'nick': otherNick}),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: _endCine,
                child: Text(t('cine.end')),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                cinePlayer(c['id'] as String, videoId),
                // Capa web real sobre el iframe: recibe TODOS los
                // toques (los widgets del lienzo no los reciben
                // sobre un iframe). Así ni el botón rojo ni el
                // botón «Ver en YouTube» se pueden apretar: el
                // primer toque activa el sonido y los demás
                // pausan/reanudan para ambos.
                Positioned.fill(
                  child: cineTapOverlay(c['id'] as String),
                ),
                if (!_cineSoundOn)
                  // El botón de sonido, en el CENTRO del
                  // reproductor, donde iría el botón rojo de
                  // YouTube (es solo visual: el toque lo recibe
                  // la capa completa).
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.volume_up,
                                  size: 22, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(t('cine.enableSound'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _cineBusy ? null : () => _cineSeek(-10),
                icon: const Icon(Icons.replay_10),
              ),
              IconButton.filled(
                onPressed: _cineBusy ? null : _cineTogglePlay,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                onPressed: _cineBusy ? null : () => _cineSeek(10),
                icon: const Icon(Icons.forward_10),
              ),
              const SizedBox(width: 8),
              Text(_cineClock()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _gameArea() {
    final g = _game;
    final otherNick = widget.other['nickname'] as String;
    if (g == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _gameBusy ? null : _invite,
                icon: const Icon(Icons.grid_3x3, size: 18),
                label: Text(t('game.play')),
              ),
            ),
            if (_vsRecord != null) ...[
              const SizedBox(height: 4),
              _vsLine(),
            ],
          ],
        ),
      );
    }
    final me = _svc.myUid;
    final iAmA = g['player_a'] == me;
    final myMark = iAmA ? 'X' : 'O';
    final status = g['status'] as String;
    final board = (g['state']?['board'] as List?) ?? const [];
    Widget header;
    List<Widget> actions = [];
    if (status == 'invited') {
      if (iAmA) {
        header = Text(t('game.waiting'));
        actions = [
          _gameButton(
              t('game.cancel'), _gameBusy ? null : () => _respond(false)),
        ];
      } else {
        header = Text(t('game.invitedYou', {'nick': otherNick}),
            style: const TextStyle(fontWeight: FontWeight.bold));
        actions = [
          _gameButton(
              t('game.accept'), _gameBusy ? null : () => _respond(true),
              primary: true),
          const SizedBox(width: 8),
          _gameButton(
              t('game.decline'), _gameBusy ? null : () => _respond(false)),
        ];
      }
      return _gameCard(header, actions, null);
    }
    if (status == 'active') {
      final myTurn = g['turn_uid'] == me;
      header = Text(
        myTurn
            ? '${t('game.yourTurn')} · ${t('game.youAre', {'mark': myMark})}'
            : t('game.theirTurn', {'nick': otherNick}),
        style: const TextStyle(fontWeight: FontWeight.bold),
      );
      actions = [
        _gameButton(t('game.resign'), _gameBusy ? null : _resign),
      ];
      return _gameCard(header, actions, board);
    }
    // finished
    final winner = g['winner_uid'] as String?;
    final result = winner == null
        ? t('game.draw')
        : winner == me
            ? t('game.youWon')
            : t('game.theyWon', {'nick': otherNick});
    header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(result,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: OneChatColors.primary)),
        if (_vsRecord != null) ...[
          const SizedBox(height: 3),
          _vsLine(),
        ],
      ],
    );
    actions = [
      _gameButton(t('game.rematch'), _gameBusy ? null : _invite,
          primary: true),
      const SizedBox(width: 8),
      _gameButton(t('game.close'), () => setState(() {
        _dismissedGames.add(g['id'] as String);
        _game = null;
      })),
    ];
    return _gameCard(header, actions, board);
  }

  Widget _gameButton(String label, VoidCallback? onTap,
      {bool primary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: primary ? OneChatColors.primary : Colors.transparent,
          border: Border.all(color: OneChatColors.primary),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primary ? Colors.white : OneChatColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _gameCard(Widget header, List<Widget> actions, List? board) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          if (board != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 168,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 9,
                itemBuilder: (context, i) {
                  final v = i < board.length ? board[i] : null;
                  final g = _game!;
                  final canTap = v == null &&
                      g['status'] == 'active' &&
                      g['turn_uid'] == _svc.myUid &&
                      !_gameBusy;
                  return InkWell(
                    onTap: canTap ? () => _move(i) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        v?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: v == 'X'
                              ? OneChatColors.primary
                              : OneChatColors.secondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: actions,
          ),
        ],
      ),
    );
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
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _shakeCtrl,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                  _shakeCtrl.isAnimating
                      ? math.sin(_shakeCtrl.value * math.pi * 7) *
                          9 *
                          (1 - _shakeCtrl.value)
                      : 0.0,
                  0),
              child: child,
            ),
            child: Column(
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
                          if (m['kind'] == 'nudge') {
                            final mineN = m['sender_uid'] == _svc.myUid;
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    mineN
                                        ? t('dm.nudgeSent',
                                            {'nick': otherNick})
                                        : t('dm.nudgeReceived',
                                            {'nick': otherNick}),
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant),
                                  ),
                                ),
                              ),
                            );
                          }
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
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
                                  TextSpan(
                                      text: bodyWithoutYoutubeUrl(
                                          m['body'] as String? ?? '')),
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
                                if (youtubeIdFromText(
                                        m['body'] as String? ?? '') !=
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
          _gameArea(),
          _cineArea(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _nudgeCooling ? null : _sendNudge,
                    icon: const Icon(Icons.vibration),
                    tooltip: t('dm.nudge'),
                  ),
                  const SizedBox(width: 2),
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
