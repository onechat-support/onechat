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

/// Tarjeta de video (punto 8): miniatura con botón de play; al
/// tocarla se despliega el reproductor oficial dentro de la app,
/// sin autoplay al llegar el mensaje. Si el dueño del video
/// impide incrustarlo, el reproductor ofrece abrirlo en YouTube.
class YoutubeCard extends StatefulWidget {
  const YoutubeCard({super.key, required this.videoId, this.onPlay});

  final String videoId;

  /// Si se entrega, tocar la miniatura NO despliega el video
  /// dentro de la conversación: avisa al padre, que lo abre en
  /// la ventana flotante (FloatingVideoPlayer).
  final void Function(String videoId)? onPlay;

  @override
  State<YoutubeCard> createState() => _YoutubeCardState();
}

class _YoutubeCardState extends State<YoutubeCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (_open) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: youtubePlayer(widget.videoId),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: () {
          final play = widget.onPlay;
          if (play != null) {
            play(widget.videoId);
          } else {
            setState(() => _open = true);
          }
        },
        onLongPress: () =>
            openExternalUrl('https://www.youtube.com/watch?v=${widget.videoId}'),
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 34),
              ),
            ],
          ),
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
