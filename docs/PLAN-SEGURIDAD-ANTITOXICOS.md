# ONEchat — Plan de acción contra usuarios tóxicos

**Fecha:** 24 de noviembre de 2026 · **Estado:** PROPUESTA
PRIORITARIA — se implementa por fases con la aprobación
de Mario.
**Motivo (palabras del dueño):** en los chats en español
(como Chatsi) una parte de la comunidad acosa, amenaza,
suplanta identidades para obtener datos de otros y
publicarlos, y evade los baneos cambiando su IP. Eso daña
la reputación de la app, la estabilidad de la comunidad y
la integridad emocional — y hasta física — de las
personas. ONEchat nace con la defensa construida, no
parchada después.

## 1. La verdad técnica sobre el «baneo por MAC»

Mario pidió buscar la manera de bloquear directamente la
**MAC del dispositivo**. La respuesta honesta, verificada
contra cómo funciona internet:

**Ninguna app web ni servicio en línea puede obtener la
MAC de un visitante. Es físicamente imposible, para
nosotros y para Chatsi:**

- La MAC es un identificador de la red local (el tramo
  entre el teléfono y su router). Al salir a internet, el
  router la reemplaza: **la MAC nunca viaja más allá de la
  casa del usuario**. Nuestro servidor jamás la recibe.
- Los navegadores no tienen ninguna función que la
  entregue (sería un agujero de privacidad gigante).
- Incluso las apps nativas están bloqueadas: iOS la oculta
  desde 2013 y Android la entrega falsa/aleatoria desde
  Android 10 — y los teléfonos modernos además **rotan una
  MAC aleatoria por cada red Wi-Fi**.

Quien prometa «baneo por MAC» en un chat web está
vendiendo humo. **Pero el objetivo detrás del pedido —
que un expulsado no vuelva aunque cambie su IP — sí se
puede lograr**, y mejor: con una combinación de capas que
es el estándar de las plataformas serias. Eso es este
plan.

## 2. El enemigo: cómo opera el tóxico típico

1. Entra como invitado con nicks desechables, uno tras
   otro.
2. Acosa y amenaza en salas y por privado; si lo banean,
   cambia su IP (Wi-Fi/datos, reiniciar el router, VPN) y
   vuelve en minutos.
3. Se hace pasar por otros (nick parecido al de una
   víctima o al del Staff) para engañar y sacar datos
   personales: teléfono, redes, dirección.
4. Publica esos datos en el chat (doxxing) para exponer a
   la víctima ante todos.
5. Si le cierran una cuenta, abre diez más.

Cada capa del plan corta uno de esos pasos.

## 3. El sistema de defensa (5 capas)

### Capa 1 — Identidad del dispositivo (la «huella»)
Al entrar, la app genera un **identificador de
dispositivo** y calcula una **huella** con señales del
navegador (pantalla, gráficos, idioma, zona, fuentes y
otras características técnicas combinadas). La huella se
guarda en el servidor junto a la cuenta y la IP, y en el
dispositivo se guarda en **varios lugares a la vez**
(almacenamiento local, base interna, caché y el motor de
la app): borrar uno no basta para «ser otro».
- Cambiar la IP ya no sirve: el dispositivo sigue siendo
  el mismo.
- Evadir exige borrar todo el rastro Y alterar las
  características del equipo: posible para un técnico
  paciente, imposible para el tóxico común que hoy vuelve
  en 2 minutos.

### Capa 2 — El Destierro (el «castigo supremo»)
Una sanción global que solo aplican el **dueño y el
Staff**, desde la ficha del usuario, con un toque:
**«Desterrar»**. Bloquea a la vez:
- la **cuenta** (si es registrada),
- la **huella del dispositivo** (ese equipo no vuelve a
  entrar, ni como invitado ni con otra cuenta),
- la **IP** actual, y con historial repetido, el **rango**
  de IP.
La persona desterrada ve una pantalla única: «Tu acceso a
ONEchat fue revocado». Sin detalles técnicos (no le
enseñamos qué lo detectó). Todo destierro queda en el
registro de auditoría: quién lo aplicó, cuándo, a quién y
por qué motivo (campo obligatorio). El dueño puede
levantarlo; el Staff puede aplicar destierros temporales
(24 h / 7 días / 30 días) y solo el dueño los
permanentes.

### Capa 3 — Fricción contra cuentas desechables
- **Límite de invitados por dispositivo e IP:** máximo de
  cuentas de invitado nuevas por día desde el mismo
  equipo/red (propuesta: 3). El usuario normal ni lo nota;
  el que fabrica alts choca con una pared.
- **Correos desechables bloqueados** al registrarse
  (listas públicas de dominios temporales).
- La cuenta registrada con historial vale más: los
  invitados nuevos tendrán límites suaves (p. ej., sus
  primeros mensajes no pueden contener enlaces — ya
  teníamos la regla de enlaces anotada para post-alfa;
  esto la refuerza).

