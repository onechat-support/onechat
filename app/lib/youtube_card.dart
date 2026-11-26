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
  const YoutubeCard({super.key, required this.videoId});

  final String videoId;

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
        onTap: () => setState(() => _open = true),
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
