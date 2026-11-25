import 'package:material_ui/material_ui.dart';

import 'services.dart';
import 'strings.dart';

String _fmtDate(dynamic iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso.toString())?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Abre el selector del centro de reportes: error, usuario o abuso de
/// poder. Desde una sala llega el contexto de la sala; desde la ficha
/// de un usuario, la persona ya viene elegida.
Future<void> showReportSheet(
  BuildContext context, {
  String? roomId,
  String? roomName,
  Map<String, dynamic>? presetTarget,
  bool targetHasPower = false,
}) {
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text(t('report.choosePrompt'),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(t('report.kindError')),
            subtitle: Text(t('report.kindErrorSub')),
            onTap: () {
              Navigator.pop(sheetCtx);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReportFormPage(
                    kind: 'error', roomId: roomId, roomName: roomName),
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: Text(t('report.kindUser')),
            subtitle: Text(t('report.kindUserSub')),
            onTap: () {
              Navigator.pop(sheetCtx);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ReportFormPage(
                    kind: 'user',
                    roomId: roomId,
                    roomName: roomName,
                    presetTarget: presetTarget),
              ));
            },
          ),
          if (presetTarget == null || targetHasPower)
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(t('report.kindAbuse')),
              subtitle: Text(t('report.kindAbuseSub')),
              onTap: () {
                Navigator.pop(sheetCtx);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReportFormPage(
                      kind: 'abuse',
                      roomId: roomId,
                      roomName: roomName,
                      presetTarget: presetTarget),
                ));
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Formulario de un reporte. La evidencia la adjunta el servidor al
/// enviar; aquí solo se elige a la persona (si aplica) y se describe.
class ReportFormPage extends StatefulWidget {
  const ReportFormPage({
    super.key,
    required this.kind,
    this.roomId,
    this.roomName,
    this.presetTarget,
  });
  final String kind; // error | user | abuse
  final String? roomId;
  final String? roomName;
  final Map<String, dynamic>? presetTarget;

  @override
  State<ReportFormPage> createState() => _ReportFormPageState();
}

class _ReportFormPageState extends State<ReportFormPage> {
  final _svc = OnechatService();
  final _desc = TextEditingController();
  bool _sending = false;
  bool _loadingPeople = false;
  List<Map<String, dynamic>> _rooms = [];
  String? _roomId;
  String? _roomName;
  List<Map<String, dynamic>> _people = [];
  Map<String, dynamic>? _target;

  String get _title => widget.kind == 'error'
      ? t('report.errorTitle')
      : widget.kind == 'abuse'
          ? t('report.abuseTitle')
          : t('report.userTitle');

