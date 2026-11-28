# Catálogo de películas gratis para Cine juntos

Pedido de Mario (2026-11-27): un catálogo de películas publicadas
en YouTube de acceso gratis, integrado en la opción Cine juntos.

## Criterio de selección (verificado título por título)

1. **Legal**: dominio público (EE. UU.: obras anteriores a 1930 o
   con derechos caducados por falta de renovación/aviso) o cine
   libre con licencia Creative Commons (Blender Studio).
2. **Incrustable**: YouTube debe permitir reproducir el video
   dentro del chat (verificado con `playable_in_embed` de la API
   y con oEmbed: 200 = incrustable, 401 = bloqueado). Sin esto,
   Cine juntos no puede sincronizar la película.
3. Las películas «gratis con anuncios» de la tienda de YouTube
   NO sirven: no se pueden incrustar.

## Excluidas a propósito

- *Tiempos modernos* (1936): incrustable, pero sus derechos en
  EE. UU. siguen vigentes (hasta 2032). Fuera por higiene legal.
- *El chico* (1921), de Chaplin: todas las copias en YouTube
  tienen la incrustación desactivada (oEmbed 401).
- *His Girl Friday* coloreada: se eligió la copia en blanco y
  negro (la coloreada podría tener derechos derivados propios).

## El catálogo (15 títulos, en app/lib/cine_catalog.dart)

Nosferatu (1922) · El gabinete del Dr. Caligari (1920) ·
Metrópolis (1927) · El acorazado Potemkin (1925, copia oficial
Mosfilm) · El hombre de la cámara (1929) · Sherlock Jr. (1924) ·
El maquinista de La General (1926) · Luna nueva (1940) · La
noche de los muertos vivientes (1968) · Charada (1963) ·
Demencia 13 (1963) · Carnaval de almas (1962) · La pequeña
tienda de los horrores (1960) · Plan 9 del espacio exterior
(1959) · Big Buck Bunny (2008, corto CC).

La mayoría son cine silente: el idioma no es barrera para la
comunidad. En la app (v2026.11.26.17) el diálogo de invitación
de Cine juntos ofrece el botón «Catálogo de películas gratis»;
tocar una película envía la invitación al instante. El campo de
enlace libre sigue disponible.
