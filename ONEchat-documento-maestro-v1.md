# Email

## Message

From: Mario Valdes <m.valdesur@gmail.com>  
To: m.valdesur@gmail.com  
Subject: ONEchat — Documento Maestro v1.0 para Muse  
Sent: Sun, 22 Nov 2026 22:53:59 -0800  
Sent (UTC): 2026-11-23T06:53:59.000Z  
Sent (America/Los_Angeles): 2026-11-22T22:53:59.000-08:00  
Gmail message: 1a2072ed7063e762  
Thread: 1a2072ed7063e762  
Message-ID: CAJ=T_76eX5pq87_AtEB8n2RB2aLYR8MTCm6qTjn56kzAoqgkhA@mail.gmail.com  
Body coverage: full  
Body format: markdown  

## Attachments

No attachments.

## Body

ONEchat — DOCUMENTO MAESTRO DE PRODUCTO, ARQUITECTURA Y PLAN DE DESARROLLO
Versión 1.0 reconstruida — 22 de noviembre de 2026
Destinatario: propietario del proyecto / agente de desarrollo Muse

IMPORTANTE SOBRE ESTA COPIA
El archivo maestro original no pudo recuperarse como archivo. Este documento es una reconstrucción a partir de la información de proyecto disponible, no una copia literal del documento anterior. Los requisitos aquí descritos son objetivos de producto; no prueban que estén implementados. Muse debe auditar el estado real antes de modificar o programar.

1. VISIÓN DEL PRODUCTO
ONEchat es una aplicación social de chat basada en salas permanentes, conversación espontánea y descubrimiento de comunidades y personas. Recupera la experiencia social de salas clásicas (MSN, IRC, LatinChat/Terra Chat y servicios similares) con una experiencia moderna, segura, multiplataforma e internacional.
No debe convertirse simplemente en otro WhatsApp, Telegram o Discord ni limitarse a chat aleatorio/dating. La experiencia central es entrar rápidamente con un nickname, encontrar salas activas y conversar. Debe admitir invitados y cuentas persistentes, con funciones sociales esenciales gratuitas y beneficios Premium no abusivos.

2. ACCESO, IDENTIDAD Y AUTENTICACIÓN
WelcomePage prioriza un campo de nickname y botón CHATEAR DIRECTAMENTE. Debajo: Crear cuenta e Iniciar sesión. Al continuar, comprobar si el nickname está registrado: si no, permitir invitado; si está registrado, exigir autenticación y evitar suplantación.
Registro permanente: nickname, email, contraseña y color de nickname. Incluir recuperación de contraseña. Nicknames únicos, insensibles a mayúsculas/minúsculas (Mario/mario/MARIO es la misma identidad), reservados atómicamente en backend. El invitado debe poder convertirse en cuenta permanente conservando UID, nickname y perfil si la arquitectura lo permite. Evaluar Firebase Anonymous Auth y vinculación de credenciales. No confiar en validaciones solo del cliente.

3. SALAS Y NAVEGACIÓN
Al entrar, mostrar Sala Status, sala regional según preferencia y dos salas sugeridas. La región se configura por país/preferencia; no exigir GPS preciso. Varias salas abiertas en pestañas, cambiar entre ellas y cerrar con X. Permitir búsqueda e ingreso manual. Tipos: regionales, temáticas, públicas, privadas por invitación/permisos y temporales.
Sala Status es un centro personal de notificaciones e historial, no necesariamente una sala pública: avisos del sistema/moderación, menciones, privados y susurros recibidos, favoritos que entran/salen y otros eventos relevantes.

4. CHAT PÚBLICO Y PRESENCIA
Mensajes de texto en tiempo real, lista de usuarios conectados, eventos de entrada/salida, nickname y color, rangos, mensajes de sistema, menciones, favoritos y susurros. Presencia configurable para avisos de conexiones, desconexiones, entradas y salidas. Distinguir online/offline/ausente y gestionar desconexiones inesperadas.
Nota técnica: Firestore por sí solo no proporciona presencia fiable equivalente a conexión persistente. Evaluar Firebase Realtime Database y Cloud Functions para sincronización/limpieza.

5. FUNCIONES SOCIALES
Menciones: el destinatario recibe aviso y evento en Status; el mensaje aparece rojo solo para él y normal para otros. Es una presentación individual, no se modifica el contenido compartido.
Favoritos: estrella junto al nickname; mensajes resaltados en rojo solo para quien marcó; avisos de entrada/salida/desconexión según preferencias.
Susurros: mensajes privados/ocultos enviados desde cualquier sala sin abrir conversación privada convencional; morado y aviso en Status. Solo emisor y destinatario pueden leerlos, con reglas backend reales.
Bloqueo: no mostrar mensajes públicos del bloqueado al bloqueador ni recibir sus privados, susurros o notificaciones. No basta con ocultación visual.

