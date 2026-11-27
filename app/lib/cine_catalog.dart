import 'package:material_ui/material_ui.dart';

import 'strings.dart';

/// Catálogo de películas GRATIS y LEGALES para «Cine juntos»:
/// clásicos de dominio público y cine libre (Creative Commons)
/// publicados en YouTube. Cada video fue verificado el
/// 2026-11-27: existe y YouTube permite reproducirlo incrustado
/// (sin esa condición, Cine juntos no puede sincronizarlo).
/// Quedaron fuera a propósito: «Tiempos modernos» (aún con
/// derechos vigentes en EE. UU.) y «El chico» de Chaplin (todas
/// sus copias en YouTube tienen la incrustación desactivada).
class CineMovie {
  final String title;
  final String originalTitle;
  final int year;
  final String genre;
  final String language;
  final int minutes;
  final String synopsis;
  final String videoId;

  const CineMovie({
    required this.title,
    required this.originalTitle,
    required this.year,
    required this.genre,
    required this.language,
    required this.minutes,
    required this.synopsis,
    required this.videoId,
  });

  String get meta => '$year · $genre · $language · $minutes min';
}

const List<CineMovie> cineCatalog = [
  CineMovie(
    title: 'Nosferatu',
    originalTitle: 'Nosferatu',
    year: 1922,
    genre: 'Terror',
    language: 'Silente',
    minutes: 88,
    synopsis:
        'El conde Orlok llega a Alemania sediento de sangre: el clásico que inventó al vampiro en el cine.',
    videoId: 'dCT1YUtNOA8',
  ),
  CineMovie(
    title: 'El gabinete del Dr. Caligari',
    originalTitle: 'Das Cabinet des Dr. Caligari',
    year: 1920,
    genre: 'Terror · Misterio',
    language: 'Silente',
    minutes: 75,
    synopsis:
        'Un hipnotista y su sonámbulo asesino en una pesadilla expresionista que fundó el cine de terror.',
    videoId: 'zV00ylxcwXw',
  ),
  CineMovie(
    title: 'Metrópolis',
    originalTitle: 'Metropolis',
    year: 1927,
    genre: 'Ciencia ficción',
    language: 'Silente',
    minutes: 149,
    synopsis:
        'La ciudad futurista dividida entre élites y obreros, en la obra maestra de Fritz Lang.',
    videoId: 'enwB5zZfaV4',
  ),
  CineMovie(
    title: 'El acorazado Potemkin',
    originalTitle: 'Bronenosets Potemkin',
    year: 1925,
    genre: 'Drama histórico',
    language: 'Silente',
    minutes: 71,
    synopsis:
        'El motín del acorazado y la escalinata de Odesa: la película que cambió el montaje para siempre. Copia oficial de Mosfilm.',
    videoId: 'a_bkBbrdyyw',
  ),
  CineMovie(
    title: 'El hombre de la cámara',
    originalTitle: 'Chelovek s kino-apparatom',
    year: 1929,
    genre: 'Documental',
    language: 'Silente',
    minutes: 67,
    synopsis:
        'Un día en la ciudad filmado con una libertad que todavía parece moderna.',
    videoId: '64jLxgCWukY',
  ),
  CineMovie(
    title: 'Sherlock Jr.',
    originalTitle: 'Sherlock Jr.',
    year: 1924,
    genre: 'Comedia',
    language: 'Silente',
    minutes: 45,
    synopsis:
        'Buster Keaton se duerme en la sala de proyección y entra en la pantalla a resolver el crimen.',
    videoId: 'fZuqWxITq38',
  ),
  CineMovie(
    title: 'El maquinista de La General',
    originalTitle: 'The General',
    year: 1926,
    genre: 'Comedia · Aventura',
    language: 'Silente',
    minutes: 79,
    synopsis:
        'Keaton persigue su locomotora robada en plena Guerra Civil: su obra cumbre.',
    videoId: 'D_UdtS-8QS0',
  ),
  CineMovie(
    title: 'Luna nueva',
    originalTitle: 'His Girl Friday',
    year: 1940,
    genre: 'Comedia romántica',
    language: 'Inglés',
    minutes: 92,
    synopsis:
        'Un editor hace lo imposible por recuperar a su ex esposa… y a su mejor reportera. Diálogos a velocidad de vértigo.',
    videoId: 'kmYcT5gT6a4',
  ),
  CineMovie(
    title: 'La noche de los muertos vivientes',
    originalTitle: 'Night of the Living Dead',
    year: 1968,
    genre: 'Terror',
    language: 'Inglés',
    minutes: 96,
    synopsis:
        'Siete personas atrapadas en una granja mientras los muertos caminan. El origen del zombi moderno, de George A. Romero.',
    videoId: 'IpDosODDwK8',
  ),
  CineMovie(
    title: 'Charada',
    originalTitle: 'Charade',
    year: 1963,
    genre: 'Suspenso · Comedia',
    language: 'Inglés',
    minutes: 113,
    synopsis:
        'Audrey Hepburn y Cary Grant entre París, un botín y varios asesinos. La mejor película de Hitchcock que Hitchcock no hizo.',
    videoId: 'VhGNhwOtbVs',
  ),
  CineMovie(
    title: 'Demencia 13',
    originalTitle: 'Dementia 13',
    year: 1963,
    genre: 'Terror',
    language: 'Inglés',
    minutes: 75,
    synopsis:
        'Una viuda, un castillo irlandés y un asesino con un hacha: el debut de Francis Ford Coppola.',
    videoId: 'h_avxeGLXUA',
  ),
  CineMovie(
    title: 'Carnaval de almas',
    originalTitle: 'Carnival of Souls',
    year: 1962,
    genre: 'Terror',
    language: 'Inglés',
    minutes: 78,
    synopsis:
        'Tras un accidente, una organista es perseguida por un hombre pálido que nadie más parece ver.',
    videoId: 'vNYg4YWkp0k',
  ),
  CineMovie(
    title: 'La pequeña tienda de los horrores',
    originalTitle: 'The Little Shop of Horrors',
    year: 1960,
    genre: 'Comedia · Terror',
    language: 'Inglés',
    minutes: 73,
    synopsis:
        'Una planta carnívora que solo crece con un alimento muy especial… «¡Aliméntame, Seymour!».',
    videoId: 'aZ2CuqGkHZ8',
  ),
  CineMovie(
    title: 'Plan 9 del espacio exterior',
    originalTitle: 'Plan 9 from Outer Space',
    year: 1959,
    genre: 'Ciencia ficción · Culto',
    language: 'Inglés',
    minutes: 78,
    synopsis:
        'Extraterrestres resucitan cadáveres para salvar la Tierra: la «peor película de la historia» es hoy un clásico de culto.',
    videoId: 'luIuvnKjb6E',
  ),
  CineMovie(
    title: 'Big Buck Bunny',
    originalTitle: 'Big Buck Bunny',
    year: 2008,
    genre: 'Animación · Corto',
    language: 'Sin diálogos',
    minutes: 10,
    synopsis:
        'Un conejo gigante se cansa de los abusones del bosque. Corto libre de Blender Studio, ideal para probar Cine juntos.',
    videoId: 'YE7VzlLtp-4',
  ),
];

/// Selector del catálogo: devuelve el videoId elegido (o null).
class CineCatalogPage extends StatelessWidget {
  const CineCatalogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('cine.catalogTitle'))),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: cineCatalog.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(t('cine.catalogNote'),
                  style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            );
          }
          final m = cineCatalog[i - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () => Navigator.pop(ctx, m.videoId),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        'https://i.ytimg.com/vi/${m.videoId}/hqdefault.jpg',
                        width: 128,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 128, height: 72),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5)),
                          const SizedBox(height: 2),
                          Text(m.meta,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text(m.synopsis,
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