  String get _evidenceNote => widget.kind == 'error'
      ? t('report.evidenceNoteError')
      : widget.kind == 'abuse'
          ? t('report.evidenceNoteAbuse')
          : t('report.evidenceNoteUser');

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId;
    _roomName = widget.roomName;
    _target = widget.presetTarget;
    if (widget.kind != 'error' && widget.presetTarget == null) {
      if (_roomId != null) {
        _loadPeople();
      } else {
        _loadRooms();
      }
    }
  }

  Future<void> _loadRooms() async {
    final rooms = await _svc.fetchRooms();
    if (mounted) setState(() => _rooms = rooms);
  }

  Future<void> _loadPeople() async {
    if (_roomId == null) return;
    setState(() => _loadingPeople = true);
    try {
      final members = await _svc.roomMembersInfo(_roomId!);
      final room = await _svc.fetchRoomById(_roomId!);
      final ownerUid = room?['owner_uid'] as String?;
      final profiles = await _svc.profilesByUids(members.keys.toList());
      final byUid = {for (final p in profiles) p['uid'] as String: p};
      final people = <Map<String, dynamic>>[];
      for (final entry in members.entries) {
        if (entry.key == _svc.myUid) continue;
        final p = byUid[entry.key];
        if (p == null) continue;
        final role = entry.value['role'] as String? ?? 'member';
        final globalRole = p['global_role'] as String? ?? 'user';
        final hasPower = role == 'owner' ||
            role == 'moderator' ||
            globalRole == 'staff' ||
            globalRole == 'owner' ||
            entry.key == ownerUid;
        if (widget.kind == 'abuse' && !hasPower) continue;
        people.add(p);
      }
      people.sort((a, b) => (a['nickname'] as String)
          .toLowerCase()
          .compareTo((b['nickname'] as String).toLowerCase()));
      if (mounted) setState(() => _people = people);
    } finally {
      if (mounted) setState(() => _loadingPeople = false);
    }
  }

  bool get _canSend =>
      !_sending &&
      _desc.text.trim().length >= 3 &&
      (widget.kind == 'error' || _target != null);

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await _svc.submitReport(
        kind: widget.kind,
        targetUid: _target?['uid'] as String?,
        roomId: _roomId,
        description: _desc.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t('report.sent'))));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('report.failed'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.kind != 'error' && widget.presetTarget == null) ...[
            if (_roomId == null) ...[
              Text(t('report.pickRoom'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_rooms.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                DropdownButtonFormField<String>(
                  items: [
                    for (final r in _rooms)
                      DropdownMenuItem(
                        value: r['id'] as String,
                        child: Text(r['name'] as String),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    final room =
                        _rooms.firstWhere((r) => r['id'] == v);
                    setState(() {
                      _roomId = v;
                      _roomName = room['name'] as String;
                      _target = null;
                      _people = [];
                    });
                    _loadPeople();
                  },
                ),
            ] else ...[
              Text(
                  widget.kind == 'abuse'
                      ? t('report.pickPower')
                      : t('report.pickUser'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (_roomName != null)
                Text(t('center.room', {'name': _roomName!})),
              const SizedBox(height: 8),
              if (_loadingPeople)
                const Center(child: CircularProgressIndicator())
              else if (_people.isEmpty)
                Text(t('report.noPeople'))
              else
                DropdownButtonFormField<String>(
                  initialValue: _target?['uid'] as String?,
                  items: [
                    for (final p in _people)
                      DropdownMenuItem(
                        value: p['uid'] as String,
                        child: Text(p['nickname'] as String),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _target =
                        _people.firstWhere((p) => p['uid'] == v));
                  },
                ),
            ],
            const SizedBox(height: 16),
          ],
          if (widget.presetTarget != null) ...[
            Text(
                '${t('report.targetFixed')}: ${widget.presetTarget!['nickname']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _desc,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t('report.description'),
              hintText: t('report.descriptionHint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(_evidenceNote)),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _canSend ? _send : null,
            child: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t('report.send')),
          ),
        ],
      ),
    );
  }
}

/// Centro de reportes: lo ven el dueño, el Staff y los moderadores,
/// cada uno con su alcance (lo impone el servidor por RLS).
class ReportCenterPage extends StatefulWidget {
  const ReportCenterPage({super.key});

  @override
  State<ReportCenterPage> createState() => _ReportCenterPageState();
}

class _ReportCenterPageState extends State<ReportCenterPage> {
  final _svc = OnechatService();
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  String _filter = 'all'; // all | new | review | closed

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _svc.fetchReportsCenter();
    if (mounted) {
      setState(() {
        _reports = rows;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible => _reports.where((r) {
        final s = r['status'] as String;
        return switch (_filter) {
          'new' => s == 'new',
          'review' => s == 'review',
          'closed' => s == 'resolved' || s == 'dismissed',
          _ => true,
        };
      }).toList();

  Color _statusColor(String s) => switch (s) {
        'new' => Colors.redAccent,
        'review' => Colors.orange,
        'resolved' => Colors.green,
        _ => Colors.grey,
      };

  String _statusText(String s) => switch (s) {
        'new' => t('center.statusNew'),
        'review' => t('center.statusReview'),
        'resolved' => t('center.statusResolved'),
        _ => t('center.statusDismissed'),
      };

  String _kindText(String k) => switch (k) {
        'error' => t('center.kindError'),
        'abuse' => t('center.kindAbuse'),
        _ => t('center.kindUser'),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('center.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            tooltip: t('conduct.view'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ConductPage(readOnly: true))),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                for (final (key, label) in [
                  ('all', t('center.filterAll')),
                  ('new', t('center.filterNew')),
                  ('review', t('center.filterReview')),
                  ('closed', t('center.filterClosed')),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == key,
                      onSelected: (_) => setState(() => _filter = key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _visible.isEmpty
                    ? Center(child: Text(t('center.empty')))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _visible.length,
                          itemBuilder: (context, i) {
                            final r = _visible[i];
                            return ListTile(
                              leading: Icon(
                                r['kind'] == 'error'
                                    ? Icons.bug_report_outlined
                                    : r['kind'] == 'abuse'
                                        ? Icons.gavel_outlined
                                        : Icons.person_off_outlined,
                              ),
                              title: Text(
                                '${_kindText(r['kind'] as String)}'
                                '${r['target_nickname'] != null ? ' · ${r['target_nickname']}' : ''}',
                              ),
                              subtitle: Text(
                                '${r['description']}\n${_fmtDate(r['created_at'])}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                label: Text(_statusText(r['status'] as String),
                                    style: const TextStyle(fontSize: 11)),
                                side: BorderSide(
                                    color: _statusColor(r['status'] as String)),
                              ),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          _ReportDetailPage(report: r)),
                                );
                                _load();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ReportDetailPage extends StatefulWidget {
  const _ReportDetailPage({required this.report});
  final Map<String, dynamic> report;

  @override
  State<_ReportDetailPage> createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<_ReportDetailPage> {
  final _svc = OnechatService();
  bool _busy = false;

  Map<String, dynamic> get _r => widget.report;

  Future<void> _act(String status) async {
    String? note;
    if (status != 'review') {
      final ctrl = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(status == 'resolved'
              ? t('center.resolve')
              : t('center.dismiss')),
          content: TextField(
            controller: ctrl,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: t('center.note'),
              hintText: t('center.noteHint'),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('sheet.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(t('report.send')),
            ),
          ],
        ),
      );
      if (note == null || !mounted) return;
    }
    setState(() => _busy = true);
    final ok = await _svc.resolveReport(_r['id'] as int, status, note: note);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? t('center.actionDone') : t('center.actionFailed'))));
    if (ok) Navigator.of(context).pop();
  }

  Widget _evidence() {
    final ev = _r['evidence'];
    if (ev is! Map) return Text(t('center.evidenceEmpty'));
    final msgs = ev['room_messages'];
    if (msgs is List && msgs.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('center.evidenceMessages'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final m in msgs)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  '${_fmtDate(m['at'])} · ${m['from']}: ${m['body']}'),
            ),
        ],
      );
    }
    final acts = ev['mod_actions'];
    if (acts is List && acts.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('center.evidenceActions'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          for (final a in acts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                  '${_fmtDate(a['at'])} · ${a['action']}'
                  '${a['target'] != null ? ' → ${a['target']}' : ''}'
                  '${a['room'] != null ? ' · ${a['room']}' : ''}'
                  '${a['detail'] != null ? ' · ${a['detail']}' : ''}'),
            ),
        ],
      );
    }
    return Text(t('center.evidenceEmpty'));
  }

  @override
  Widget build(BuildContext context) {
    final status = _r['status'] as String;
    final closed = status == 'resolved' || status == 'dismissed';
    return Scaffold(
      appBar: AppBar(title: Text(t('center.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_r['description'] as String,
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          Text(t('center.reporter', {'name': '${_r['reporter_nickname']}'})),
          if (_r['target_nickname'] != null)
            Text(t('center.target', {'name': '${_r['target_nickname']}'})),
          if (_r['room_name'] != null)
            Text(t('center.room', {'name': '${_r['room_name']}'})),
          Text(_fmtDate(_r['created_at'])),
          const Divider(height: 28),
          _evidence(),
          if (closed) ...[
            const Divider(height: 28),
            if (_r['resolution_note'] != null &&
                (_r['resolution_note'] as String).isNotEmpty)
              Text('${t('center.note')}: ${_r['resolution_note']}'),
            if (_r['resolved_by_nickname'] != null)
              Text(t('center.resolvedBy',
                  {'name': '${_r['resolved_by_nickname']}'})),
          ],
          if (!closed) ...[
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status == 'new')
                  OutlinedButton(
                    onPressed: _busy ? null : () => _act('review'),
                    child: Text(t('center.markReview')),
                  ),
                FilledButton(
                  onPressed: _busy ? null : () => _act('resolved'),
                  child: Text(t('center.resolve')),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _act('dismissed'),
                  child: Text(t('center.dismiss')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// El código de conducta del poder. Con readOnly=false es la
/// aceptación que se pide a quien recibe un rol con poder.
class ConductPage extends StatelessWidget {
  const ConductPage({super.key, this.readOnly = false});
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final svc = OnechatService();
    return Scaffold(
      appBar: AppBar(title: Text(t('conduct.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t('conduct.intro')),
          const SizedBox(height: 16),
          Text(t('conduct.body')),
          const SizedBox(height: 20),
          Text(t('conduct.ladderTitle'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(t('conduct.ladder')),
          if (!readOnly) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                await svc.acceptConduct();
                if (context.mounted) Navigator.of(context).pop(true);
              },
              child: Text(t('conduct.accept')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(t('conduct.later')),
            ),
          ],
        ],
      ),
    );
  }
}

bool _conductPromptShown = false;

/// Si el usuario tiene poder y aún no aceptó el código de conducta,
/// se lo presenta una vez por sesión (condición para ejercer el rol).
Future<void> maybeShowConduct(BuildContext context) async {
  if (_conductPromptShown) return;
  _conductPromptShown = true;
  final svc = OnechatService();
  try {
    final st = await svc.myPowerStatus();
    if (st['has_power'] == true && st['conduct_accepted'] != true) {
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ConductPage(readOnly: false)));
    }
  } catch (_) {
    // Si la función aún no existe (migración en curso), no bloquear.
  }
}