6. MENSAJES PRIVADOS Y JUEGOS
Conversaciones 1:1 con historial, tiempo real, timestamps, no leídos, notificaciones y bloqueo.
Notas de voz solo en privados como beneficio Premium: grabar, reproducir, mostrar duración y enviar/recibir; Firebase Storage con permisos estrictos.
Juegos VS por invitación dentro del chat y sincronización en tiempo real. Orden: Gato (tres en raya), Conecta 4, Damas, Ludo y Ajedrez. Priorizar Gato. Movimientos y turnos validados en servidor; no permitir manipulación del cliente.

7. PERFILES
Foto principal, nickname, color, biografía breve, visitas, insignias y rango. Fecha de registro, nacionalidad, sexo y edad opcionales. Privacidad/visibilidad configurable. Prevenir visitas artificiales. Galería ampliada Premium, con eliminación, reportes y moderación.

8. RANGOS Y MODERACIÓN
Staff: poderes globales. Dueño de sala: editar bienvenida, asignar moderadores, destacar, banear y silenciar en su sala. Moderador: destacar, banear y silenciar en salas autorizadas. Usuario destacado: reconocimiento visual temporal, sin poderes.
Insignias visuales no otorgan permisos. Verificar permisos en backend y auditar acciones críticas. Incluir reportes, normas, anti-spam, límites de envío, bloqueo, sanciones y mecanismos de revisión.

9. TEMAS Y DISEÑO
Paleta de referencia: principal turquesa #00C2A8; secundario azul #4F8CFF; fondo oscuro #121212; superficies #1E1E1E; tarjetas #242424; texto #FFFFFF; secundario #B0B0B0. Menciones #FF5252; susurros #B388FF; favoritos #FF6B6B; moderadores #FFB74D; dueños #FFD54F; Staff #00E5C4.
Modos: system, dark y light. Guardar preferencia de registrados; persistencia local para invitados si viable. Temas futuros: ONEchat Classic, Neon, Premium y MSN Classic. El modo claro requiere contraste accesible. theme_mode fue propuesto, pero su existencia real debe verificarse.

10. TRADUCCIÓN E INTERNACIONALIZACIÓN
Interfaz inicial español/inglés. Traducción opcional automática de mensajes, detección de idioma, preferencia del receptor, mensaje original siempre disponible, traducción manual/automática configurable. Evaluar Google Cloud Translation u otro proveedor vía Cloud Functions. No exponer claves API en cliente; medir costos por caracteres y usar caché. Preparar portugués, francés, alemán e italiano, salas globales/regionales, perfiles con idiomas, búsqueda y eventos multilingües.

11. FUNCIONES INSPIRADAS EN MSN
Zumbidos en privados: efecto visual, vibración si el dispositivo lo soporta y sonido configurable; límites antiabuso y opción de desactivación.
Mostrar música escuchada solo mediante integraciones autorizadas y voluntarias con servicios musicales; no extraer datos privados ni usar métodos no autorizados.

12. PREMIUM
Gratuito: invitados, registro, salas públicas, mensajes públicos, privados de texto, perfiles básicos, favoritos, menciones, susurros, bloqueos y funciones sociales esenciales.
Premium mensual: notas de voz en privados, galería ampliada, temas exclusivos y personalización avanzada y beneficios cosméticos. No vender poderes de moderación ni inmunidad.
Pagos mediante Google Play Billing y Apple In-App Purchase; backend verifica compras, renovaciones, cancelaciones, expiraciones, reembolsos y restauraciones. No confiar en flags locales.

13. COMUNIDAD Y RETENCIÓN
Antigüedad, fecha de ingreso, años en ONEchat y rachas opcionales. Actividad: mensajes, salas visitadas, eventos y tiempo conectado con criterios transparentes. Insignias: pionero, veterano, fundador, colaborador, moderador, creador de salas y organizador. Destacados semanales, eventos regionales/globales/temporales/temáticos, salas recomendadas, usuarios sugeridos, amigos en línea y salas populares/nuevas. Evitar incentivar spam o actividad artificial.

14. ARQUITECTURA TÉCNICA PROPUESTA
Frontend: FlutterFlow + Flutter. Backend: Firebase Authentication, Cloud Firestore, Storage, Cloud Functions, Cloud Messaging y App Check; evaluar Realtime Database para presencia.
Colecciones mencionadas inicialmente: users, rooms, room_messages y notifications; verificar que existan. Campos mencionados/propuestos en users: email, display_name, photo_url, uid, created_time, phone_number, nickname, nickname_lower, bio, nickname_color, is_guest, is_registered, global_role, language, status, last_seen, profile_views, country, gender y age. No asumir que todos existen. theme_mode e is_online fueron propuestos y deben comprobarse.
El ID Firebase se mencionó como onechat-52b44; confirmar antes de actuar.
Cloud Functions para nickname único, permisos, pagos, traducción, moderación y juegos. Secretos solo backend. Reglas Firestore/Storage por usuario, sala, conversación y permiso. App Check, anti-spam, reportes, bloqueo, eliminación de cuentas/datos, privacidad, términos y normas comunitarias.

