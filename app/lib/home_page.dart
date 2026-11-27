import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_page.dart';
import 'config.dart';
import 'dm_pages.dart';
import 'main.dart';
import 'report_pages.dart';
import 'revoked_page.dart';
import 'rooms_host.dart';
import 'services.dart';
import 'strings.dart';
import 'theme.dart';
import 'user_sheet.dart';
import 'web_links.dart';

/// Código ISO del país de la conexión → nombre del país tal
/// como está en rooms.country. España y el resto de Europa sin
/// sala propia caen en la sala Europa.
const _isoToRoomCountry = {
  'CL': 'Chile',
  'MX': 'México',
  'AR': 'Argentina',
  'CO': 'Colombia',
  'PE': 'Perú',
  'VE': 'Venezuela',
  'EC': 'Ecuador',
  'BO': 'Bolivia',
  'PY': 'Paraguay',
  'UY': 'Uruguay',
  'BR': 'Brasil',
  'CU': 'Cuba',
  'DO': 'República Dominicana',
  'PR': 'Puerto Rico',
  'GT': 'Guatemala',
  'HN': 'Honduras',
  'SV': 'El Salvador',
  'NI': 'Nicaragua',
  'CR': 'Costa Rica',
  'PA': 'Panamá',
  'US': 'Estados Unidos',
  'CA': 'Canadá',
};

const _europeCodes = {
  'ES', 'PT', 'FR', 'IT', 'DE', 'GB', 'IE', 'NL', 'BE', 'CH',
  'AT', 'SE', 'NO', 'DK', 'FI', 'PL', 'CZ', 'SK', 'HU', 'RO',
  'BG', 'GR', 'HR', 'RS', 'BA', 'SI', 'EE', 'LV', 'LT', 'UA',
  'RU', 'BY', 'MD', 'AL', 'MK', 'ME', 'IS', 'LU', 'MT', 'CY',
};

String? roomCountryForIso(String code) =>
    _isoToRoomCountry[code] ??
    (_europeCodes.contains(code) ? 'Europa' : null);

