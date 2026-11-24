# ONEchat — Etapa 5: Traducción

Completada el 2026-11-23. Sobre la Etapa 4.

## Interfaz ES/EN
- Todos los textos de la app viven en `lib/strings.dart`
  (diccionario ES/EN, ~170 claves): bienvenida, registro,
  recuperación, pestañas, salas, chat, privados, fichas,
  moderación y errores de acceso.
- El idioma se guarda en la cuenta (`profiles.language`) y se
  aplica en vivo, igual que el tema: selector Español/English en
  el Perfil y acceso rápido ES/EN en la bienvenida (el invitado
  guarda el idioma elegido al crear su perfil). Agregar un
  idioma nuevo (p. ej. portugués por la sala de Brasil) es sumar
  un diccionario.
- Los nombres de país del selector se muestran localizados; el
  valor guardado sigue siendo el nombre de la sala.

## Traducción de mensajes
- Mantener presionado un mensaje (sala, susurro o privado) →
  «Traducir»: la traducción aparece bajo el mensaje con 🌐;
  «Ver original» la quita. Si el mensaje ya está en el idioma
  del lector, avisa en vez de traducir.
- Función `translate` en Supabase: recibe {text, target} y
  responde {translated, detected}. Detección ES/EN por palabras
  frecuentes; proveedor **MyMemory** (gratuito, sin clave; con el
  correo del proyecto el cupo es 10.000 caracteres/día).
- **DeepL quedó en pausa por decisión del dueño**: su plan
  gratuito «Developer» exige tarjeta de crédito al registrarlo;
  la cuenta de DeepL sí quedó creada (djserver22@gmail.com) por
  si Mario lo activa él mismo. Cambiar de proveedor es tocar
  solo esta función; la app no se entera.

## Verificación
- Función probada como navegador (preflight CORS 200) y con
  sesión real: EN→ES, ES→EN y detección de «ya está en tu
  idioma», todo correcto.
- Análisis sin problemas, prueba de widgets aprobada y
  publicación verificada por hash.
