import 'package:material_ui/material_ui.dart';

import 'chat_page.dart';
import 'theme.dart';

/// Pestañas de salas (pedido de Mario, 2026-11-26): varias salas
/// abiertas a la vez en la pestaña principal, con una fila de
/// pestañas arriba y un PageView que se recorre deslizando el
/// dedo. Cada sala abierta queda viva (presencia y mensajes
/// siguen corriendo en todas). General es la primera y no se
/// puede cerrar; las demás se cierran con la ✕. Máximo 6.
class RoomsHost extends StatefulWidget {
  const RoomsHost({
    super.key,
    required this.generalRoom,
    required this.myProfile,
    required this.onGoToRooms,
    this.generalExtraActions,
  });

  final Map<String, dynamic> generalRoom;
  final Map<String, dynamic> myProfile;
  final VoidCallback onGoToRooms;
  final List<Widget>? generalExtraActions;

  @override
  State<RoomsHost> createState() => RoomsHostState();
}

class RoomsHostState extends State<RoomsHost> {
  static const maxOpen = 6;
  final List<Map<String, dynamic>> _open = [];
  final PageController _pager = PageController();
  int _current = 0;
  bool _countryAutoOpened = false;

  @override
  void initState() {
    super.initState();
    _open.add(widget.generalRoom);
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  static bool _isGeneral(Map<String, dynamic> r) => r['slug'] == 'general';

  /// Abre la sala como pestaña, o salta a ella si ya está
  /// abierta. Devuelve false si se alcanzó el máximo.
  bool openRoom(Map<String, dynamic> room, {bool switchTo = true}) {
    final idx = _open.indexWhere((r) => r['id'] == room['id']);
    if (idx >= 0) {
      if (switchTo) _goTo(idx);
      return true;
    }
    if (_open.length >= maxOpen) return false;
    setState(() => _open.add(room));
    if (switchTo) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _goTo(_open.length - 1));
    }
    return true;
  }

  /// Auto-apertura de la sala del país según la IP (una sola
  /// vez por sesión; si el usuario la cierra, no vuelve sola).
  void autoOpenCountry(
      List<Map<String, dynamic>> rooms, String? countryName) {
    if (_countryAutoOpened || countryName == null) return;
    _countryAutoOpened = true;
    for (final r in rooms) {
      if (r['country'] == countryName) {
        openRoom(r, switchTo: false);
        return;
      }
    }
  }

  void _goTo(int idx) {
    if (!_pager.hasClients) return;
    _pager.animateToPage(idx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut);
  }

  void _closeRoom(int idx) {
    if (idx <= 0 || idx >= _open.length) return; // General no se cierra
    setState(() {
      _open.removeAt(idx);
      if (_current >= _open.length) _current = _open.length - 1;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pager.hasClients) _pager.jumpToPage(_current);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            itemCount: _open.length,
            itemBuilder: (context, i) {
              final r = _open[i];
              final selected = i == _current;
              final general = _isGeneral(r);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: Material(
                  color: selected
                      ? OneChatColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _goTo(i),
                    child: Padding(
                      padding:
                          EdgeInsets.only(left: 12, right: general ? 12 : 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            r['name'] as String,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected ? Colors.black : null,
                            ),
                          ),
                          if (!general)
                            InkWell(
                              onTap: () => _closeRoom(i),
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close, size: 15),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pager,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: _open.length,
            itemBuilder: (context, i) {
              final r = _open[i];
              final general = _isGeneral(r);
              return _KeepAlive(
                key: ValueKey(r['id'] as String),
                child: ChatPage(
                  room: r,
                  myProfile: widget.myProfile,
                  embedded: true,
                  onExit: general
                      ? widget.onGoToRooms
                      : () => _closeRoom(i),
                  extraActions:
                      general ? widget.generalExtraActions : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Mantiene viva la sala aunque el PageView la deje fuera de
/// pantalla: la gracia de las pestañas es que todas las salas
/// abiertas siguen recibiendo mensajes y presencia.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({super.key, required this.child});
  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
