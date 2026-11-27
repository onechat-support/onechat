# «Cine juntos» con plataformas de streaming — viabilidad

Idea de Mario (2026-11-26): extender Cine juntos a Netflix,
Prime Video y similares — listado de plataformas, tarjeta
segura de credenciales para iniciar sesión, abrir la cuenta,
elegir la película y sincronizar la reproducción entre los
dos usuarios. **Veredicto: NO viable en esa forma.** Tres
bloqueos independientes, cada uno suficiente por sí solo:

## 1. Las plataformas prohíben técnicamente ser incrustadas

- Netflix responde `x-frame-options: DENY` (verificado el
  2026-11-26): ningún sitio puede meter Netflix en un
  iframe, ni siquiera como página completa.
- Prime Video, Disney+ y Max protegen sus reproductores con
  CSP y DRM (Widevine con requisitos de hardware): el video
  solo corre dentro de sus apps y reproductores oficiales.
- YouTube es la excepción porque ofrece un reproductor
  incrustable oficial (por eso Cine juntos funciona con él).

## 2. No existe forma de controlar ni observar la otra cuenta

- Netflix cerró su API pública en 2014; Prime Video, Disney+
  y Max nunca tuvieron una para terceros. Nadie puede enviar
  «play/pausa» ni leer la posición de una cuenta ajena.
- La seguridad del navegador (mismo origen) impide que
  nuestra página mire o toque una pestaña de netflix.com.
- Teleparty (ex Netflix Party) lo logra siendo una
  **extensión del navegador** que se inyecta en la pestaña
  del propio servicio, con cada usuario en su cuenta: es el
  único modelo tolerado y una web/app como ONEchat no puede
  replicarlo.
- Dato de contexto: hasta las propias plataformas
  abandonaron la función — Prime Video eliminó Watch Party
  el 2024-04-02 y Disney+ cerró GroupWatch el 2023-09-18.

## 3. La tarjeta de credenciales incumpliría las normas

- Pedir la contraseña de Netflix dentro de ONEchat viola los
  términos de las plataformas (las credenciales solo se
  ingresan en el servicio oficial; Netflix además prohíbe
  manipular su servicio por medios no autorizados e
  insertar código sobre su contenido).
- Es el patrón exacto del phishing: Google Play lo rechaza
  y cualquier auditoría de seguridad lo marca como crítico.
  Ningún usuario debiera escribir la clave de su banco de
  video en una app de chat, y nosotros no debemos pedirla.

## Lo que SÍ es viable y legal: «Ver juntos» (modo compañero)

Sin incrustar nada y sin tocar credenciales:

- Sesión 1:1 en ONEchat como la de Cine juntos; el anfitrión
  elige plataforma y pega el enlace del título (o lo busca en
  un listado de accesos directos).
- Cada uno abre el título en **su propia** app/pestaña de
  Netflix/Prime/etc., con **su propia** cuenta, en el sitio
  oficial. ONEchat no ve ni guarda ninguna clave.
- ONEchat sincroniza lo que sí puede: **cuenta atrás 3-2-1**
  para que ambos den play al mismo tiempo, un **cronómetro
  de sesión compartido** («van en el 42:10») y un botón de
  **re-sincronizar** que le dice a cada uno a qué minuto
  saltar en su reproductor.
- Es el equivalente digital de lo que la gente ya hace por
  llamada: legal, sin fricción con ninguna norma. La
  sincronía es manual (puede derivar unos segundos) — es el
  máximo honesto sin extensión de navegador.

Estado: solo evaluado, como los «Regalos físicos». No
construir sin orden de Mario.
