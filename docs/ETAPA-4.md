# ONEchat — Etapa 4: Temas y personalización

Completada el 2026-11-23. Sobre la Etapa 3 y las Salas v2.

## Qué incluye
- **Tema de la app**: selector en Perfil — Sistema / Oscuro /
  Claro — guardado en la cuenta (`profiles.theme_mode`, con
  validación en la base: un valor inválido se rechaza) y aplicado
  en vivo a toda la app sin reiniciar. Al entrar se aplica el
  tema guardado; la pantalla de bienvenida siempre va en oscuro
  (la cara de la marca) y al cerrar sesión se vuelve a oscuro.
  Antes la app seguía el tema del sistema sin hacer caso al
  perfil; los dos temas oficiales (claro y oscuro, §9 del
  Documento Maestro) ya existían desde la Etapa 0.
- **Tu país**: selector en Perfil con los países de las salas
  regionales (+ España y Otro), guardado en `profiles.country`;
  acompaña el enfoque regional de las Salas v2.
- La personalización que ya existía se mantiene: color de
  nickname (paleta de 8) y bio editable (160 caracteres).

## Verificación
- API con sesión real: guardar tema oscuro y país, leerlos de
  vuelta, rechazo de un tema inválido (400) y restauración.
- Análisis sin problemas y prueba de widgets aprobada;
  publicación verificada por hash.
