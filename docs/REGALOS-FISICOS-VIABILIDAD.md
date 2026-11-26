# Regalos físicos entre usuarios — idea de Mario (2026-11-26) y verificación de viabilidad

**Estado: SOLO IDEA EVALUADA. No construir sin orden expresa de Mario.**

## La idea (tal como la imaginó Mario)

1. Un usuario toca «Enviar regalo» y se despliega un catálogo
   (ramo de flores, caja de chocolates, etc.).
2. Elige el regalo y toca «Enviar solicitud de regalo». NO paga aún.
3. La destinataria recibe el aviso: «X usuario te tiene una
   sorpresa preparada, ¿quieres recibirla?». Puede aceptar o no.
4. Si acepta, le aparece una tarjeta segura para ingresar nombre,
   dirección y teléfono, con el aviso de que sus datos solo los usa
   la tienda que despacha, luego se eliminan del sistema y quien
   envía NUNCA ve sus datos personales.
5. Al remitente le llega: «aceptó tu regalo, todo listo para el
   despacho, solo falta el pago» → pasarela de pago → paga.
6. El sistema compra en la tienda, la tienda despacha, ambos ven el
   estado (preparando → en camino → entregado) y el servicio queda
   completado. El remitente jamás conoce la dirección.

## Veredicto: VIABLE

El flujo imaginado es, además, el orden correcto: cobrar DESPUÉS de
la aceptación evita cobrar regalos rechazados (el error típico de
estos servicios). Todas las piezas existen hoy:

### ¿Quién despacha? (verificado 2026-11-26)

Las flores no cruzan fronteras: los servicios internacionales
reciben la orden y la ejecuta un FLORISTA LOCAL del país de la
destinataria, que arma un ramo equivalente y lo entrega en 24–72 h
(mismo día en capitales). Operadores reales con cobertura que
calza con las salas de ONEchat:

- **FloraQueen** (100+ países): incluye Chile, Argentina, Bolivia,
  Colombia, Ecuador, México, Panamá, Perú, Uruguay, EE. UU.,
  Canadá y España. Ramos US$70–180; extras: chocolates, vino,
  peluches. Pide exactamente nombre, dirección y teléfono.
- **GiftBasketsOverseas** (200 países): canastas, chocolates,
  flores; ticket promedio US$170; programa de afiliados (Awin)
  10–15 % de comisión y ELLOS hacen todo el despacho y soporte.
- **Wineflowers** (120+ países): programa de afiliados y convenios
  corporativos con equipo dedicado.
- **Interflora**: red de 58.000 floristas en 150+ países.

### Dos modelos posibles

- **A. Revendedor (el que calza con la idea):** el remitente paga a
  ONEchat (Stripe); ONEchat coloca la orden en el operador con los
  datos de la tarjeta segura. La experiencia completa queda dentro
  de la app y la privacidad se cumple al 100 %. Margen = sobreprecio
  del catálogo. Exige: cuenta Stripe de la empresa (la SpA u otra
  entidad), política de reembolsos y soporte de pedidos. Fase 1
  puede colocar las órdenes de forma SEMI-MANUAL (panel interno),
  sin API: viable desde el primer día con volumen bajo.
- **B. Afiliado (cero operación):** ONEchat deriva la compra al
  operador y gana 10–15 % (~US$17–25 por orden típica). PERO rompe
  la idea: la destinataria saldría de la app a ingresar sus datos en
  el sitio del operador y se pierde el flujo sorpresa/aceptación.

**Recomendado: modelo A, fase 1 semi-manual, un solo operador.**

### Pagos

Stripe: cobro solo tras aceptación (PaymentIntent confirmado en ese
momento). Comisión 2,9 % + US$0,30. 3D Secure obligatorio para
frenar tarjetas robadas (contracargos) + monto máximo para cuentas
nuevas. Si el despacho falla: reembolso total al remitente (regla
simple y publicable).

### Privacidad (el corazón de la función)

- Dirección cifrada en la base, visible SOLO para el rol de
  despacho al momento de colocar la orden; acceso auditado.
- Borrado automático 30 días después de la entrega.
- El remitente ve solo estados, nunca ciudad ni dirección.
- Actualizar la Política de Privacidad del paquete legal con esta
  sección antes de lanzar (el borrador ya contempla datos de
  terceros; se agrega el tratamiento de direcciones de regalo).

### Seguridad anti-acoso (reglas propuestas)

- Solo se puede enviar a quien tenga conversación mutua o sea
  favorito del remitente; bloqueados, jamás.
- La destinataria puede DESACTIVAR recibir regalos (ajuste, junto a
  los de privados/susurros del Lote A).
- Rechazo silencioso: el remitente solo ve «no fue aceptada», sin
  insistencia posible (enfriamiento por pareja) y máx. 1 solicitud
  pendiente por pareja.
- Centinel/Staff: las solicitudes quedan registradas; abuso del
  sistema = infracción normal.

### Economía (ejemplo con números reales del sector)

Ramo en catálogo a US$89 todo incluido → costo operador ~US$70 →
Stripe ~US$2,88 → margen bruto ~US$16 por regalo, sin inventario ni
logística propia. El catálogo debe avisar «foto referencial: el
florista local prepara un ramo equivalente con flores de estación»
(es la práctica declarada de todo el sector).

### Riesgos honestos

- Calidad variable del florista local (fotos referenciales y
  garantía de reposición/reembolso del operador lo mitigan).
- Entregas fallidas: casi siempre por dirección incompleta → el
  teléfono es OBLIGATORIO en la tarjeta segura (el florista llama).
- Fechas pico (San Valentín, Día de la Madre — que cae distinto por
  país): plazos más largos; avisar en el catálogo.
- Requiere la empresa constituida para Stripe y para responder
  como vendedor; sin empresa, solo cabe el modelo B.

## Fases si Mario lo aprueba

- **R1:** catálogo fijo (10–15 regalos), flujo completo en la app,
  1 operador, órdenes semi-manuales, cobertura = países del
  operador. Premium: envío prioritario o descuento en la tarifa.
- **R2:** automatizar la orden (convenio/API), segundo operador
  para comparar precios por país, recordatorios de cumpleaños.
- **R3:** floristas locales asociadas directas en los países con
  más volumen (mejor margen y control de calidad).