/// Pantalla principal del MVP: pestañas Salas · Status · Perfil.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.profile});
  final Map<String, dynamic> profile;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  int _unread = 0;
  int _dmUnread = 0;
  late Map<String, dynamic> _profile = widget.profile;
  final _svc = OnechatService();

  // La Sala General es la puerta de entrada: primera pestaña y
  // chat abierto al entrar. Su fila se busca por slug al iniciar.
  Map<String, dynamic>? _generalRoom;
  Map<String, dynamic>? _ayudaRoom;

  bool get _isStaff =>
      _profile['global_role'] == 'staff' ||
      _profile['global_role'] == 'owner';
  bool _generalFailed = false;
  // Pestañas de salas: anfitrión de las salas abiertas y país
  // de la conexión (para abrir la sala del país junto a
  // General, pedido de Mario 2026-11-26).
  final _roomsHostKey = GlobalKey<RoomsHostState>();
  List<Map<String, dynamic>> _allRooms = [];
  String? _visitCountry;
  final _statusKey = GlobalKey<_StatusTabState>();
  final _convsKey = GlobalKey<ConversationsTabState>();
  RealtimeChannel? _notifChannel;
  RealtimeChannel? _inboxChannel;

  @override
  void initState() {
    super.initState();
    applyProfileTheme(widget.profile);
    applyProfileLanguage(widget.profile);
    _svc.touchLastSeen();
    // Puerta también aquí: quien entra desde la bienvenida
    // no pasa por SessionGate en esta misma carga. Registra
    // la conexión (IP + dispositivo) y, si hay Destierro,
    // lo manda a la pantalla de acceso revocado.
    _svc.entryCheck().then((v) {
      if (!mounted) return;
      // País de la conexión (lo resuelve el servidor desde la
      // IP): con él se abre la sala del país junto a General.
      final c = v['country'] as String?;
      if (c != null && c.isNotEmpty) {
        _visitCountry = c;
        _maybeAutoOpenCountry();
      }
      if (v['banned'] != true) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => RevokedPage(verdict: v)),
        (_) => false,
      );
    });
    _refreshUnread();
    _loadGeneral();
    // Si tengo poder y aún no acepté el código de conducta, se me
    // presenta una vez por sesión (v1.17).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowConduct(context);
    });
    // Avisos en vivo: si me escriben o me llega una notificación
    // estando en cualquier pestaña, los contadores se actualizan
    // solos (antes solo cambiaban al entrar a Privados o Status).
    _notifChannel = _svc.subscribeNotifications((_) {
      if (!mounted) return;
      _refreshUnread();
      if (_tab == 3) _statusKey.currentState?.reload();
    });
    _inboxChannel = _svc.subscribeInbox((row) {
      if (!mounted || row['sender_uid'] == _svc.myUid) return;
      _refreshUnread();
    });
  }

  @override
  void dispose() {
    final n = _notifChannel;
    if (n != null) _svc.unsubscribe(n);
    final i = _inboxChannel;
    if (i != null) _svc.unsubscribe(i);
    super.dispose();
  }

  Future<void> _loadGeneral() async {
    try {
      final rooms = await _svc.fetchRooms();
      final general = rooms.where((r) => r['slug'] == 'general').firstOrNull;
      final ayuda = rooms.where((r) => r['slug'] == 'ayuda').firstOrNull;
      if (!mounted) return;
      setState(() {
        _generalRoom = general;
        _ayudaRoom = ayuda;
        _generalFailed = general == null;
        _allRooms = rooms;
      });
      _maybeAutoOpenCountry();
    } catch (_) {
      if (mounted) setState(() => _generalFailed = true);
    }
  }

  /// Si ya se conoce el país de la conexión y las salas están
  /// cargadas, abre la sala del país junto a General (sin
  /// cambiar de pestaña: se entra conversando en General).
  void _maybeAutoOpenCountry() {
    final code = _visitCountry;
    if (code == null || _allRooms.isEmpty) return;
    final name = roomCountryForIso(code);
    if (name == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _roomsHostKey.currentState?.autoOpenCountry(_allRooms, name);
    });
  }

  /// Abre una sala desde la lista de Salas: pasa a ser una
  /// pestaña junto a General y se salta a ella.
  void _openRoomFromList(Map<String, dynamic> room) {
    final host = _roomsHostKey.currentState;
    if (host == null) return;
    if (!host.openRoom(room)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('rooms.maxOpen'))),
      );
      return;
    }
    setState(() => _tab = 0);
  }

  Widget _generalTab() {
    final room = _generalRoom;
    if (room == null) {
      return Center(
        child: _generalFailed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t('general.loadFailed')),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() => _tab = 1),
                    child: Text(t('general.goToRooms')),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      );
    }
    return RoomsHost(
      key: _roomsHostKey,
      generalRoom: room,
      myProfile: _profile,
      onGoToRooms: () => setState(() => _tab = 1),
      generalExtraActions: (_isStaff && _ayudaRoom != null)
          ? [_StaffHelpButton(room: _ayudaRoom!, myProfile: _profile)]
          : null,
    );
  }

  Future<void> _refreshUnread() async {
    final results = await Future.wait([
      _svc.unreadCount(),
      _svc.dmUnreadCount(),
    ]);
    if (!mounted) return;
    setState(() {
      _unread = results[0];
      _dmUnread = results[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _generalTab(),
      _RoomsTab(myProfile: _profile, onOpenRoom: _openRoomFromList),
      ConversationsTab(key: _convsKey, myProfile: _profile),
      _StatusTab(
        key: _statusKey,
        myProfile: _profile,
        onSeen: () {
          if (_unread != 0) setState(() => _unread = 0);
        },
      ),
      _ProfileTab(
        profile: _profile,
        onProfileChanged: (p) {
          setState(() => _profile = p);
          applyProfileTheme(p);
          applyProfileLanguage(p);
        },
      ),
    ];
    return Scaffold(
      // En la pestaña General manda la barra propia de la sala
      // (nombre, en línea, moderación); en las demás, la de ONEchat.
      appBar: _tab == 0
          ? null
          : AppBar(
              // La marca en la barra: solo las letras del logo
              // (Mario, 2026-11-25); a 32 px la píldora no se
              // leería, la versión completa vive en la bienvenida.
              title: ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.asset(
                  'assets/logo_letras.png',
                  height: 32,
                  fit: BoxFit.fitHeight,
                  semanticLabel: 'ONEchat',
                ),
              ),
              actions: [
                if (_isStaff && _ayudaRoom != null)
                  _StaffHelpButton(
                      room: _ayudaRoom!, myProfile: _profile),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Center(
                    child: Text(
                      _profile['nickname'] as String,
                      style: TextStyle(
                          color:
                              nickColor(_profile['nickname_color'] as String?),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          _refreshUnread();
          if (i == 2) _convsKey.currentState?.reload();
          if (i == 3) _statusKey.currentState?.reload();
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.forum_outlined),
              selectedIcon: const Icon(Icons.forum),
              label: t('tabs.general')),
          NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore),
              label: t('tabs.rooms')),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _dmUnread > 0,
              label: Text('$_dmUnread'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: t('tabs.private'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: t('tabs.status'),
          ),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: t('tabs.profile')),
        ],
      ),
    );
  }
}

