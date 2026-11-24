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
