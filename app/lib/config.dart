/// Configuración pública del cliente ONEchat.
///
/// Estos dos valores son PÚBLICOS por diseño: la URL del proyecto y la
/// clave "publishable" de Supabase están hechas para vivir en las apps
/// cliente. La seguridad no depende de ocultarlos: la imponen las
/// políticas RLS de la base de datos y las funciones de servidor.
/// La clave secreta (service_role) jamás va en el cliente.
class AppConfig {
  /// Sello visible de la versión (Perfil): sirve para confirmar
  /// qué tan fresca es la copia que el navegador está ejecutando.
  static const appVersion = '2026.11.26.15';

  /// Sitio oficial (lugar web definitivo): portada, Comunidad
  /// y páginas personales con Galería en `/u/<nickname>`.
  static const siteBaseUrl = 'https://getonechat.com';

  static const supabaseUrl = 'https://jsdyoqmgdkqlkucebjmt.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_FE28e094cucvLYdDFlnxKQ_dxlKjXO-';
}