class _RoomsTab extends StatefulWidget {
  const _RoomsTab({required this.myProfile, required this.onOpenRoom});
  final Map<String, dynamic> myProfile;
  final void Function(Map<String, dynamic> room) onOpenRoom;

  @override
  State<_RoomsTab> createState() => _RoomsTabState();
}

class _RoomsTabState extends State<_RoomsTab> {
  final _svc = OnechatService();
  late Future<List<Map<String, dynamic>>> _rooms = _svc.fetchRooms();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _rooms,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
              child: Text(t('rooms.error', {'error': '${snap.error}'})));
        }
        final rooms = snap.data ?? [];
        // Lista plana con encabezados de sección: Plataforma,
        // Latino, Norteamérica, Europa, Temáticos.
        final headers = {
          'plataforma': t('rooms.platform'),
          'latino': t('rooms.latino'),
          'norteamerica': t('rooms.northAmerica'),
          'europa': t('rooms.europe'),
          'tematicos': t('rooms.thematic'),
        };
        final items = <Object>[];
        for (final c in headers.keys) {
          final group = rooms.where((r) => r['category'] == c).toList();
          if (group.isEmpty) continue;
          items.add(headers[c]!);
          items.addAll(group);
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _rooms = _svc.fetchRooms());
            await _rooms;
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final it = items[i];
              if (it is String) {
                return Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: 2),
                  child: Text(it,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: OneChatColors.primary)),
                );
              }
              final r = it as Map<String, dynamic>;
              final isPlatform = r['category'] == 'plataforma';
              final isRegional = r['kind'] == 'regional';
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: OneChatColors.primary,
                    child: Icon(
                        isPlatform
                            ? Icons.support_agent
                            : isRegional
                                ? Icons.public
                                : Icons.tag,
                        color: Colors.black),
                  ),
                  title: Text(r['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isPlatform
                      ? t('rooms.staffAttended')
                      : isRegional
                          ? t('rooms.regional')
                          : t('rooms.thematicRoom')),
                  trailing: const Icon(Icons.chevron_right),
                  // La sala se abre como pestaña junto a General
                  // (ya no como pantalla encima): así se puede
                  // chatear en varias salas a la vez deslizando.
                  onTap: () => widget.onOpenRoom(r),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusTab extends StatefulWidget {
  const _StatusTab({super.key, required this.onSeen, required this.myProfile});
  final VoidCallback onSeen;
  final Map<String, dynamic> myProfile;

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab> {
  final _svc = OnechatService();
  late Future<List<Map<String, dynamic>>> _items = _load();
  bool _centerVisible = false;

  @override
  void initState() {
    super.initState();
    _svc.myPowerStatus().then((st) {
      if (mounted) {
        setState(() => _centerVisible = st['center_visible'] == true);
      }
    }).catchError((_) {});
  }

  /// Recarga al volver a la pestaña (la pila de pestañas la mantiene
  /// viva, así que sin esto la lista quedaría vieja).
  void reload() {
    setState(() => _items = _load());
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _svc.fetchNotifications();
    await _svc.markAllRead();
    widget.onSeen();
    return rows;
  }

  /// Texto detallado del aviso: quién, qué y dónde (con lo que
  /// trae el payload; los avisos viejos caen en la etiqueta genérica).
  String _label(Map<String, dynamic> n) {
    final p = (n['payload'] as Map?) ?? const {};
    final from = p['from_nickname'] as String?;
    final room = p['room_name'] as String?;
    switch (n['kind']) {
      case 'mention':
        return from != null
            ? t('status.mentionFrom',
                {'from': from, 'room': room ?? ''})
            : t('status.mention');
      case 'whisper':
        return from != null
            ? t('status.whisperFrom',
                {'from': from, 'room': room ?? ''})
            : t('status.whisper');
      case 'dm':
        return from != null
            ? t('status.dmFrom', {'from': from})
            : t('status.dm');
      case 'favorite_in':
        return t('status.favorite');
      case 'favorite_out':
        return t('status.favoriteIn');
      case 'moderation':
        // Avisos del equipo con alcance por rol (punto 10).
        final action = p['action'] as String?;
        final target = p['target_nickname'] as String? ?? '···';
        final actor = p['actor_nickname'] as String? ?? '···';
        final reporter = p['reporter_nickname'] as String? ?? '···';
        switch (action) {
          case 'auto_mute_link':
            return t('status.modAutoMute', {
              'target': target,
              'room': room ?? '',
              'minutes': '${p['minutes'] ?? ''}',
              'n': '${p['infractions'] ?? ''}',
            });
          case 'report_user':
            return t('status.modReportUser',
                {'reporter': reporter, 'target': target});
          case 'report_error':
            return t('status.modReportError', {'reporter': reporter});
          case 'report_abuse':
            return t('status.modReportAbuse', {'target': target});
          case 'mute':
          case 'unmute':
          case 'ban':
          case 'unban':
          case 'kick':
          case 'feature':
          case 'unfeature':
            return t('status.modAction', {
              'actor': actor,
              'verb': t('mod.verb.$action'),
              'target': target,
              'room': room ?? '',
            });
          default:
            return t('status.moderation');
        }
      case 'system':
        if (p['code'] == 'link_blocked') {
          return t('status.linkBlocked', {
            'room': room ?? '',
            'minutes': '${p['minutes'] ?? ''}',
          });
        }
        return t('status.system');
      case 'game_invite':
        return from != null
            ? t('status.gameInviteFrom', {'from': from})
            : t('status.gameInvite');
      case 'cine_invite':
        return t('status.cineInvite',
            {'nick': p['from_nickname'] as String? ?? from ?? '···'});
      case 'safety':
        // Aviso del Bot de Seguridad (solo Staff/dueño lo reciben).
        final level = '${p['level'] ?? ''}';
        if (from == null) {
          return t('status.safetyGeneric', {'level': level});
        }
        return room != null
            ? t('status.safetyRoom',
                {'level': level, 'from': from, 'room': room})
            : t('status.safetyPrivate', {'level': level, 'from': from});
      default:
        return t('status.system');
    }
  }

  IconData _icon(String? kind) {
    switch (kind) {
      case 'mention':
        return Icons.alternate_email;
      case 'dm':
        return Icons.mail_outline;
      case 'whisper':
        return Icons.chat_bubble_outline;
      case 'game_invite':
        return Icons.sports_esports;
      case 'cine_invite':
        return Icons.movie_outlined;
      case 'safety':
        return Icons.shield_outlined;
      case 'moderation':
        return Icons.gavel;
      default:
        return Icons.notifications_none;
    }
  }

  /// Al tocar un aviso, ir a la actividad: el privado, la sala
  /// de la mención o la conversación del juego.
  Future<void> _open(Map<String, dynamic> n) async {
    final p = (n['payload'] as Map?) ?? const {};
    final kind = n['kind'] as String?;
    if (kind == 'dm' || kind == 'game_invite' || kind == 'cine_invite') {
      final fromUid = p['from_uid'] as String?;
      if (fromUid == null) return;
      final other = await _svc.profileByUid(fromUid);
      if (other == null || !mounted) return;
      final conv = await _svc.getOrCreateConversation(fromUid);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DmChatPage(
            conversationId: conv['id'] as String,
            other: other,
            myProfile: widget.myProfile,
          ),
        ),
      );
      reload();
      return;
    }
    if (kind == 'mention' || kind == 'whisper') {
      final roomId = p['room_id'] as String?;
      if (roomId == null) return;
      final room = await _svc.fetchRoomById(roomId);
      if (room == null || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ChatPage(room: room, myProfile: widget.myProfile),
        ),
      );
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_centerVisible) ...[
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(t('center.open')),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ReportCenterPage())),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _items,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                t('status.empty'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final n = items[i];
            final unread = n['read_at'] == null;
            return ListTile(
              leading: Icon(
                _icon(n['kind'] as String?),
                color: unread ? OneChatColors.mention : null,
              ),
              title: Text(_label(n),
                  style: TextStyle(
                      fontWeight:
                          unread ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text('${n['created_at']}'.substring(0, 16)),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => _open(n),
            );
          },
        );
      },
          ),
        ),
      ],
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.profile, required this.onProfileChanged});
  final Map<String, dynamic> profile;
  final ValueChanged<Map<String, dynamic>> onProfileChanged;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _svc = OnechatService();
  late final _bio = TextEditingController(text: widget.profile['bio'] as String? ?? '');
  bool _saving = false;
  List<Map<String, dynamic>> _gallery = [];
  bool _uploading = false;

  bool get _isRegistered => widget.profile['is_guest'] != true;

  @override
  void initState() {
    super.initState();
    if (_isRegistered) _loadGallery();
  }

  Future<void> _loadGallery() async {
    try {
      final rows = await _svc.myGallery();
      if (mounted) setState(() => _gallery = rows);
    } catch (_) {
      // La Galería es un extra web: si falla, el Perfil sigue.
    }
  }

  Future<void> _saveDirectory(bool value) async {
    await _svc.updateMyProfile(showInDirectory: value);
    final fresh = await _svc.fetchMyProfile();
    if (fresh != null && mounted) widget.onProfileChanged(fresh);
  }

  String get _myPageUrl =>
      '${AppConfig.siteBaseUrl}/u/${Uri.encodeComponent(widget.profile['nickname'] as String)}';

  Future<void> _addPhoto() async {
    final picked = await pickImageBytes();
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      await _svc.uploadGalleryPhoto(picked.$1, picked.$2);
      await _loadGallery();
    } catch (e) {
      if (!mounted) return;
      final limit = e.toString().contains('gallery_limit');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(limit ? t('profile.photoLimit') : '$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(Map<String, dynamic> photo) async {
    await _svc.deleteGalleryPhoto(photo);
    await _loadGallery();
  }

  static const _palette = [
    '#00C2A8', '#4F8CFF', '#FF5252', '#B388FF',
    '#FFB74D', '#FFD54F', '#69F0AE', '#FF80AB',
  ];

  static const _countries = [
    'Argentina', 'Bolivia', 'Brasil', 'Canadá', 'Chile', 'Colombia',
    'Costa Rica', 'Cuba', 'Ecuador', 'El Salvador', 'España',
    'Estados Unidos', 'Guatemala', 'Honduras', 'México', 'Nicaragua',
    'Panamá', 'Paraguay', 'Perú', 'Puerto Rico', 'República Dominicana',
    'Uruguay', 'Venezuela', 'Otro',
  ];

  String _countryLabel(String c) => switch (c) {
        'Estados Unidos' => t('country.US'),
        'Canadá' => t('country.CA'),
        'España' => t('country.ES'),
        'República Dominicana' => t('country.DO'),
        'Otro' => t('country.other'),
        _ => c,
      };

  Future<void> _saveLanguage(String lang) async {
    await _svc.updateMyProfile(language: lang);
    final fresh = await _svc.fetchMyProfile();
    if (fresh != null && mounted) widget.onProfileChanged(fresh);
  }

  Future<void> _saveTheme(String mode) async {
    await _svc.updateMyProfile(themeMode: mode);
    final fresh = await _svc.fetchMyProfile();
    if (fresh != null && mounted) widget.onProfileChanged(fresh);
  }

  Future<void> _saveCountry(String? country) async {
    if (country == null) return;
    await _svc.updateMyProfile(country: country);
    final fresh = await _svc.fetchMyProfile();
    if (fresh != null && mounted) widget.onProfileChanged(fresh);
  }

  /// Ajustes de privacidad y contacto (puntos 11, 12 y 14) y de
  /// sonidos (punto 16).
  Future<void> _savePrivacy({
    bool? dmOpen,
    bool? whispersOpen,
    bool? showSystemNotices,
    bool? soundEnabled,
    bool? vibrateEnabled,
  }) async {
    await _svc.updateMyProfile(
      dmOpen: dmOpen,
      whispersOpen: whispersOpen,
      showSystemNotices: showSystemNotices,
      soundEnabled: soundEnabled,
      vibrateEnabled: vibrateEnabled,
    );
    final fresh = await _svc.fetchMyProfile();
    if (fresh != null && mounted) widget.onProfileChanged(fresh);
  }

  /// Cambio de nickname desde la app (punto 13): el servidor hace
  /// el cambio atómico y aplica el freno de 7 días.
  Future<void> _changeNickname() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('profile.nickTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLength: 20,
              decoration:
                  InputDecoration(labelText: t('profile.nickLabel')),
            ),
            const SizedBox(height: 6),
            Text(t('profile.nickHint'),
                style: const TextStyle(fontSize: 12.5)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('welcome.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('profile.changeNick')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final newNick = ctrl.text.trim();
    final result = await _svc.changeNickname(newNick);
    if (!mounted) return;
    final msg = switch (result) {
      'ok' => t('profile.nickOk', {'nick': newNick}),
      'taken' => t('profile.nickTaken'),
      'invalid' => t('profile.nickInvalid'),
      'same' => t('profile.nickSame'),
      'cooldown' => t('profile.nickCooldown'),
      _ => t('profile.nickError'),
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
    if (result == 'ok') {
      final fresh = await _svc.fetchMyProfile();
      if (fresh != null && mounted) widget.onProfileChanged(fresh);
    }
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _saveColor(String hex) async {
    await _svc.updateMyProfile(colorHex: hex);
    final fresh = await _svc.fetchMyProfile();
    if (fresh != null && mounted) widget.onProfileChanged(fresh);
  }

  Future<void> _saveBio() async {
    setState(() => _saving = true);
    await _svc.updateMyProfile(bio: _bio.text.trim());
    final fresh = await _svc.fetchMyProfile();
    if (!mounted) return;
    setState(() => _saving = false);
    if (fresh != null) widget.onProfileChanged(fresh);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t('profile.saved'))));
  }

  Future<void> _showBlocked() async {
    final uids = await _svc.fetchBlockedUids();
    final profiles = await _svc.profilesByUids(uids.toList());
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('profile.blocked'),
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (profiles.isEmpty) Text(t('profile.noBlocked')),
            for (final p in profiles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p['nickname'] as String),
                trailing: TextButton(
                  child: Text(t('profile.unblock')),
                  onPressed: () async {
                    await _svc.unblock(p['uid'] as String);
                    if (mounted) Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    appThemeMode.value = ThemeMode.dark; // la bienvenida va en oscuro
    await _svc.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SessionGate()),
      (_) => false,
    );
  }

  /// Eliminación de cuenta (requisito de Google Play): confirma,
  /// pide la contraseña en cuentas registradas y llama al
  /// servidor, que borra todo. Al terminar vuelve a la bienvenida.
  Future<void> _confirmDeleteAccount() async {
    final isGuest = (widget.profile['is_guest'] as bool?) ?? false;
    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('profile.deleteTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isGuest
                ? t('profile.deleteGuestBody')
                : t('profile.deleteBody')),
            if (!isGuest) ...[
              const SizedBox(height: 14),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: t('profile.deletePassword')),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('welcome.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('profile.deleteConfirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _svc.deleteMyAccount(
          password: isGuest ? null : passwordCtrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('profile.deleted'))),
      );
      appThemeMode.value = ThemeMode.dark;
      try {
        await _svc.signOut();
      } catch (_) {
        // La sesión ya no existe en el servidor: es lo esperado.
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SessionGate()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final wrong = e.toString().contains('invalid_password') ||
          e.toString().contains('password_required');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(wrong
                ? t('profile.deleteWrongPassword')
                : t('profile.deleteError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: nickColor(p['nickname_color'] as String?),
              child: Text(
                (p['nickname'] as String).substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 26),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['nickname'] as String,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: nickColor(p['nickname_color'] as String?))),
                Text(p['is_guest'] == true
                    ? t('profile.guest')
                    : t('profile.registered')),
                if (p['global_role'] == 'owner')
                  Text(t('profile.roleOwner'),
                      style: TextStyle(
                          color: OneChatColors.roomOwner,
                          fontWeight: FontWeight.w600)),
                if (p['global_role'] == 'staff')
                  Text(t('profile.roleStaff'),
                      style: TextStyle(
                          color: OneChatColors.staff,
                          fontWeight: FontWeight.w600)),
                if (p['global_role'] == 'moderator')
                  Text(t('profile.roleMod'),
                      style: TextStyle(
                          color: OneChatColors.moderator,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(t('profile.color'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: [
            for (final hex in _palette)
              GestureDetector(
                onTap: () => _saveColor(hex),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: nickColor(hex),
                  child: p['nickname_color'] == hex
                      ? const Icon(Icons.check, color: Colors.black, size: 18)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text(t('profile.theme'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
                value: 'system',
                icon: const Icon(Icons.brightness_auto_outlined),
                label: Text(t('profile.themeSystem'))),
            ButtonSegment(
                value: 'dark',
                icon: const Icon(Icons.dark_mode_outlined),
                label: Text(t('profile.themeDark'))),
            ButtonSegment(
                value: 'light',
                icon: const Icon(Icons.light_mode_outlined),
                label: Text(t('profile.themeLight'))),
          ],
          selected: {p['theme_mode'] as String? ?? 'system'},
          onSelectionChanged: (s) => _saveTheme(s.first),
        ),
        const SizedBox(height: 22),
        Text(t('profile.language'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'es', label: Text('Español')),
            ButtonSegment(value: 'en', label: Text('English')),
          ],
          selected: {p['language'] as String? ?? 'es'},
          onSelectionChanged: (s) => _saveLanguage(s.first),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _bio,
          maxLines: 3,
          maxLength: 160,
          decoration: InputDecoration(labelText: t('profile.bio')),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _saveBio,
          child: Text(_saving ? t('profile.saving') : t('profile.save')),
        ),
        const SizedBox(height: 22),
        Text(t('profile.country'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue:
              _countries.contains(p['country']) ? p['country'] as String : null,
          decoration: InputDecoration(labelText: t('profile.countryLabel')),
          items: [
            for (final c in _countries)
              DropdownMenuItem(value: c, child: Text(_countryLabel(c))),
          ],
          onChanged: _saveCountry,
        ),
        const SizedBox(height: 26),
        Text(t('profile.privacySection'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('profile.dmOpen')),
          subtitle: Text(t('profile.dmOpenHint')),
          value: p['dm_open'] != false,
          onChanged: (v) => _savePrivacy(dmOpen: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('profile.whispersOpen')),
          subtitle: Text(t('profile.whispersOpenHint')),
          value: p['whispers_open'] != false,
          onChanged: (v) => _savePrivacy(whispersOpen: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('profile.systemNotices')),
          subtitle: Text(t('profile.systemNoticesHint')),
          value: p['show_system_notices'] != false,
          onChanged: (v) => _savePrivacy(showSystemNotices: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('profile.sound')),
          subtitle: Text(t('profile.soundHint')),
          value: p['sound_enabled'] != false,
          onChanged: (v) => _savePrivacy(soundEnabled: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t('profile.vibrate')),
          subtitle: Text(t('profile.vibrateHint')),
          value: p['vibrate_enabled'] != false,
          onChanged: (v) => _savePrivacy(vibrateEnabled: v),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _changeNickname,
          icon: const Icon(Icons.badge_outlined),
          label: Text(t('profile.changeNick')),
        ),
        if (p['global_role'] == 'owner') ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const _OwnerRolesPage())),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(t('owner.panelTitle')),
          ),
        ],
        const SizedBox(height: 26),
        OutlinedButton.icon(
          onPressed: () => showReportSheet(context),
          icon: const Icon(Icons.flag_outlined),
          label: Text(t('report.button')),
        ),
        if (_isRegistered) ...[
          const SizedBox(height: 26),
          Text(t('profile.webSection'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('profile.directory')),
            subtitle: Text(t('profile.directoryHint')),
            value: p['show_in_directory'] != false,
            onChanged: _saveDirectory,
          ),
          OutlinedButton.icon(
            onPressed: () => openExternalUrl(_myPageUrl),
            icon: const Icon(Icons.open_in_new),
            label: Text(t('profile.viewPage')),
          ),
          const SizedBox(height: 18),
          Text(t('profile.gallery'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(t('profile.galleryHint'),
              style: TextStyle(
                  fontSize: 12.5,
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final photo in _gallery)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photo['url'] as String,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                          width: 84,
                          height: 84,
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        iconSize: 18,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(4),
                          minimumSize: const Size(28, 28),
                        ),
                        icon: const Icon(Icons.close),
                        tooltip: t('profile.deletePhoto'),
                        onPressed: () => _deletePhoto(photo),
                      ),
                    ),
                  ],
                ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _addPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                    _uploading ? t('profile.uploading') : t('profile.addPhoto')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _showBlocked,
          icon: const Icon(Icons.block),
          label: Text(t('profile.blocked')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: Text(t('profile.signOut')),
        ),
        const SizedBox(height: 26),
        TextButton.icon(
          onPressed: _confirmDeleteAccount,
          icon: const Icon(Icons.delete_forever_outlined,
              color: Colors.redAccent),
          label: Text(t('profile.deleteAccount'),
              style: const TextStyle(color: Colors.redAccent)),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'ONEchat · v${AppConfig.appVersion}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }
}

/// Panel del dueño (punto 2): buscar usuarios y otorgar o quitar
/// roles globales (usuario, moderador global, Staff). El servidor
/// (set_global_role) protege al dueño y deja auditoría.
class _OwnerRolesPage extends StatefulWidget {
  const _OwnerRolesPage();

  @override
  State<_OwnerRolesPage> createState() => _OwnerRolesPageState();
}

class _OwnerRolesPageState extends State<_OwnerRolesPage> {
  final _svc = OnechatService();
  final _query = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _searching = false;

  String _roleLabel(String? role) => switch (role) {
        'owner' => t('profile.roleOwner'),
        'staff' => t('profile.roleStaff'),
        'moderator' => t('profile.roleMod'),
        _ => t('profile.roleUser'),
      };

  Future<void> _search() async {
    setState(() => _searching = true);
    try {
      final rows = await _svc.searchProfiles(_query.text);
      if (mounted) setState(() => _results = rows);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _setRole(Map<String, dynamic> p, String role) async {
    final nick = p['nickname'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('owner.setRole', {'nick': nick})),
        content: Text(t('owner.confirmRole',
            {'nick': nick, 'role': _roleLabel(role)})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('sheet.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('sheet.yesApply')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await _svc.setGlobalRole(p['uid'] as String, role);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(done
            ? t('owner.roleSet',
                {'nick': nick, 'role': _roleLabel(role)})
            : t('owner.roleFailed'))));
    if (done) _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('owner.panelTitle'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(t('owner.panelHint'),
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _query,
                  decoration:
                      InputDecoration(labelText: t('owner.searchHint')),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_results.isEmpty)
            Text(t('owner.noResults'))
          else
            for (final p in _results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      nickColor(p['nickname_color'] as String?),
                  child: Text(
                    (p['nickname'] as String)
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(p['nickname'] as String),
                subtitle: Text(_roleLabel(p['global_role'] as String?)),
                trailing: p['global_role'] == 'owner'
                    ? null
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (role) => _setRole(p, role),
                        itemBuilder: (_) => [
                          for (final role
                              in ['user', 'moderator', 'staff'])
                            PopupMenuItem(
                              value: role,
                              child: Text(_roleLabel(role)),
                            ),
                        ],
                      ),
              ),
        ],
      ),
    );
  }
}

/// Icono HUD de la sala Ayuda, SOLO para el Staff (y el dueño):
/// lleva la cuenta en vivo de mensajes de usuarios sin leer en
/// Ayuda y entra directo a la sala. El Staff queda así «siempre
/// presente» en Ayuda sin tener que estar dentro de la sala.
class _StaffHelpButton extends StatefulWidget {
  const _StaffHelpButton({required this.room, required this.myProfile});
  final Map<String, dynamic> room;
  final Map<String, dynamic> myProfile;

  @override
  State<_StaffHelpButton> createState() => _StaffHelpButtonState();
}

class _StaffHelpButtonState extends State<_StaffHelpButton> {
  final _svc = OnechatService();
  int _unread = 0;
  RealtimeChannel? _channel;

  String get _roomId => widget.room['id'] as String;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Membresía silenciosa: el marcador de lectura vive en mi fila.
    await _svc.joinRoom(_roomId);
    await _reload();
    _channel = _svc.subscribeMessages(_roomId, (_) => _reload());
  }

  Future<void> _reload() async {
    final n = await _svc.helpUnreadCount(_roomId);
    if (mounted) setState(() => _unread = n);
  }

  @override
  void dispose() {
    final ch = _channel;
    if (ch != null) _svc.unsubscribe(ch);
    super.dispose();
  }

  Future<void> _open() async {
    await _svc.markHelpRead(_roomId);
    if (mounted) setState(() => _unread = 0);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ChatPage(room: widget.room, myProfile: widget.myProfile),
      ),
    );
    // Al salir, lo que llegó mientras estaba dentro también
    // quedó visto por el Staff.
    await _svc.markHelpRead(_roomId);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: t('help.staffTooltip'),
      onPressed: _open,
      icon: Badge(
        isLabelVisible: _unread > 0,
        label: Text('$_unread'),
        child: const Icon(Icons.support_agent),
      ),
    );
  }
}
