# Bot de Seguridad Infantil — Fase B1 en vivo (2026-11-25)

Migración **v1.18** aplicada en Supabase y app **v2026.11.25.5**.
Diseño y decisiones: `PLAN-BOT-SEGURIDAD-INFANTIL.md` (v1.0 validada).

## Qué quedó activo

- **Motor de reglas en el servidor** (función `safety_analyze`, disparada
  al insertar en `room_messages`, `direct_messages` y `whispers`).
  Normaliza el texto (minúsculas, sin tildes) y lo compara con
  **103 patrones activos** en `safety_patterns` (categorías A–H,
  español e inglés, editables por SQL).
- **Señales** (`safety_signals`): una por categoría y mensaje, con
  extracto de evidencia. Ventana de puntuación: 24 h por contexto
  (sala+usuario, conversación, par de susurros).
- **Niveles:** 1 = registro silencioso · 2 = aviso al Staff en Status ·
  3 = aviso prioritario, con **congelamiento automático solo en los
  casos validados**: señal A en cualquier contexto (congelamiento del
  usuario completo) y combinación C+D en 1:1 (congelamiento de la
  pareja). B+C, C+F y E+C llegan como Nivel 3 **sin** congelar
  (periodo de medición de 1–2 semanas → fase B2).
- **Guarda anti-falsos-positivos** para la señal A de edad: contextos
  como «tengo 16 años de experiencia» no cuentan como declaración de
  menor.
- **Congelamientos** (`safety_holds`: usuario / pareja / sala) aplicados
  en las políticas de inserción de los tres canales. Las funciones de
  consulta son *security definer* (imprescindible: la RLS de la tabla
  solo deja verla al Staff, y el chequeo debe funcionar también para el
  usuario evaluado — bug cazado y corregido durante la verificación).
- **Avisos en Status** (notificaciones tipo `safety`, solo dueño y
  Staff): «Seguridad N{nivel}: actividad sospechosa de {nick} en
  {sala} / en un privado». Sin navegación en B1 (el panel llega en B4).
- **Revisión humana:** RPC `safety_review(alert_id, release|keep|
  reported, nota)` — solo Staff/dueño; `release` levanta los
  congelamientos de la alerta.
- **RLS:** las cuatro tablas de seguridad solo son legibles por
  Staff/dueño. Los usuarios normales no ven nada.

## Verificación (cuentas Zeth*, datos eliminados después)

- Batería 1 (25 controles): 22 PASS iniciales; los 3 fallos eran el
  mismo bug (las consultas de congelamiento sin *security definer* no
  veían los holds del propio usuario evaluado y este podía seguir
  escribiendo; el otro miembro de la pareja sí quedaba bloqueado).
- Parche aplicado (funciones recreadas como *security definer*) y
  batería 2: **10/10 PASS** — el emisor de C+D queda congelado, el
  receptor también, la liberación restaura la escritura, la señal A en
  sala congela al propio usuario en salas y privados, un usuario sano
  escribe sin problema, la guarda de «años de experiencia» no dispara,
  y un usuario normal no ve alertas ni recibe avisos.
- Limpieza verificada: 0 alertas / 0 señales / 0 holds / 0
  notificaciones de prueba; ZethRegistro restaurado a rol `user`;
  quedan los 103 patrones activos.

## Pendiente (fases siguientes, cuando el propietario lo indique)

- **B2:** ampliar el congelamiento automático a B+C, C+F y E+C según
  los datos del periodo de medición.
- **B3:** aviso rojo periódico (cada 6 h en General y Encuentros; al
  entrar a Hot).
- **B4:** panel «Seguridad» en Status con revisión en la app y editor
  de patrones para el dueño; mensaje amable de «conversación pausada»
  en la app al intentar escribir en un contexto congelado (en B1 el
  envío simplemente no se completa).
- Borrado automático de evidencia Nivel 3 a los 12 meses (decisión 5).
