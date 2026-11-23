# ONEchat

Aplicación social de chat basada en salas permanentes, conversación espontánea y descubrimiento de comunidades y personas. Recupera la experiencia de las salas clásicas (MSN, IRC, LatinChat) con una experiencia moderna, segura, multiplataforma e internacional.

**Propietario:** Mario Valdes
**Agente de desarrollo:** Muse
**Estado:** Etapa 0 — Fundación (iniciada el 2026-11-22)

## Documentos

- `ONEchat-documento-maestro-v1.md` — Documento maestro de producto (visión y requisitos). Es la referencia de *qué* debe ser ONEchat.
- `docs/ARQUITECTURA.md` — Decisiones técnicas: stack, arquitectura, modelo de datos y seguridad.
- `docs/ETAPA-0.md` — Alcance y checklist de la etapa de fundación.

## Stack decidido (2026-11-22)

- **Cliente:** Flutter (código, sin editor visual), una sola base para Android, iOS y web.
- **Backend:** Supabase (PostgreSQL, Auth, Realtime/Presence, Storage, Edge Functions). Código abierto y autoalojable: el proyecto no queda atrapado en un proveedor.
- **Repositorio:** Git, propiedad del propietario desde el primer día.

## Principios no negociables

1. La privacidad se verifica en el servidor (reglas de base de datos y funciones), nunca solo en la interfaz.
2. Los nicknames registrados son únicos sin distinguir mayúsculas, con reserva atómica en backend.
3. Ningún gasto, publicación ni cambio de alcance sin aprobación expresa del propietario.
4. Ningún módulo se declara terminado por tener solo pantalla: debe funcionar y estar probado.
5. Secretos y claves solo en backend / variables de entorno, jamás en el código del cliente.

## Estructura

```
app/         Código Flutter (Android, iOS, web)
supabase/    Esquema de base de datos, políticas de seguridad (RLS) y funciones
docs/        Arquitectura y bitácora de etapas
```
