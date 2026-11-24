import 'package:material_ui/material_ui.dart';

import 'chat_page.dart';
import 'dm_pages.dart';
import 'main.dart';
import 'services.dart';
import 'theme.dart';
import 'user_sheet.dart';

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
  bool _generalFailed = false;
  final _statusKey = GlobalKey<_StatusTabState>();

  @override
  void initState() {
    super.initState();
    _svc.touchLastSeen();
    _refreshUnread();
    _loadGeneral();
  }

  Future<void> _loadGeneral() async {
    try {
      final rooms = await _svc.fetchRooms();
      final general = rooms.where((r) => r['slug'] == 'general').firstOrNull;
      if (!mounted) return;
      setState(() {
        _generalRoom = general;
        _generalFailed = general == null;
      });
    } catch (_) {
      if (mounted) setState(() => _generalFailed = true);
    }
  }

  Widget _generalTab() {
    final room = _generalRoom;
    if (room == null) {
      return Center(
        child: _generalFailed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No se pudo abrir la Sala General.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() => _tab = 1),
                    child: const Text('Ir a las salas'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      );
    }
    return ChatPage(
      room: room,
      myProfile: _profile,
      embedded: true,
      onExit: () => setState(() => _tab = 1),
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
      _RoomsTab(myProfile: _profile),
      ConversationsTab(myProfile: _profile),
      _StatusTab(
        key: _statusKey,
        onSeen: () {
          if (_unread != 0) setState(() => _unread = 0);
        },
      ),
      _ProfileTab(
        profile: _profile,
        onProfileChanged: (p) => setState(() => _profile = p),
      ),
    ];
    return Scaffold(
      // En la pestaña General manda la barra propia de la sala
      // (nombre, en línea, moderación); en las demás, la de ONEchat.
      appBar: _tab == 0
          ? null
          : AppBar(
              title: const Text('ONEchat',
                  style: TextStyle(
                      color: OneChatColors.primary,
                      fontWeight: FontWeight.w800)),
              actions: [
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
          if (i == 3) _statusKey.currentState?.reload();
        },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'General'),
          const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Salas'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _dmUnread > 0,
              label: Text('$_dmUnread'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: 'Privados',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Status',
          ),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
      ),
    );
  }
}

class _RoomsTab extends StatefulWidget {
  const _RoomsTab({required this.myProfile});
  final Map<String, dynamic> myProfile;

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
          return Center(child: Text('Error al cargar salas: ${snap.error}'));
        }
        final rooms = snap.data ?? [];
        // Lista plana con encabezados de sección: Plataforma,
        // Latino, Norteamérica, Europa, Temáticos.
        const headers = {
          'plataforma': 'Plataforma',
          'latino': 'Latino',
          'norteamerica': 'Norteamérica',
          'europa': 'Europa',
          'tematicos': 'Temáticos',
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
                      ? 'Atendida por el Staff'
                      : isRegional
                          ? 'Sala regional'
                          : 'Sala temática'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatPage(room: r, myProfile: widget.myProfile),
                    ),
                  ),
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
  const _StatusTab({super.key, required this.onSeen});
  final VoidCallback onSeen;

  @override
  State<_StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<_StatusTab> {
  final _svc = OnechatService();
  late Future<List<Map<String, dynamic>>> _items = _load();

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

  String _label(Map<String, dynamic> n) {
    switch (n['kind']) {
      case 'mention':
        return 'Te mencionaron en una sala';
      case 'whisper':
        return 'Recibiste un susurro';
      case 'dm':
        return 'Nuevo mensaje privado';
      case 'favorite_in':
        return 'Alguien te agregó a favoritos';
      case 'favorite_out':
        return 'Uno de tus favoritos entró';
      case 'moderation':
        return 'Aviso de moderación';
      default:
        return 'Aviso del sistema';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _items,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Tu Sala Status está tranquila.\nAquí llegarán menciones, susurros, privados y avisos.',
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
                n['kind'] == 'mention'
                    ? Icons.alternate_email
                    : Icons.notifications_none,
                color: unread ? OneChatColors.mention : null,
              ),
              title: Text(_label(n),
                  style: TextStyle(
                      fontWeight:
                          unread ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text('${n['created_at']}'.substring(0, 16)),
            );
          },
        );
      },
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

  static const _palette = [
    '#00C2A8', '#4F8CFF', '#FF5252', '#B388FF',
    '#FFB74D', '#FFD54F', '#69F0AE', '#FF80AB',
  ];

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
        .showSnackBar(const SnackBar(content: Text('Perfil guardado.')));
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
            const Text('Usuarios bloqueados',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (profiles.isEmpty) const Text('No has bloqueado a nadie.'),
            for (final p in profiles)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(p['nickname'] as String),
                trailing: TextButton(
                  child: const Text('Desbloquear'),
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
    await _svc.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SessionGate()),
      (_) => false,
    );
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
                    ? 'Invitado'
                    : 'Cuenta registrada'),
                if (p['global_role'] == 'owner')
                  const Text('Dueño de ONEchat',
                      style: TextStyle(
                          color: OneChatColors.roomOwner,
                          fontWeight: FontWeight.w600)),
                if (p['global_role'] == 'staff')
                  const Text('Staff de ONEchat',
                      style: TextStyle(
                          color: OneChatColors.staff,
                          fontWeight: FontWeight.w600)),
                if (p['global_role'] == 'moderator')
                  const Text('Moderador global',
                      style: TextStyle(
                          color: OneChatColors.moderator,
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text('Color de tu nickname',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
        TextField(
          controller: _bio,
          maxLines: 3,
          maxLength: 160,
          decoration: const InputDecoration(labelText: 'Tu bio'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _saving ? null : _saveBio,
          child: Text(_saving ? 'Guardando…' : 'GUARDAR PERFIL'),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _showBlocked,
          icon: const Icon(Icons.block),
          label: const Text('Usuarios bloqueados'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}