### Capa 4 — Protección del anonimato y anti-doxxing
Esto protege a los **buenos**, que es la mitad del pedido:
- La plataforma **nunca muestra** correos ni IP a otros
  usuarios (ya es así: el correo vive solo en el servidor
  y la IP solo la ve el Staff).
- **Detector de datos personales en salas:** si un mensaje
  público contiene patrones de teléfono, correo, dirección
  o documento de identidad, el mensaje **no se publica**,
  el autor recibe un aviso («no se permite publicar datos
  personales») y el intento queda registrado ante el
  Staff. Repetir = sanción automática creciente y
  candidato a destierro.
- **Anti-suplantación:** un invitado no puede usar el
  nick de una cuenta registrada **ni una imitación visual**
  (cambios tipo l→1, o→0, mayúsculas, acentos, espacios).
  Los nicks del Staff y del dueño quedan blindados igual.
  En la ficha de cada persona se ve si es «Cuenta
  registrada» o «Invitado» (ya existe) para que nadie se
  haga pasar por otro.
- **Reportes con evidencia:** al reportar, el sistema
  guarda copia de los mensajes del contexto, para que el
  Staff juzgue con pruebas aunque el tóxico se vaya o
  cambie de nick (hoy el reporte existe; falta adjuntar la
  evidencia automática).

### Capa 5 — Herramientas del Staff y escalera de sanciones
- En la ficha del usuario, el Staff ve: IP actual e
  historial, huella de dispositivo, **«otras cuentas desde
  este dispositivo»** (las cuentas hermanas delatan al
  evasor) y su historial de sanciones e infracciones.
- Escalera clara: advertencia → silencio → baneo de sala →
  baneo de plataforma → **destierro** (dispositivo + IP).
- **Protocolo de amenazas graves:** si alguien amenaza la
  integridad física de otra persona, el Staff puede
  exportar la evidencia completa (mensajes, IP, fechas) en
  un archivo, para que la víctima pueda denunciar ante la
  policía. Proteger a la persona va primero; la plataforma
  guarda las pruebas.

## 4. Fases de implementación

- **Fase S1 — Destierro básico (la prioridad):** huella de
  dispositivo al entrar, tabla de destierros, pantalla de
  acceso revocado, botón «Desterrar» para Staff/dueño con
  motivo y auditoría, baneo por IP y por huella efectivos
  al instante. Con esto, cambiar la IP deja de funcionar.
- **Fase S2 — Anti-evasión:** cuentas hermanas visibles en
  la ficha, límite de invitados por dispositivo/IP, lista
  de correos desechables, blindaje anti-suplantación de
  nicks (incluidas imitaciones visuales).
- **Fase S3 — Anti-doxxing:** detector de datos personales
  en salas con aviso y registro, reportes con evidencia
  automática y exportación de evidencia para amenazas
  graves.

Costo: **US$0** — todo se construye sobre lo que ya
existe (la huella usa funciones del propio navegador; el
resto es base de datos y reglas del servidor como las de
la moderación actual).

## 5. Límites honestos

- Ningún sistema es 100 % impenetrable: un atacante
  técnico con equipo nuevo, VPN y paciencia puede volver.
  El objetivo real — y alcanzable — es que **volver le
  cueste caro** (equipo, tiempo y esfuerzo), mientras que
  para la comunidad sana todo sigue fácil. Así es como las
  plataformas serias ganan esta guerra: por desgaste.
- La huella de dispositivo es un dato técnico sensible:
  se guarda con las mismas reglas que la IP (solo Staff,
  nunca visible a usuarios) y se menciona en el aviso de
  privacidad de la bienvenida.
- El destierro es poder fuerte: queda auditado y el
  permanente es exclusivo del dueño, para que nadie abuse
  de él.

## 6. Decisiones para Mario

1. **¿Partimos con la Fase S1 ya?** Mi recomendación: sí —
   es la prioridad que marcaste y cierra la puerta
   principal (cambiar la IP) desde el alfa.
2. **Duraciones del destierro del Staff:** propongo
   temporal de 24 h / 7 días / 30 días para el Staff y
   permanente solo tú. ¿De acuerdo?
3. **Límite de invitados por dispositivo/día:** propongo
   3. ¿Lo dejamos así?
4. **Detector de datos personales:** ¿el mensaje se frena
   siempre (mi recomendación) o solo se marca para
   revisión del Staff cuando es ambiguo? Propongo: freno
   directo para teléfonos/correos/documentos claros, y
   aviso al Staff en los casos dudosos.

Con tu aprobación, la Fase S1 parte de inmediato y se
verifica igual que todo: con cuentas reales de prueba,
intentando evadir el destierro como lo haría un tóxico.
