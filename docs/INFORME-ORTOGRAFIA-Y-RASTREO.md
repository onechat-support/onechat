# ONEchat — Informe de rastreo y revisión ortográfica

**Fecha:** 24 de noviembre de 2026 · **Pedido de:** Mario
(rastrear al invitado «Mario» y revisar la ortografía de
toda la plataforma, partiendo por el «conveza» de la Sala
General).

## Parte 1 — Rastreo del invitado «Mario»

### Lo que la plataforma registra de esa visita

- **Nickname:** Mario (invitado, sin cuenta registrada).
- **Creación del perfil:** 24-11-2026, 07:05:56 (hora del
  Pacífico).
- **Última actividad:** 07:06:33 — la visita completa duró
  unos **40 segundos**.
- **Salas que abrió:** Sala General (07:05:57) y sala
  **Chile** (07:06:39).
- **Mensajes:** ninguno — ni en salas, ni privados, ni
  susurros. No escribió ni una palabra.
- **Idioma de su app:** español. **País declarado:** ninguno
  (dejó el campo vacío). Sin bio, sin foto, sin favoritos
  ni contactos. Rol: usuario común.

### Ubicación de conexión

**No se puede determinar, y es importante que sepas por
qué:** la plataforma, tal como está construida, **no
guarda la dirección IP ni la ubicación de quien se
conecta**. Lo comprobé en las tres fuentes posibles:

1. El perfil solo guarda el país que la propia persona
   declara en su Perfil — este invitado no declaró ninguno.
2. El registro de auditoría de accesos del sistema de
   cuentas se consultó por su identificador y por la
   ventana exacta de su visita (15:04–15:09 UTC): **no
   contiene ningún registro de esa conexión**.
3. No existe ningún otro registro de red en la plataforma.

Los únicos indicios, débiles, son de comportamiento: usó
la app en español y, tras entrar a la General, abrió la
sala **Chile**. Es compatible con alguien de habla hispana
con interés en Chile — pero también con cualquier curioso,
y **no permite afirmar un país ni una ciudad**.

**Conclusión del rastreo:** fue una visita fantasma de 40
segundos: entró con tu nombre, miró dos salas y se fue sin
escribir nada. No tocó nada ni dejó rastro aprovechable.
Si quieres que en el futuro sí se pueda ubicar una
conexión así, habría que agregar el registro de IP al
momento de entrar (con su aviso de privacidad
correspondiente); es una decisión tuya y queda anotada
como opción, no implementada.

## Parte 2 — Revisión ortográfica de la plataforma

### Alcance revisado (100 % de los textos visibles)

- El diccionario completo de textos de la app en
  **español** (unas 190 frases: bienvenida, cuentas, salas,
  chat, susurros, privados, moderación, ficha de usuario,
  juego del Gato, Status y Perfil) y su espejo en
  **inglés**.
- Los **nombres de las 30 salas** y sus **mensajes de
  bienvenida** guardados en la base de datos.
- Los **mensajes del equipo** (PruebaZeth) en General y
  Ayuda, incluida la presentación del acceso anticipado.
- Textos fijos fuera del diccionario (pantallas, título de
  la pestaña del navegador, manifiesto de la app).
- Los documentos entregados: Manual de administración y
  Plan de la web oficial.
- Método: lectura completa, línea por línea, más una
  pasada automática con diccionario ortográfico como
  segunda red (sus alertas resultaron ser palabras
  correctas ausentes de ese diccionario; se verificaron
  una a una).

### El caso «conveza»

Busqué la palabra «conveza» en **todo** el sistema — código
de la app, base de datos (bienvenidas, mensajes de salas y
privados), documentos y mensajes del equipo — y **no
aparece en ninguna parte**. El texto vigente de bienvenida
de la Sala General, tal como está guardado y se muestra al
entrar, es:

> «Bienvenido a la Sala General de ONEchat. Pasa, saluda y
> **conversa** con todos.»

— con «conversa» correctamente escrito, igual que en la
bienvenida de Ayuda («¿Necesitas ayuda? Aquí te atiende el
Staff de ONEchat.») y en el eslogan de la pantalla de
acceso («Salas para **conversar**, como las de antes»).

Es posible que lo hayas leído en una captura rápida en la
pantalla del teléfono, o en una versión en caché de la
primera noche. Si lo vuelves a ver, mándame una captura y
lo cazo en el acto: con la evidencia de hoy, la plataforma
no contiene ese error.

### Hallazgos y correcciones

**Errores ortográficos en los textos de la app: ninguno.**
Tildes, signos de apertura (¿ ¡) y concordancia están
correctos en todo el diccionario en español, y el inglés
no presenta errores.

**Una corrección aplicada (redacción, no ortografía):** la
pestaña del navegador mostraba el título «onechat» en
minúscula y la descripción genérica que trae la plantilla
(«A new Flutter project.»). Quedó corregido y publicado:
título **«ONEchat»** y descripción «ONEchat — Salas para
conversar, como las de antes. Entra, elige tu nickname y a
chatear.», también en el manifiesto de la app. Es el texto
que se ve al compartir el enlace y en el historial del
navegador.

### Observaciones de estilo (sin cambios; quedan a tu criterio)

- En inglés, el juego se presenta como «Tic-Tac-Toe» y en
  español como «Gato»: correcto para el público de cada
  idioma.
- «Status» se mantiene como nombre de la pestaña en ambos
  idiomas, por ser el nombre propio de esa sección en el
  diseño original.
- Los verbos de moderación en inglés («unban», «unmute»)
  son jerga habitual de plataformas; en español se usa la
  forma completa («quitar baneo», «quitar silencio»).

## Resumen

- Invitado «Mario»: visita de 40 segundos, dos salas,
  cero mensajes; su ubicación **no es recuperable** porque
  la plataforma no registra IPs (decisión de diseño que
  puedes cambiar si lo pides).
- Ortografía: **sin errores** en los textos de la
  plataforma; «conveza» no existe en el sistema; la única
  corrección fue el título y la descripción de la pestaña
  web, ya publicados.
