# Arreglos durante el acceso anticipado

## 2026-11-24 — Privados invisibles y Status sin detalle

Reporte de Mario probando en vivo con otra persona:

1. **Los privados nuevos no aparecían en la pestaña Privados**
   del receptor (ni la conversación ni la invitación a jugar).
   La única forma de entrar era tocar el nick del remitente y
   elegir «Privado». Causa: la lista de conversaciones cargaba
   una sola vez al abrir la app y la pila de pestañas la
   mantenía viva sin recargar; los datos siempre estuvieron
   en la base (verificado por API del lado del receptor).
   Arreglo: la lista se recarga al volver a la pestaña y se
   suscribe en tiempo real a los privados entrantes.

2. **Status mostraba avisos genéricos** («Nuevo mensaje
   privado», «Aviso del sistema») y tocarlos no hacía nada.
   Causa: los payloads de las notificaciones no traían quién
   ni dónde. Arreglo:
   - Los avisos de privado, mención, susurro y juego ahora
     llevan `from_uid`, `from_nickname` y `room_name` cuando
     aplica (migración v1.13 para el aviso de juego).
   - Status muestra el detalle: «X te envió un mensaje
     privado», «X te mencionó en Sala», «X te invitó a jugar
     al Gato», con icono propio por tipo.
   - Tocar un aviso navega a la actividad: el privado (o la
     conversación del juego) o la sala de la mención/susurro.
   - Los avisos anteriores a este arreglo conservan la
     etiqueta genérica (su payload no trae el detalle).

## 2026-11-24 — Avisos que no llegaban y mensajes duplicados

Segunda ronda de reportes de Mario en vivo:

1. **Las alertas no aparecían hasta entrar a una pestaña**:
   los contadores de Privados y Status solo se recalculaban
   al cambiar de pestaña; nada escuchaba en vivo. Arreglo:
   la pantalla principal se suscribe en tiempo real a las
   notificaciones propias y a los privados entrantes, y los
   contadores se actualizan solos estando en cualquier
   pestaña (si estás dentro de Status, su lista también se
   refresca). Las tablas ya estaban en la publicación de
   tiempo real; faltaba la suscripción del cliente.

2. **El emisor veía sus mensajes duplicados** (el receptor
   no; pasaba «cada dos mensajes»): carrera entre el eco en
   tiempo real y la respuesta del envío. El mensaje optimista
   se reemplazaba por la fila real sin notar que el eco ya la
   había agregado. Arreglo en los tres caminos de envío
   (sala, susurro y privado): al completar, si la fila real
   ya está en la lista se retira el temporal en vez de
   reemplazarlo; y los receptores de eco re-verifican el id
   tras cualquier espera antes de agregar.