15. ROADMAP OFICIAL (12 FASES)
1 Infraestructura: Firebase, FlutterFlow, Firestore, Auth, Storage, plataformas y seguridad inicial.
2 Acceso: nickname, invitados, cuentas registradas, login, recuperación y conversión de invitado.
3 Chat público: Lobby, regionales/temáticas, pestañas, realtime, usuarios, presencia básica y Status.
4 Perfiles: fotos, bio, datos opcionales, visitas, colores e insignias.
5 Temas: oscuro, claro, automático y preferencias.
6 Comunicación avanzada: menciones, favoritos, susurros, privados, bloqueos, notificaciones e historial.
7 Moderación: Staff, dueños, moderadores, destacados, silencios, baneos e insignias.
8 Traducción: detección, proveedor externo, original, manual y preferencias.
9 Premium: suscripción, voz, galería, temas, pagos y verificación.
10 Juegos: Gato, Conecta 4, Damas, Ludo y Ajedrez.
11 Comunidad/retención: antigüedad, actividad, insignias, eventos, rankings y descubrimiento.
12 Crecimiento internacional: idiomas, comunidades, salas globales, búsqueda y optimización.
Las fases no son independientes. Resolver desde arquitectura inicial UID/identidad, nickname único, permisos, modelo de mensajes, privados, presencia, notificaciones, traducción, Premium y juegos.

16. ESTADO HISTÓRICO CONOCIDO: AUDITAR, NO ASUMIR
FlutterFlow y Firebase se conectaron y la configuración inicial se realizó. Se indicó que Firestore tenía colecciones y Authentication estaba habilitado; verificarlo. Storage y reglas deben verificarse.
Páginas mencionadas: WelcomePage, LoginPage, RegisterPage y HomePage. GuestLoginPage y NickRegisteredPage fueron propuestas; comprobar existencia.
No había chat funcional ni flujo completo de login. Último punto de pausa conocido: WelcomePage, campo nickname no vinculado a variable/acción; el usuario no encontraba nicknameInput. No asumir que Status y Lobby están creadas.
El propietario tiene poca experiencia técnica; explicar pasos de forma sencilla.

17. AUDITORÍA OBLIGATORIA DE MUSE ANTES DE PROGRAMAR
Inspeccionar FlutterFlow: páginas, componentes, acciones, navegación y variables.
Inspeccionar Firebase real: proyecto, Auth, Firestore, Storage, Functions, FCM, App Check y Realtime Database.
Inventariar colecciones, campos, índices y reglas. Revisar Android/iOS y compilación.
Entregar matriz de estado: implementado, parcial, ausente, desconocido y conflicto.
Proponer arquitectura definitiva, modelo de datos, permisos, navegación, backend, servicios externos, costos y riesgos.
Esperar aprobación del propietario antes de cambios estructurales.

18. SEGURIDAD, CALIDAD Y PUBLICACIÓN
Reglas Firestore/Storage por usuario, sala, conversación y permiso; App Check y validación servidor; claves solo backend; privacidad real de privados/susurros; reportar/bloquear; auditoría y moderación; eliminación de cuenta/datos; cumplimiento de tiendas para UGC, reportes, bloqueo, privacidad y compras.
Backups antes de cambios, Git, versiones estables y entornos separados dev/prod. Cada módulo debe pasar pruebas funcionales, seguridad, rendimiento y experiencia; una pantalla no significa función terminada.
Android: firma, AAB, pruebas internas, ficha, privacidad, clasificación y rollout. iOS: Bundle ID, certificados, App Store Connect, TestFlight, ficha, privacidad e IAP.
El propietario conserva control de Firebase, FlutterFlow, GitHub, tiendas, dominios y servicios. Muse recibe permisos limitados. No publicar ni gastar sin aprobación expresa.

19. ENCARGO OPERATIVO PARA MUSE
Muse es el agente IA designado para desarrollar ONEchat. Debe:
- No programar hasta terminar auditoría.
- Presentar informe con evidencia y diferencias frente a este documento.
- Proponer arquitectura, datos, reglas, backend, costos y riesgos.
- Pedir aprobación para gastos, acciones irreversibles y cambios de alcance.
- Construir fase por fase con entregables y pruebas verificables.
- Documentar cambios y decisiones; mantener compatibilidad y evitar duplicación.
- No alterar objetivos funcionales sin explicar y obtener aprobación.
- No declarar terminado un módulo por tener solo UI.
- No publicar sin autorización final.
- Explicar avances en lenguaje comprensible para una persona no técnica.

20. RECOMENDACIÓN DE EJECUCIÓN
Recomendación: definir primero un MVP centrado en acceso seguro, salas, chat público, presencia básica, Status, perfiles mínimos, bloqueo y reportes. Privados avanzados, traducción, Premium, juegos y rankings pueden añadirse después, pero la arquitectura inicial debe permitirlos. Riesgos principales: alcance excesivo, presencia inconsistente, privacidad débil, colisiones de nickname, costos de traducción/Firebase, abuso de usuarios y dependencia de proveedor.

FIN DEL DOCUMENTO
Esta es una reconstrucción para transferencia. La aprobación del propietario prevalece sobre inferencias o propuestas del agente.
