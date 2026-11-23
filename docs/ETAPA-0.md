# Etapa 0 — Fundación

Inicio: 2026-11-22 · Aprobada por el propietario.

## Objetivo

Dejar la base real del proyecto: repositorio ordenado, proyecto Flutter que compila, decisiones de arquitectura escritas, esquema de datos v0 y la primera pantalla de acceso con el tema oficial. Sin cuentas pagadas ni publicaciones.

## Checklist

- [x] Documento maestro archivado en el repositorio
- [x] Arquitectura v0 y stack decididos y documentados
- [x] Esquema de base de datos v0 (`supabase/schema.sql`)
- [x] Proyecto Flutter creado y compilando (web) — verificado 2026-11-22: análisis sin problemas, prueba de interfaz aprobada, compilación web de producción OK
- [x] Pantalla de acceso (Welcome) con tema ONEchat: nickname + CHATEAR DIRECTAMENTE, Crear cuenta, Iniciar sesión (solo interfaz en esta etapa)
- [x] Repositorio Git inicializado con primer commit
- [x] Cuentas del propietario: GitHub `onechat-support` (correo onechat.support@gmail.com, verificada 2026-11-23) y Supabase con ese GitHub, organización «ONEchat» plan Free
- [x] Proyecto Supabase «onechat» creado (región East US / us-east-1, https://jsdyoqmgdkqlkucebjmt.supabase.co) y esquema v0 aplicado sin errores: 16 tablas verificadas en el Table Editor. Clave pública guardada en `app/lib/config.dart`; la clave secreta no fue abierta ni registrada

## Fuera de alcance en esta etapa

- Chat funcional, login real y cualquier función del MVP (eso es Etapa 1).
- Gastos de cualquier tipo.
- Publicación en tiendas.
