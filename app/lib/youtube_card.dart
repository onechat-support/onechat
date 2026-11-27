import 'package:material_ui/material_ui.dart';

import 'fx.dart';
import 'web_links.dart';

/// Extrae el id de video de YouTube de un texto, si lo hay
/// (watch, youtu.be, shorts o embed). Mismas casas que permite
/// el servidor: youtube.com y youtu.be.
String? youtubeIdFromText(String text) {
  final patterns = [
    RegExp(r'youtu\.be/([A-Za-z0-9_-]{6,})'),
    RegExp(r'youtube\.com/watch\?[^ ]*v=([A-Za-z0-9_-]{6,})'),
    RegExp(r'youtube\.com/shorts/([A-Za-z0-9_-]{6,})'),
    RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{6,})'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(text);
    if (m != null) return m.group(1);
  }
  return null;
}

/// La URL de YouTube tal como aparece escrita en el texto.
String? youtubeUrlMatch(String text) {
  final patterns = [
    RegExp(r'youtu\.be/[A-Za-z0-9_-]{6,}'),
    RegExp(r'youtube\.com/watch\?[^ ]*'),
    RegExp(r'youtube\.com/shorts/[A-Za-z0-9_-]{6,}'),
    RegExp(r'youtube\.com/embed/[A-Za-z0-9_-]{6,}'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(text);
    if (m != null) return m.group(0);
  }
  return null;
}

/// El cuerpo del mensaje sin la URL de YouTube: el enlace
/// bonito («YouTube - título») la reemplaza visualmente.
String bodyWithoutYoutubeUrl(String body) {
  final u = youtubeUrlMatch(body);
  if (u == null) return body;
  return body.replaceFirst(u, '').replaceAll(RegExp(r' {2,}'), ' ').trim();
}

/// Enlace de video SIN previsualización (pedido de Mario,
/// 2026-11-27): la miniatura ocupaba mucho espacio en la sala.
/// Queda una sola línea azul, «YouTube - <título del video>»,
/// que al tocarla abre la ventana flotante. El título llega
/// del oEmbed oficial de YouTube y se cachea por video
/// durante la sesión; si no carga, el enlace dice «YouTube».
class YoutubeTitleLink extends StatefulWidget {
  const YoutubeTitleLink(
      {super.key, required this.videoId, required this.onPlay});

  final String videoId;
  final void Function(String videoId) onPlay;

  @override
  State<YoutubeTitleLink> createState() => _YoutubeTitleLinkState();
}

class _YoutubeTitleLinkState extends State<YoutubeTitleLink> {
  static final Map<String, String> _cache = {};
  String? _title;

  @override
  void initState() {
    super.initState();
    _title = _cache[widget.videoId];
    if (_title == null) _load();
  }

  Future<void> _load() async {
    final t = await fetchYoutubeTitle(widget.videoId);
    if (t != null) _cache[widget.videoId] = t;
    if (mounted && t != null) setState(() => _title = t);
  }

  @override
  Widget build(BuildContext context) {
    final label = _title == null ? 'YouTube' : 'YouTube - $_title';
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: InkWell(
        onTap: () => widget.onPlay(widget.videoId),
        onLongPress: () => openExternalUrl(
            'https://www.youtube.com/watch?v=${widget.videoId}'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_outline,
                size: 16, color: Color(0xFF4F8CFF)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4F8CFF),
                  decoration: TextDecoration.underline,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ventana flotante del reproductor (pedido de Mario,
/// 2026-11-26): el video no se despliega dentro de la
/// conversación — flota sobre el chat, se arrastra desde su
/// barra superior y se cierra con la ✕. La conversación no se
/// mueve ni se reordena: la ventana vive en su propia capa.
class FloatingVideoPlayer extends StatefulWidget {
  const FloatingVideoPlayer({
    super.key,
    required this.videoId,
    required this.onClose,
  });

  final String videoId;
  final VoidCallback onClose;

  @override
  State<FloatingVideoPlayer> createState() => _FloatingVideoPlayerState();
}

class _FloatingVideoPlayerState extends State<FloatingVideoPlayer> {
  Offset? _pos;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = (constraints.maxWidth - 24).clamp(200.0, 340.0).toDouble();
        const barH = 30.0;
        final totalH = barH + w * 9 / 16;
        var maxX = constraints.maxWidth - w - 8;
        if (maxX < 8) maxX = 8;
        var maxY = constraints.maxHeight - totalH - 8;
        if (maxY < 8) maxY = 8;
        var x = _pos?.dx ?? maxX;
        var y = _pos?.dy ?? (maxY - 64); // por defecto, sobre el compositor
        x = x.clamp(8.0, maxX).toDouble();
        y = y.clamp(8.0, maxY).toDouble();
        return Stack(
          children: [
            Positioned(
              left: x,
              top: y,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: w,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onPanUpdate: (d) => setState(() {
                          _pos = Offset(
                            (x + d.delta.dx).clamp(8.0, maxX).toDouble(),
                            (y + d.delta.dy).clamp(8.0, maxY).toDouble(),
                          );
                        }),
                        child: Container(
                          height: barH,
                          color: Colors.black87,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.drag_handle,
                                  size: 16, color: Colors.white70),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text('YouTube',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12)),
                              ),
                              InkWell(
                                onTap: widget.onClose,
                                child: const Icon(Icons.close,
                                    size: 18, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                      KeyedSubtree(
                        key: ValueKey(widget.videoId),
                        child: youtubePlayer(widget.videoId),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
