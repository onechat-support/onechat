# Bot de Seguridad Infantil de ONEchat — Diseño y viabilidad

> **Documento de diseño v1.0 — VALIDADO por el propietario el
> 25 de noviembre de 2026.** La fase B1 está construida y en vivo
> (ver `SEGURIDAD-INFANTIL-B1.md`). Complementa la Parte C (Estándares
> de Seguridad Infantil) del borrador de Términos y Normas.

## 1. Veredicto de viabilidad

**Viable, con costo US$0, sobre la infraestructura actual.** Los mensajes
de ONEchat (salas, privados y susurros) pasan por nuestro servidor
(Supabase) sin cifrado de extremo a extremo, por lo que un analizador del
lado del servidor puede evaluar cada mensaje al momento de enviarse, sin
que ningún usuario lo note. El bot se apoya en piezas que ya existen: el
registro de conexiones, el centro de reportes con evidencia del servidor,
las notificaciones de Status y el Destierro.

**Límites honestos (lo que el bot NO puede hacer):**

- No entiende intenciones: detecta **señales** (palabras, frases y
  combinaciones). Habrá falsos positivos y falsos negativos; por eso las
  decisiones graves siempre las confirma un humano.
- No ve imágenes (fotos de perfil o Galería): su ámbito es texto. El
  material visual se controla por reporte y revisión del Staff.
- No ve nada fuera de ONEchat: si una conversación se traslada a otra
  app, solo podemos detectar el intento de traslado (que ya es una
  señal) y actuar dentro de la plataforma.
- El lenguaje en clave y las faltas deliberadas reducen la detección;
  las listas se mantienen vivas y el Staff puede agregar patrones.

## 2. Principios de operación

1. **Discreción total.** El bot no tiene nickname público, no escribe a
   los usuarios investigados y no revela qué señal disparó una alerta.
   Solo el dueño global y el Staff ven sus avisos.
2. **Protección primero.** Ante una señal crítica de menor en peligro,
   el bot actúa de inmediato (congela la conversación) aunque no haya
   ningún administrador conectado; la revisión humana llega después.
3. **Proporcionalidad.** Las señales leves solo se registran; nadie es
   sancionado por una sola palabra suelta sin contexto.
4. **El humano decide las sanciones.** El bot congela y alerta; el
   Destierro, los baneos y las denuncias los decide el Staff o el dueño
   con la evidencia en la mano.
5. **Evidencia íntegra.** Cada alerta guarda el contexto (mensajes
   previos de la conversación) tal como lo ve el servidor, sin edición
   posible, igual que el centro de reportes.
6. **Sin acusaciones públicas.** Si el bot interviene en una
   conversación, el mensaje visible es genérico («conversación pausada
   por el sistema de seguridad»), nunca una acusación.

## 3. Arquitectura

- **Dónde corre:** función del servidor que se ejecuta al insertarse
  cada mensaje (salas, privados y susurros), antes de que el mensaje se
  distribuya en tiempo real cuando el nivel de riesgo lo exige.
- **Motor:** reglas por categorías con puntaje (sección 4) + memoria de
  conversación: el puntaje se acumula por conversación y por usuario en
  ventanas de tiempo (una frase aislada no es lo mismo que un patrón).
- **Salidas:** tabla interna `safety_alerts` (solo Staff/dueño, con
  RLS), notificación en Status sección «Seguridad», acción de
  congelamiento (bloqueo de envío mutuo en esa conversación) y registro
  en la auditoría de moderación.
- **Sala Hot +18:** el bot vigila en ella solo las señales de menores
  (categorías A, B y las combinaciones críticas); el contenido sexual
  entre adultos en esa sala no puntúa.

## 4. Categorías de señales y listas de detección

Las listas están en español e inglés (la comunidad es bilingüe) y se
guardan como configuración editable por el dueño. Se detectan variantes
con errores comunes, abreviaturas y leetspeak básico (p. ej. «f0to»).

### A. Declaración de minoría de edad — CRÍTICA (puntaje máximo)

«tengo 13 / 14 / 15 / 16 / 17», «cumplo 15», «soy menor de edad», «aún
no tengo 18», «estoy en el colegio / la escuela / la secundaria»,
«salgo del liceo», «mi mamá / mis papás no saben que estoy aquí»,
«i'm 14 / 15 / 16», «i'm underage», «i'm still in school / high school».

### B. Sondeo de edad (el otro pregunta o presiona)

«¿cuántos años tienes?», «¿qué edad tienes?», «¿ya eres mayor?»,
«¿seguro que tienes 18?», «te ves menor», «pareces de 15», «¿en qué
curso vas?», «how old are you», «are you 18?», «you look younger».

### C. Sexualización y petición de material

«mándame / pásame una foto tuya», «foto sin ropa», «foto en ropa
interior», «mándame tu pack», «nudes», «enséñame tu cuerpo», términos
sexuales explícitos dirigidos al interlocutor fuera de la sala +18,
«send me a pic», «send nudes», «show me your body».

### D. Secreto y aislamiento (grooming clásico)

«que sea nuestro secreto», «no le digas a nadie», «esto queda entre
nosotros», «borra los mensajes / esta conversación», «tus papás no
tienen que saber», «si se enteran me matan», «don't tell anyone»,
«delete this chat», «our secret».

### E. Regalos, dinero y favores

«te recargo el celular», «te compro lo que quieras», «te doy dinero»,
«tarjeta de regalo», «te pago por…», «te regalo un celular», «i'll buy
you…», «gift card», «i'll pay you for…».

### F. Traslado fuera de la plataforma

«pásame tu WhatsApp / Instagram / Telegram / Snapchat / TikTok»,
«hablemos por otro lado», «mejor por Whats», «aquí nos vigilan»,
«add me on snap / insta», «let's talk somewhere else».

