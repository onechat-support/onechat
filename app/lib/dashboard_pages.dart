import 'package:material_ui/material_ui.dart';

import 'services.dart';
import 'strings.dart';
import 'theme.dart';

/// Paneles de control (v1.29, pedido del dueño 2026-11-28).
///
/// - Panel global: SOLO Staff y dueño de la plataforma. Datos
///   relevantes, moderación y gráficos de conexiones con su
///   ORIGEN (Instagram, buscadores, redes, directo) y país.
/// - Panel de sala: dueños de sala y moderadores ven SOLO los
///   datos de su sala (historial de moderación, sancionados,
///   actividad diaria del equipo y ranking de moderadores).
///   El Staff global ve todas las salas.
/// El servidor verifica cada permiso en los RPC dashboard_*;
/// estas páginas solo presentan lo que el servidor entrega.

String _fmtDate(dynamic iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso.toString())?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

String _fmtTime(dynamic iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso.toString())?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}') ?? 0;
}

List<Map<String, dynamic>> _asList(dynamic v) {
  if (v is List) {
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  return const [];
}

String _sourceLabel(String code) {
  final key = 'dash.source.$code';
  final label = t(key);
  return label == key ? code : label;
}

/// Tarjeta de cifra grande.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.icon});
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Icon(icon, size: 18, color: OneChatColors.primary),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    fontSize: 12, color: OneChatColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Barras horizontales etiqueta/cantidad para orígenes, países
/// y páginas. [rawLabel] muestra la etiqueta tal cual (países,
/// páginas); si es false, la etiqueta es un código de origen.
class _Bars extends StatelessWidget {
  const _Bars({required this.rows, this.rawLabel = false});
  final List<Map<String, dynamic>> rows;
  final bool rawLabel;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('—',
            style: TextStyle(color: OneChatColors.textSecondary)),
      );
    }
    final maxCount =
        rows.map((r) => _asInt(r['count'])).fold<int>(1, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 128,
                  child: Text(
                    rawLabel
                        ? '${r['source'] ?? ''}'
                        : _sourceLabel('${r['source'] ?? ''}'),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _asInt(r['count']) / maxCount,
                      minHeight: 10,
                      backgroundColor: OneChatColors.darkCard,
                      color: OneChatColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_asInt(r['count'])}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Columnas verticales para la serie de conexiones por día.
class _DayColumns extends StatelessWidget {
  const _DayColumns({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxCount =
        rows.map((r) => _asInt(r['count'])).fold<int>(1, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 108,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final r in rows)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${_asInt(r['count'])}',
                      style: const TextStyle(fontSize: 9)),
                  const SizedBox(height: 2),
                  Container(
                    height: 56 * (_asInt(r['count']) / maxCount) + 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: OneChatColors.secondary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r['day'] ?? ''}'.length >= 10
                        ? '${r['day']}'.substring(5)
                        : '${r['day'] ?? ''}',
                    style: const TextStyle(
                        fontSize: 8, color: OneChatColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}

/// Página raíz del Panel de control: datos globales si el
/// usuario es Staff/dueño global, y la lista de paneles de
/// sala a los que tiene acceso.
class ControlPanelPage extends StatefulWidget {
  const ControlPanelPage({super.key});

  @override
  State<ControlPanelPage> createState() => _ControlPanelPageState();
}

class _ControlPanelPageState extends State<ControlPanelPage> {
  final _svc = OnechatService();
  late Future<Map<String, dynamic>> _mine = _svc.dashboardMyRooms();
  Future<Map<String, dynamic>>? _global;

  @override
  void initState() {
    super.initState();
    _mine.then((m) {
      if (mounted && m['is_staff'] == true) {
        setState(() => _global = _svc.dashboardGlobal());
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('dash.title'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _mine,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? const {};
          if (data['error'] == 'forbidden') {
            return Center(child: Text(t('dash.forbidden')));
          }
          final isStaff = data['is_staff'] == true;
          final rooms = _asList(data['rooms']);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (isStaff && _global != null)
                FutureBuilder<Map<String, dynamic>>(
                  future: _global,
                  builder: (context, gsnap) {
                    if (gsnap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final g = gsnap.data ?? const {};
                    if (g['error'] == 'forbidden') {
                      return const SizedBox.shrink();
                    }
                    return _GlobalPanel(data: g);
                  },
                ),
              _SectionTitle(t('dash.myRooms')),
              if (rooms.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t('dash.noRooms'),
                      style: const TextStyle(
                          color: OneChatColors.textSecondary)),
                ),
              for (final r in rooms)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.meeting_room_outlined,
                        color: OneChatColors.primary),
                    title: Text('${r['name'] ?? ''}'),
                    subtitle: Text(r['my_role'] == 'owner'
                        ? t('dash.roleOwner')
                        : r['my_role'] == 'moderator'
                            ? t('dash.roleModerator')
                            : 'Staff'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoomDashboardPage(
                          roomId: '${r['id']}',
                          roomName: '${r['name'] ?? ''}',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// El bloque global (Staff/dueño): cifras, orígenes y países.
class _GlobalPanel extends StatelessWidget {
  const _GlobalPanel({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(t('dash.global')),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            _StatCard(
                label: t('dash.users'),
                value: '${_asInt(data['users_total'])}',
                icon: Icons.people_outline),
            _StatCard(
                label: t('dash.registered'),
                value: '${_asInt(data['users_registered'])}',
                icon: Icons.badge_outlined),
            _StatCard(
                label: t('dash.guests'),
                value: '${_asInt(data['users_guests'])}',
                icon: Icons.person_outline),
            _StatCard(
                label: t('dash.new7d'),
                value: '${_asInt(data['users_new_7d'])}',
                icon: Icons.person_add_outlined),
            _StatCard(
                label: t('dash.connectionsToday'),
                value: '${_asInt(data['connections_today'])}',
                icon: Icons.login),
            _StatCard(
                label: t('dash.connections7d'),
                value: '${_asInt(data['connections_7d'])}',
                icon: Icons.insights),
            _StatCard(
                label: '${t('dash.webVisits')} (7d)',
                value: '${_asInt(data['web_visits_7d'])}',
                icon: Icons.language),
          ],
        ),
        _SectionTitle(t('dash.byDay')),
        _DayColumns(rows: _asList(data['connections_by_day'])),
        _SectionTitle(t('dash.chatSources')),
        _Bars(rows: _asList(data['chat_sources_7d'])),
        _SectionTitle(t('dash.webSources')),
        _Bars(rows: _asList(data['web_sources_7d'])),
        _SectionTitle(t('dash.webPages')),
        _Bars(rows: _asList(data['web_pages_7d']), rawLabel: true),
        _SectionTitle(t('dash.countries')),
        _Bars(rows: _asList(data['countries_7d']), rawLabel: true),
        _SectionTitle(t('dash.moderation')),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            _StatCard(
                label: t('dash.modActions7d'),
                value: '${_asInt(data['mod_actions_7d'])}',
                icon: Icons.gavel_outlined),
            _StatCard(
                label: t('dash.bansActive'),
                value: '${_asInt(data['platform_bans_active'])}',
                icon: Icons.block_outlined),
            _StatCard(
                label: t('dash.reportsPending'),
                value: '${_asInt(data['reports_pending'])}',
                icon: Icons.flag_outlined),
          ],
        ),
      ],
    );
  }
}

/// Panel de una sala: equipo y ranking de moderadores,
/// conexiones del equipo hoy, sancionados e historial.
class RoomDashboardPage extends StatefulWidget {
  const RoomDashboardPage(
      {super.key, required this.roomId, required this.roomName});
  final String roomId;
  final String roomName;

  @override
  State<RoomDashboardPage> createState() => _RoomDashboardPageState();
}

class _RoomDashboardPageState extends State<RoomDashboardPage> {
  final _svc = OnechatService();
  late Future<Map<String, dynamic>> _data = _svc.dashboardRoom(widget.roomId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${t('dash.roomPanel')} · ${widget.roomName}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _data,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data ?? const {};
          if (d['error'] != null) {
            return Center(child: Text(t('dash.forbidden')));
          }
          final mods = _asList(d['moderators']);
          final today = _asList(d['mod_today']);
          final sanctioned = _asList(d['sanctioned_now']);
          final history = _asList(d['history']);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.7,
                children: [
                  _StatCard(
                      label: t('dash.messages3h'),
                      value: '${_asInt(d['messages_3h'])}',
                      icon: Icons.chat_bubble_outline),
                  _StatCard(
                      label: t('dash.members'),
                      value: '${_asInt(d['members_now'])}',
                      icon: Icons.people_outline),
                ],
              ),
              _SectionTitle(t('dash.team')),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Text(t('dash.rankingNote'),
                    style: const TextStyle(
                        fontSize: 12, color: OneChatColors.textSecondary)),
              ),
              if (mods.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t('dash.noHistory'),
                      style: const TextStyle(
                          color: OneChatColors.textSecondary)),
                ),
              for (var i = 0; i < mods.length; i++)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: i == 0
                          ? OneChatColors.roomOwner
                          : OneChatColors.darkCard,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              color: i == 0 ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text('${mods[i]['nickname'] ?? ''}'),
                    subtitle: Text(
                      '${mods[i]['role'] == 'owner' ? t('dash.roleOwner') : t('dash.roleModerator')}'
                      ' · ${_asInt(mods[i]['actions_7d'])} ${t('dash.actions')} (7d)'
                      ' · ${_asInt(mods[i]['actions_total'])} ${t('dash.actionsTotal')}\n'
                      '${_asInt(mods[i]['connections_7d'])} ${t('dash.connections')} (7d)'
                      ' · ${_asInt(mods[i]['active_days_7d'])} ${t('dash.activeDays')}'
                      ' · ${t('dash.lastSeen')}: ${_fmtDate(mods[i]['last_seen'])}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              _SectionTitle(t('dash.todayTeam')),
              if (today.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('—',
                      style: const TextStyle(
                          color: OneChatColors.textSecondary)),
                ),
              for (final r in today)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.access_time, size: 18),
                  title: Text('${r['nickname'] ?? ''}'),
                  subtitle: Text(
                      '${_asInt(r['connections'])} ${t('dash.connections')}'
                      ' · ${t('dash.firstAt')} ${_fmtTime(r['first_at'])}'
                      ' · ${t('dash.lastAt')} ${_fmtTime(r['last_at'])}'),
                ),
              _SectionTitle(t('dash.sanctionedNow')),
              if (sanctioned.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t('dash.noneSanctioned'),
                      style: const TextStyle(
                          color: OneChatColors.textSecondary)),
                ),
              for (final s in sanctioned)
                ListTile(
                  dense: true,
                  leading: Icon(
                      s['kind'] == 'ban' ? Icons.block : Icons.volume_off,
                      size: 18,
                      color: OneChatColors.mention),
                  title: Text('${s['nickname'] ?? ''}'),
                  subtitle: Text(s['kind'] == 'ban'
                      ? 'Ban'
                      : 'Mute · ${_fmtDate(s['until'])}'),
                ),
              _SectionTitle(t('dash.history')),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(t('dash.noHistory'),
                      style: const TextStyle(
                          color: OneChatColors.textSecondary)),
                ),
              for (final h in history)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.gavel_outlined, size: 18),
                  title: Text(
                      '${h['actor'] ?? ''} · ${h['action'] ?? ''} · ${h['target'] ?? ''}'),
                  subtitle: Text(
                      '${_fmtDate(h['at'])}${(h['detail'] ?? '') != '' ? ' · ${h['detail']}' : ''}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