### G. Encuentro en persona y ubicación

«¿dónde vives?», «¿en qué escuela / colegio estudias?», «nos vemos a
la salida», «paso por ti», «te recojo», «ven a mi casa, no hay nadie»,
«where do you live», «what school do you go to», «i'll pick you up».

### H. Petición de datos personales

«tu dirección», «tu número de teléfono», «foto de tu casa / de tu
uniforme», «¿con quién vives?», «¿a qué hora estás sola/o?», «your
address», «your phone number», «are you home alone?».

### Reglas de combinación (ejemplos)

- **A sola** → Nivel 3 inmediato.
- **B + C**, **C + D**, **C + F**, **E + C**, **G + D** en la misma
  conversación → Nivel 3.
- **C, D, E, F, G o H** repetidas (2+ categorías distintas o 3+
  coincidencias en 24 h) → Nivel 2.
- Una coincidencia aislada de C–H → Nivel 1.

## 5. Niveles de respuesta

| Nivel | Cuándo | Qué hace el bot | Quién lo ve |
|---|---|---|---|
| 1 · Registro | Señal leve aislada | Guarda la señal con contexto; suma puntaje | Nadie en el momento; visible en el panel de Seguridad |
| 2 · Alerta | Patrón sospechoso | Alerta inmediata en Status «Seguridad» con extracto y puntaje; marca la conversación «en observación» | Dueño global y Staff |
| 3 · Protección | Menor declarado o combinación crítica | **Congela la conversación al instante** (ninguno de los dos puede seguir escribiendo ahí), alerta prioritaria al dueño y al Staff, conserva la evidencia completa; si nadie del equipo revisa en 30 minutos, el congelamiento se mantiene y se re-alerta | Dueño global y Staff |

- El congelamiento muestra a ambos usuarios solo: «Esta conversación
  fue pausada por el sistema de seguridad de ONEchat.»
- Un humano revisa cada Nivel 3 y decide: liberar (falso positivo),
  mantener bloqueado, aplicar Destierro y, si hay indicios de delito
  contra un menor, **denunciar al NCMEC o a la autoridad competente**
  con la evidencia preservada (Parte C de los Términos).
- Los falsos positivos liberados quedan anotados para afinar las listas
  y no volver a molestar a esos usuarios por la misma señal.

## 6. Aviso general de seguridad (mensaje del sistema en rojo)

El bot publicará periódicamente en las salas públicas (frecuencia
configurable; propuesta: cada 6 horas en General y al abrir las salas
temáticas) este aviso del sistema, en rojo:

> **⚠ AVISO DE SEGURIDAD — ONEchat es solo para mayores de 18 años.**
> **Están estrictamente prohibidos: las temáticas sexuales que
> involucren o busquen a menores de edad y la participación de menores
> en la plataforma; divulgar datos personales, propios o ajenos; y la
> venta o el intercambio de material digital de carácter sexual.**
> **Quien infrinja estas reglas será bloqueado y desterrado de forma
> permanente, y los casos que involucren a menores se denunciarán a
> las autoridades.**

## 7. Panel del Staff y flujo de trabajo

- Nueva sección **«Seguridad»** en Status (solo dueño global y Staff):
  cola de alertas por nivel, con conversación, señales detectadas,
  puntaje y botones: *Ver evidencia · Liberar · Mantener congelado ·
  Desterrar (con el flujo actual) · Marcar denunciado*.
- Contadores semanales para el dueño: alertas por nivel, falsos
  positivos, congelamientos y denuncias realizadas.
- Mantenimiento de listas: el dueño puede agregar o quitar palabras y
  frases desde la base de datos (fase B4: desde el propio panel).

## 8. Privacidad y encaje legal

- El análisis es automático y sobre texto que ya transita por el
  servidor para prestar el servicio; la Política de Privacidad
  (borrador, Parte D) debe mencionar la moderación automática de
  seguridad al publicarse.
- Las alertas y evidencias se conservan el tiempo necesario para
  moderación y obligaciones legales, con acceso restringido por RLS al
  dueño global y al Staff.
- El diseño cumple el mecanismo interno que exigen los Estándares de
  Seguridad Infantil de Google Play (detección, actuación y denuncia).

## 9. Fases de implementación (cuando se apruebe)

- **B1** Motor de reglas + registro silencioso (Nivel 1) y alertas
  Nivel 2 en Status. Sin acciones automáticas: primero medimos.
- **B2** Congelamiento automático Nivel 3 + alerta prioritaria.
- **B3** Aviso general rojo programado en salas públicas.
- **B4** Panel «Seguridad» completo y editor de listas para el dueño.

Costo total: US$0 (infraestructura actual). Cada fase se verifica con
cuentas de prueba «Zeth» antes de publicarse, como siempre.

## 10. Decisiones del propietario (validadas el 25-11-2026)

1. **Umbrales:** los del diseño. Las combinaciones mandan; una palabra
   sola solo registra (Nivel 1).
2. **Congelamiento automático desde B1, pero solo en casos
   inequívocos:** señal A (posible menor) en cualquier contexto, y
   combinación C+D (pedido de fotos + secreto) en conversaciones 1:1.
   Las demás combinaciones críticas (B+C, C+F, E+C) son Nivel 3 de
   **solo alerta** durante un periodo de medición de 1–2 semanas;
   ampliar el congelamiento será la fase B2, con datos reales.
3. **Aviso rojo** (fase B3): cada 6 horas en General y Encuentros, y al
   entrar a Hot.
4. **Alertas:** dueño + Staff. La evidencia de abuso de poder sigue
   siendo visible solo para el dueño.
5. **Evidencia de Nivel 3:** se conserva 12 meses y luego se borra
   automáticamente, salvo que haya sido reportada a las autoridades.
