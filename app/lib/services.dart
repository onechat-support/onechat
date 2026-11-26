import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'device_identity.dart';
import 'strings.dart';

/// Traduce los errores de autenticación a lenguaje claro para el
/// usuario (nunca se muestra el texto técnico crudo).
String friendlyAuthError(Object e) {
  final msg = e.toString();
  if (msg.contains('over_email_send_rate_limit') ||
      msg.contains('email rate limit')) {
    return t('auth.errRateLimit');
  }
  if (msg.contains('user_already_exists') ||
      msg.contains('already registered') ||
      msg.contains('already exists')) {
    return t('auth.errAlreadyExists');
  }
  if (msg.contains('email_not_confirmed') || msg.contains('not confirmed')) {
    return t('auth.errNotConfirmed');
  }
  if (msg.contains('invalid_credentials') ||
      msg.contains('Invalid login credentials')) {
    return t('auth.errInvalidCredentials');
  }
  if (msg.contains('weak_password') || msg.contains('Password should')) {
    return t('auth.errWeakPassword');
  }
  if (msg.contains('invalid_email') || msg.contains('Unable to validate email')) {
    return t('auth.errInvalidEmail');
  }
  return t('auth.errGeneric');
}

/// Columnas legibles de un perfil: todas menos `email`. Desde la
/// auditoría de seguridad del 2026-11-25 (migración v1.20) la API
/// no concede lectura de la columna email a nadie; pedir el perfil
/// con * falla entero, así que las lecturas de perfil usan esta
/// lista explícita.
const profileColumns =
    'uid,nickname,nickname_lower,nickname_color,bio,photo_url,'
    'is_guest,global_role,language,country,gender,birth_year,'
    'theme_mode,profile_views,created_at,last_seen_at,'
    'show_in_directory,is_premium,conduct_accepted_at,'
    'dm_open,whispers_open,show_system_notices,'
    'sound_enabled,vibrate_enabled';

/// Capa de acceso a Supabase para ONEchat (Etapa 1, MVP).
/// Toda la seguridad real la impone la base de datos con RLS;
/// esta clase solo orquesta llamadas.
class OnechatService {
  SupabaseClient get _db => Supabase.instance.client;

  User? get currentUser => _db.auth.currentUser;
  String? get myUid => currentUser?.id;
  bool get isSignedIn => currentUser != null;

  // ---------- Acceso ----------

  static final _nickRe = RegExp(r'^[A-Za-z0-9_]{3,20}$');

  static String? validateNickname(String nick) {
    if (!_nickRe.hasMatch(nick)) {
      return t('svc.nicknameRules');
    }
    return null;
  }

  Future<Map<String, dynamic>> _createProfile({
    required String uid,
    required String nickname,
    required bool isGuest,
    String? email,
  }) async {
    final row = await _db
        .from('profiles')
        .insert({
          'uid': uid,
          'nickname': nickname,
          'nickname_lower': nickname.toLowerCase(),
          'email': email,
          'is_guest': isGuest,
          'language': appLanguage.value,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select(profileColumns)
        .single();
    if (!isGuest) {
      await _db.from('nickname_reservations').insert({
        'nickname_lower': nickname.toLowerCase(),
        'uid': uid,
      });
    }
    return row;
  }

  static bool _isNicknameTaken(Object e) =>
      e is PostgrestException && e.code == '23505';

  /// Entrada como invitado: sesión anónima + perfil con nickname único.
  /// Si el nickname lo dejó un invitado inactivo (>15 min), se reclama.
  Future<Map<String, dynamic>> enterAsGuest(String nickname) async {
    final res = await _db.auth.signInAnonymously();
    final user = res.user;
    if (user == null) throw Exception(t('svc.couldNotCreateGuest'));
    try {
      return await _createProfile(uid: user.id, nickname: nickname, isGuest: true);
    } catch (e) {
      if (_isNicknameTaken(e)) {
        final claimed = await _db.rpc('claim_guest_nickname',
            params: {'p_nickname': nickname}) as bool;
        if (claimed) {
          return await _createProfile(
              uid: user.id, nickname: nickname, isGuest: true);
        }
        await _db.auth.signOut();
        throw Exception(t('auth.nicknameTaken'));
      }
      await _db.auth.signOut();
      rethrow;
    }
  }

  /// Registro con correo (con confirmación activa): el nickname viaja
  /// en los datos de la cuenta y se reserva al primer inicio de sesión,
  /// DESPUÉS de confirmar el correo. Una cuenta con el correo mal
  /// escrito nunca llega a reservar nada: el nickname no se quema.
  /// Devuelve null si falta confirmar el correo.
  Future<Map<String, dynamic>?> signUp({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {'nickname': nickname},
    );
    final user = res.user;
    if (user == null) throw Exception(t('svc.couldNotCreateAccount'));
    if (res.session == null) return null; // falta confirmar el correo
    try {
      return await _createProfile(
          uid: user.id, nickname: nickname, isGuest: false, email: email);
    } catch (e) {
      if (_isNicknameTaken(e)) {
        throw Exception(t('svc.nicknameInUse'));
      }
      rethrow;
    }
  }

  /// Inicio de sesión. Devuelve el perfil o null si aún no tiene nickname.
  Future<Map<String, dynamic>?> signIn({
    required String email,
    required String password,
  }) async {
    await _db.auth.signInWithPassword(email: email, password: password);
    return fetchMyProfile();
  }

  /// Reenvía el correo de confirmación de registro.
  Future<void> resendConfirmation(String email) =>
      _db.auth.resend(type: OtpType.signup, email: email);

  /// Envía el correo para restablecer la contraseña.
  Future<void> recoverPassword(String email) => _db.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://onechat-support.github.io/onechat/',
      );

  /// Fija la contraseña nueva (con la sesión que abre el enlace de
  /// recuperación). La contraseña se envía EXACTAMENTE como se escribe,
  /// igual que en el registro: sin recortes.
  Future<void> updatePassword(String newPassword) =>
      _db.auth.updateUser(UserAttributes(password: newPassword));

  /// Estado de un nickname para el acceso unificado:
  /// 'registered' | 'guest' | 'free'. No expone ningún correo.
  Future<String> nicknameStatus(String nickname) async {
    final r =
        await _db.rpc('nickname_status', params: {'p_nickname': nickname});
    return r as String;
  }

  /// Acceso con nickname + contraseña (el correo vive solo en el
  /// registro): una función del servidor resuelve el correo sin
  /// exponerlo y devuelve la sesión.
  Future<Map<String, dynamic>?> loginWithNickname(
      String nickname, String password) async {
    try {
      final res = await _db.functions.invoke(
        'login-with-nickname',
        body: {'nickname': nickname, 'password': password},
      );
      final data = res.data;
      if (data is Map && data['session'] is Map) {
        await _db.auth.recoverSession(
            jsonEncode(Map<String, dynamic>.from(data['session'] as Map)));
        return await fetchMyProfile();
      }
      throw Exception(t('auth.errNicknameOrPassword'));
    } on FunctionException {
      throw Exception(t('auth.errNicknameOrPassword'));
    }
  }

  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final uid = myUid;
    if (uid == null) return null;
    final rows = await _db
        .from('profiles')
        .select(profileColumns)
        .eq('uid', uid)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>> completeProfile(String nickname) async {
    final user = currentUser!;
    return _createProfile(
      uid: user.id,
      nickname: nickname,
      isGuest: user.isAnonymous,
      email: user.email,
    );
  }

  /// Elimina la cuenta del usuario actual (requisito de Google
  /// Play: borrado desde la app; también existe desde la web).
  /// El servidor verifica la contraseña en las cuentas
  /// registradas y borra todo: perfil, mensajes, fotos de la
  /// Galería y el usuario de acceso. Los invitados se borran
  /// solo con su sesión.
  Future<void> deleteMyAccount({String? password}) async {
    try {
      final res = await _db.functions.invoke(
        'delete-account',
        body: {if (password != null) 'password': password},
      );
      final data = res.data;
      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw Exception(details['error'].toString());
      }
      rethrow;
    }
  }

  /// Al salir, el invitado libera su nickname borrando su perfil;
  /// las cuentas registradas conservan el suyo (está reservado).
  Future<void> signOut() async {
    final uid = myUid;
    if (uid != null) {
      final profile = await fetchMyProfile();
      if (profile != null && profile['is_guest'] == true) {
        await _db.from('profiles').delete().eq('uid', uid);
      }
    }
    await _db.auth.signOut();
  }

  Future<void> touchLastSeen() async {
    final uid = myUid;
    if (uid == null) return;
    await _db.from('profiles').update(
        {'last_seen_at': DateTime.now().toUtc().toIso8601String()}).eq('uid', uid);
  }

  /// Puerta de entrada (v1.14 + S1): la función del servidor
  /// registra la conexión (IP observada por el servidor,
  /// dispositivo declarado por la app) y verifica el
  /// Destierro. Devuelve el veredicto: {'ok': true} o
  /// {'banned': true, 'permanent': bool, 'expires_at': ...}.
  /// Si la red falla, se deja pasar (fail-open): el control
  /// se repite en cada apertura de la app.
  Future<Map<String, dynamic>> entryCheck() async {
    try {
      final id = await getDeviceIdentity();
      final res = await _db.functions.invoke('log-visit', body: {
        'device_id': id.deviceId,
        'fingerprint': id.fingerprint,
      });
      final data = res.data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return {'ok': true};
  }

  /// Mi rol global ('user' | 'staff' | 'owner').
  Future<String> myGlobalRole() async {
    final uid = myUid;
    if (uid == null) return 'user';
    try {
      final row = await _db
          .from('profiles')
          .select('global_role')
          .eq('uid', uid)
          .maybeSingle();
      return (row?['global_role'] as String?) ?? 'user';
    } catch (_) {
      return 'user';
    }
  }

  /// Aplicar el Destierro (S1): bloquea cuenta + dispositivo
  /// + IP del objetivo en una sola llamada del servidor.
  /// [hours] null = permanente (solo el dueño). Devuelve el
  /// número de capas bloqueadas; lanza si no hay permiso.
  Future<int> applyPlatformBan(
      String targetUid, int? hours, String reason) async {
    final r = await _db.rpc('apply_platform_ban', params: {
      'p_target': targetUid,
      'p_hours': hours,
      'p_reason': reason,
    });
    return (r as num).toInt();
  }

  /// Levantar una fila del Destierro. True si se levantó.
  Future<bool> liftPlatformBan(int banId) async {
    final r = await _db.rpc('lift_platform_ban', params: {'p_ban_id': banId});
    return r == true;
  }

  /// Destierros vigentes de un usuario (solo Staff/dueño:
  /// la RLS devuelve vacío a los demás).
  Future<List<Map<String, dynamic>>> activeBansFor(String uid) async {
    try {
      final rows = await _db
          .from('platform_bans')
          .select(
              'id, kind, reason, expires_at, created_at, applied_by_nickname')
          .eq('target_uid', uid)
          .isFilter('lifted_at', null)
          .order('created_at', ascending: false);
      final now = DateTime.now().toUtc();
      return rows
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((b) {
            final exp = b['expires_at'] as String?;
            if (exp == null) return true;
            final t = DateTime.tryParse(exp);
            return t != null && t.isAfter(now);
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Última conexión registrada de un usuario. La RLS de
  /// connection_log solo deja leer al Staff global y al
  /// dueño: para cualquier otro, esto devuelve null.
  Future<Map<String, dynamic>?> lastConnection(String uid) async {
    try {
      final rows = await _db
          .from('connection_log')
          .select('ip, created_at')
          .eq('uid', uid)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return Map<String, dynamic>.from(rows.first as Map);
    } catch (_) {
      return null;
    }
  }

  // ---------- Salas y chat ----------

  static const _categoryRank = {
    'general': -1,
    'plataforma': 0,
    'latino': 1,
    'norteamerica': 2,
    'europa': 3,
    'tematicos': 4,
  };

  /// Salas públicas ordenadas por sección (Plataforma, Latino,
  /// Norteamérica, Europa, Temáticos) y su orden dentro de ella.
  Future<List<Map<String, dynamic>>> fetchRooms() async {
    final rows = await _db.from('rooms').select().eq('is_public', true);
    final list = List<Map<String, dynamic>>.from(rows);
    list.sort((a, b) {
      final ra = _categoryRank[a['category']] ?? 9;
      final rb = _categoryRank[b['category']] ?? 9;
      if (ra != rb) return ra.compareTo(rb);
      return ((a['sort'] as num?) ?? 0).compareTo((b['sort'] as num?) ?? 0);
    });
    return list;
  }

  Future<void> joinRoom(String roomId) async {
    // Idempotente: si ya eres miembro, no hace nada (sin UPDATE).
    await _db.from('room_members').upsert(
      {'room_id': roomId, 'uid': myUid},
      onConflict: 'room_id,uid',
      ignoreDuplicates: true,
    );
  }

  /// Historial con el perfil del autor incluido en UNA sola consulta
  /// (antes eran dos viajes: mensajes y luego perfiles).
  /// Devuelve (mensajes, perfilesPorUid).
  Future<(List<Map<String, dynamic>>, Map<String, Map<String, dynamic>>)>
      fetchMessagesWithProfiles(String roomId, {int limit = 60}) async {
    final rows = await _db
        .from('room_messages')
        .select(
            '*, sender:profiles!room_messages_sender_uid_fkey(nickname, nickname_color)')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);
    final messages = <Map<String, dynamic>>[];
    final profiles = <String, Map<String, dynamic>>{};
    for (final raw in rows.reversed) {
      final row = Map<String, dynamic>.from(raw);
      final sender = row.remove('sender');
      final uid = row['sender_uid'] as String?;
      if (uid != null && sender is Map) {
        profiles[uid] = {'uid': uid, ...Map<String, dynamic>.from(sender)};
      }
      messages.add(row);
    }
    return (messages, profiles);
  }

  RealtimeChannel subscribeMessages(
      String roomId, void Function(Map<String, dynamic> row) onInsert) {
    final channel = _db.channel('room-messages-$roomId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'room_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }

  Future<void> unsubscribe(RealtimeChannel channel) =>
      _db.removeChannel(channel);

  /// Mi propio nickname (para firmar los avisos que genero).
  Future<String?> myNickname() async {
    final p = await profileByUid(myUid!);
    return p?['nickname'] as String?;
  }

  Future<String?> roomNameById(String roomId) async {
    final rows =
        await _db.from('rooms').select('name').eq('id', roomId).limit(1);
    return rows.isEmpty ? null : rows.first['name'] as String?;
  }

  Future<Map<String, dynamic>?> fetchRoomById(String roomId) async {
    final rows = await _db.from('rooms').select().eq('id', roomId).limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Mis notificaciones en vivo (para los contadores de la barra
  /// principal: que avise sin tener que entrar a la pestaña).
  RealtimeChannel subscribeNotifications(
      void Function(Map<String, dynamic> row) onInsert) {
    final channel = _db.channel('notif-$myUid');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'uid',
            value: myUid,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }

  /// Avisos en vivo de privados nuevos (la RLS limita la suscripción
  /// a las conversaciones donde participo).
  RealtimeChannel subscribeInbox(void Function(Map<String, dynamic> row) onInsert) {
    final channel = _db.channel('dm-inbox-$myUid');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }

  Future<Map<String, dynamic>?> profileByUid(String uid) async {
    final rows = await _db
        .from('profiles')
        .select(profileColumns)
        .eq('uid', uid)
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> profilesByUids(List<String> uids) async {
    if (uids.isEmpty) return [];
    final rows =
        await _db.from('profiles').select(profileColumns).inFilter('uid', uids);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Envía un mensaje; detecta @menciones y avisa en la Sala Status
  /// de cada mencionado (sin avisar a bloqueados ni a uno mismo).
  /// Devuelve la fila insertada (para el eco optimista en pantalla).
  Future<Map<String, dynamic>> sendMessage({
    required String roomId,
    required String body,
    required Set<String> blockedUids,
    required String senderNickname,
  }) async {
    final mentionedLowers = RegExp(r'@([A-Za-z0-9_]{3,20})')
        .allMatches(body)
        .map((m) => m.group(1)!.toLowerCase())
        .toSet();
    var mentionUids = <String>[];
    if (mentionedLowers.isNotEmpty) {
      final rows = await _db
          .from('profiles')
          .select('uid')
          .inFilter('nickname_lower', mentionedLowers.toList());
      mentionUids = rows
          .map((r) => r['uid'] as String)
          .where((u) => u != myUid && !blockedUids.contains(u))
          .toList();
    }
    final inserted = await _db
        .from('room_messages')
        .insert({
          'room_id': roomId,
          'sender_uid': myUid,
          'sender_nickname': senderNickname,
          'body': body,
          'mentions': mentionUids,
        })
        .select()
        .single();
    final myNick = await myNickname();
    final roomName = await roomNameById(roomId);
    for (final uid in mentionUids) {
      await _db.from('notifications').insert({
        'uid': uid,
        'kind': 'mention',
        'payload': {
          'room_id': roomId,
          'message_id': inserted['id'],
          'from_uid': myUid,
          'from_nickname': myNick,
          'room_name': roomName,
        },
      });
    }
    return inserted;
  }

  // ---------- Presencia ----------

  RealtimeChannel joinPresence({
    required String roomId,
    required Map<String, dynamic> me,
    required void Function(List<Map<String, dynamic>> occupants) onSync,
  }) {
    final channel = _db.channel(
      'room-presence-$roomId',
      opts: RealtimeChannelConfig(key: myUid!),
    );
    channel
        .onPresenceSync((payload) {
          final occupants = channel
              .presenceState()
              .expand((s) => s.presences)
              .map((p) => p.payload)
              .toList();
          onSync(occupants);
        })
        .subscribe((status, error) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.track(me);
          }
        });
    return channel;
  }

  // ---------- Status (notificaciones) ----------

  Future<List<Map<String, dynamic>>> fetchNotifications({int limit = 50}) async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('uid', myUid!)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<int> unreadCount() async {
    final rows = await _db
        .from('notifications')
        .select('id')
        .eq('uid', myUid!)
        .isFilter('read_at', null);
    return rows.length;
  }

  Future<void> markAllRead() async {
    await _db
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('uid', myUid!)
        .isFilter('read_at', null);
  }

  // ---------- Susurros (Etapa 2) ----------
  // Privados DENTRO de la sala: la base solo los entrega al emisor y
  // al destinatario (RLS), nadie más puede leerlos ni por accidente.

  /// Susurros de esta sala en los que participo (como emisor o
  /// destinatario), con los perfiles de ambos incluidos.
  Future<List<Map<String, dynamic>>> fetchWhispers(String roomId,
      {int limit = 100}) async {
    final rows = await _db
        .from('whispers')
        .select(
            '*, sender:profiles!whispers_sender_uid_fkey(nickname, nickname_color), target:profiles!whispers_target_uid_fkey(nickname, nickname_color)')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows.reversed);
  }

  Future<Map<String, dynamic>> sendWhisper({
    required String roomId,
    required String targetUid,
    required String body,
  }) async {
    final inserted = await _db
        .from('whispers')
        .insert({
          'room_id': roomId,
          'sender_uid': myUid,
          'target_uid': targetUid,
          'body': body,
        })
        .select()
        .single();
    await _db.from('notifications').insert({
      'uid': targetUid,
      'kind': 'whisper',
      'payload': {
        'room_id': roomId,
        'from_uid': myUid,
        'from_nickname': await myNickname(),
        'room_name': await roomNameById(roomId),
      },
    });
    return inserted;
  }

  RealtimeChannel subscribeWhispers(
      String roomId, void Function(Map<String, dynamic> row) onInsert) {
    final channel = _db.channel('room-whispers-$roomId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'whispers',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }

  // ---------- Mensajes privados 1:1 (Etapa 2) ----------

  /// La conversación con otra persona (se crea si no existe).
  /// La pareja se guarda siempre en orden (user_a < user_b).
  Future<Map<String, dynamic>> getOrCreateConversation(
      String otherUid) async {
    final me = myUid!;
    final a = me.compareTo(otherUid) < 0 ? me : otherUid;
    final b = me.compareTo(otherUid) < 0 ? otherUid : me;
    final existing = await _db
        .from('conversations')
        .select()
        .eq('user_a', a)
        .eq('user_b', b)
        .limit(1);
    if (existing.isNotEmpty) return existing.first;
    return await _db
        .from('conversations')
        .insert({'user_a': a, 'user_b': b})
        .select()
        .single();
  }

  /// Mis conversaciones con: el perfil del otro, el último mensaje y
  /// cuántos privados suyos tengo sin leer.
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final me = myUid!;
    final convs = await _db
        .from('conversations')
        .select()
        .or('user_a.eq.$me,user_b.eq.$me')
        .order('created_at', ascending: false);
    final result = <Map<String, dynamic>>[];
    if (convs.isEmpty) return result;
    final otherUids = <String>{};
    final convIds = <String>[];
    for (final c in convs) {
      final other = c['user_a'] == me ? c['user_b'] : c['user_a'];
      otherUids.add(other as String);
      convIds.add(c['id'] as String);
    }
    final profiles = await profilesByUids(otherUids.toList());
    final profileById = {for (final p in profiles) p['uid'] as String: p};
    // Últimos mensajes de todas mis conversaciones en una consulta.
    final recent = await _db
        .from('direct_messages')
        .select()
        .inFilter('conversation_id', convIds)
        .order('created_at', ascending: false)
        .limit(300);
    final lastByConv = <String, Map<String, dynamic>>{};
    final unreadByConv = <String, int>{};
    for (final m in recent) {
      final cid = m['conversation_id'] as String;
      lastByConv.putIfAbsent(cid, () => m);
      if (m['sender_uid'] != me && m['read_at'] == null) {
        unreadByConv[cid] = (unreadByConv[cid] ?? 0) + 1;
      }
    }
    for (final c in convs) {
      final cid = c['id'] as String;
      final other = c['user_a'] == me ? c['user_b'] : c['user_a'];
      result.add({
        ...c,
        'other': profileById[other],
        'last': lastByConv[cid],
        'unread': unreadByConv[cid] ?? 0,
      });
    }
    // Primero las conversaciones con actividad más reciente.
    result.sort((x, y) {
      final tx = (x['last']?['created_at'] ?? x['created_at']) as String;
      final ty = (y['last']?['created_at'] ?? y['created_at']) as String;
      return ty.compareTo(tx);
    });
    return result;
  }

  /// Total de privados sin leer (para el distintivo de la pestaña).
  Future<int> dmUnreadCount() async {
    final me = myUid!;
    final convs = await _db
        .from('conversations')
        .select('id')
        .or('user_a.eq.$me,user_b.eq.$me');
    if (convs.isEmpty) return 0;
    final ids = convs.map((c) => c['id'] as String).toList();
    final rows = await _db
        .from('direct_messages')
        .select('id')
        .inFilter('conversation_id', ids)
        .neq('sender_uid', me)
        .isFilter('read_at', null);
    return rows.length;
  }

  Future<List<Map<String, dynamic>>> fetchDirectMessages(
      String conversationId,
      {int limit = 100}) async {
    final rows = await _db
        .from('direct_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows.reversed);
  }

  Future<Map<String, dynamic>> sendDirectMessage({
    required String conversationId,
    required String otherUid,
    required String body,
  }) async {
    final inserted = await _db
        .from('direct_messages')
        .insert({
          'conversation_id': conversationId,
          'sender_uid': myUid,
          'body': body,
        })
        .select()
        .single();
    await _db.from('notifications').insert({
      'uid': otherUid,
      'kind': 'dm',
      'payload': {
        'conversation_id': conversationId,
        'from_uid': myUid,
        'from_nickname': await myNickname(),
      },
    });
    return inserted;
  }

  /// Marca como leídos los privados que me enviaron en esta
  /// conversación (la regla de la base solo deja hacerlo al
  /// destinatario).
  Future<void> markConversationRead(String conversationId) async {
    await _db
        .from('direct_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_uid', myUid!)
        .isFilter('read_at', null);
  }

  RealtimeChannel subscribeDirectMessages(
      String conversationId, void Function(Map<String, dynamic> row) onInsert) {
    final channel = _db.channel('dm-$conversationId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }

  // ---------- Moderación (Etapa 3) ----------
  // Las sanciones se aplican desde funciones del servidor que
  // verifican el rol de quien actúa y dejan auditoría; la app solo
  // pide y muestra. El cumplimiento (no poder escribir estando
  // silenciado o baneado) también vive en el servidor.

  Future<Map<String, dynamic>?> memberState(String roomId, String uid) async {
    final rows = await _db
        .from('room_members')
        .select()
        .eq('room_id', roomId)
        .eq('uid', uid)
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Todos los miembros de la sala (uid → fila), para mostrar roles
  /// y destacados junto a la presencia.
  Future<Map<String, Map<String, dynamic>>> roomMembersInfo(
      String roomId) async {
    final rows = await _db.from('room_members').select().eq('room_id', roomId);
    return {for (final r in rows) r['uid'] as String: r};
  }

  Future<bool> moderateMember({
    required String roomId,
    required String targetUid,
    required String action,
    int? minutes,
    String? detail,
  }) async {
    final r = await _db.rpc('moderate_member', params: {
      'p_room': roomId,
      'p_target': targetUid,
      'p_action': action,
      'p_minutes': minutes,
      'p_detail': detail,
    });
    return r == true;
  }

  Future<bool> setRoomRole({
    required String roomId,
    required String targetUid,
    required String role,
  }) async {
    final r = await _db.rpc('set_room_role', params: {
      'p_room': roomId,
      'p_target': targetUid,
      'p_role': role,
    });
    return r == true;
  }

  /// Sanciones vigentes de la sala (baneos y silencios activos).
  Future<List<Map<String, dynamic>>> fetchSanctioned(String roomId) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final rows = await _db
        .from('room_members')
        .select(
            '*, member:profiles!room_members_uid_fkey(nickname, nickname_color)')
        .eq('room_id', roomId)
        .or('banned_at.not.is.null,muted_until.gt.$nowIso');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Registro de auditoría de la sala (últimas 50 acciones).
  Future<List<Map<String, dynamic>>> fetchModActions(String roomId,
      {int limit = 50}) async {
    final rows = await _db
        .from('mod_actions')
        .select(
            '*, actor:profiles!mod_actions_actor_uid_fkey(nickname), target:profiles!mod_actions_target_uid_fkey(nickname)')
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ---------- Social: favoritos, bloqueos, reportes ----------

  Future<Set<String>> fetchBlockedUids() async {
    final rows = await _db.from('blocks').select('blocked_uid').eq('uid', myUid!);
    return rows.map((r) => r['blocked_uid'] as String).toSet();
  }

  Future<void> block(String uid) =>
      _db.from('blocks').insert({'uid': myUid, 'blocked_uid': uid});

  Future<void> unblock(String uid) => _db
      .from('blocks')
      .delete()
      .eq('uid', myUid!)
      .eq('blocked_uid', uid);

  Future<bool> isFavorite(String uid) async {
    final rows = await _db
        .from('favorites')
        .select()
        .eq('uid', myUid!)
        .eq('favorite_uid', uid)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> setFavorite(String uid, bool fav) async {
    if (fav) {
      await _db.from('favorites').insert({'uid': myUid, 'favorite_uid': uid});
    } else {
      await _db
          .from('favorites')
          .delete()
          .eq('uid', myUid!)
          .eq('favorite_uid', uid);
    }
  }

  Future<void> report({
    required String targetUid,
    String? roomId,
    required String reason,
  }) async {
    await _db.from('reports').insert({
      'reporter_uid': myUid,
      'target_uid': targetUid,
      'room_id': roomId,
      'reason': reason,
    });
  }

  // ---------- Centro de reportes y conducta (v1.17) ----------

  /// Envía un reporte del centro (error | user | abuse). La evidencia
  /// la captura la función del servidor, no el cliente.
  Future<int> submitReport({
    required String kind,
    String? targetUid,
    String? roomId,
    required String description,
  }) async {
    final r = await _db.rpc('submit_report', params: {
      'p_kind': kind,
      'p_target': targetUid,
      'p_room': roomId,
      'p_description': description,
      'p_app_version': AppConfig.appVersion,
    });
    return (r as num).toInt();
  }

  /// Reportes visibles para mí según mi alcance (RLS del servidor).
  Future<List<Map<String, dynamic>>> fetchReportsCenter() async {
    final rows = await _db
        .from('reports_center')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Cambia el estado de un reporte (review | resolved | dismissed).
  Future<bool> resolveReport(int id, String status, {String? note}) async {
    final r = await _db.rpc('resolve_report', params: {
      'p_id': id,
      'p_status': status,
      'p_note': note,
    });
    return r == true;
  }

  /// Mi situación de poder: {has_power, conduct_accepted,
  /// center_visible, is_owner}.
  Future<Map<String, dynamic>> myPowerStatus() async {
    final r = await _db.rpc('my_power_status');
    if (r is Map) return Map<String, dynamic>.from(r);
    return {
      'has_power': false,
      'conduct_accepted': true,
      'center_visible': false,
      'is_owner': false,
    };
  }

  /// Registra mi aceptación del código de conducta.
  Future<bool> acceptConduct() async {
    final r = await _db.rpc('accept_conduct');
    return r == true;
  }

  /// Traduce un mensaje al idioma del usuario (Etapa 5, DeepL en
  /// el servidor). Devuelve {translated, detected}.
  Future<Map<String, dynamic>> translateText(String text) async {
    final res = await _db.functions.invoke('translate', body: {
      'text': text,
      'target': appLanguage.value,
    });
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('translate_bad_response');
  }

  // ---------- Juegos en privados: Gato 1 vs 1 ----------

  /// Invita al otro a jugar (o devuelve la partida vigente).
  Future<String?> inviteGame(String otherUid) async {
    final r = await _db.rpc('game_invite', params: {'p_other': otherUid});
    return r as String?;
  }

  Future<bool> respondGame(String gameId, bool accept) async {
    final r = await _db.rpc('game_respond',
        params: {'p_game': gameId, 'p_accept': accept});
    return r == true;
  }

  /// Juega una celda (0-8). Devuelve el resultado o null si el
  /// servidor rechazó la jugada (no era tu turno, celda ocupada…).
  Future<Map<String, dynamic>?> moveGame(String gameId, int cell) async {
    final r = await _db
        .rpc('game_move', params: {'p_game': gameId, 'p_cell': cell});
    return r == null ? null : Map<String, dynamic>.from(r as Map);
  }

  Future<bool> resignGame(String gameId) async {
    final r = await _db.rpc('game_resign', params: {'p_game': gameId});
    return r == true;
  }

  Future<Map<String, dynamic>?> fetchGameById(String gameId) async {
    final rows =
        await _db.from('games').select().eq('id', gameId).limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  /// La partida de Gato más reciente entre el otro y yo.
  Future<Map<String, dynamic>?> fetchPairGame(String otherUid) async {
    final me = myUid!;
    final rows = await _db
        .from('games')
        .select()
        .eq('game_type', 'gato')
        .or('and(player_a.eq.$me,player_b.eq.$otherUid),and(player_a.eq.$otherUid,player_b.eq.$me)')
        .order('created_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  RealtimeChannel subscribeGame(
      String gameId, void Function(Map<String, dynamic> row) onUpdate) {
    final channel = _db.channel('game-$gameId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'games',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: gameId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
    return channel;
  }

  // ---------- Ayuda / Staff (pulido tras Etapa 5) ----------

  /// Uids del equipo: dueño global y staff.
  Future<Set<String>> staffUids() async {
    final rows = await _db
        .from('profiles')
        .select('uid')
        .inFilter('global_role', ['staff', 'owner']);
    return {for (final r in rows) r['uid'] as String};
  }

  /// Mensajes de USUARIOS sin leer en la sala Ayuda para mí: los
  /// escritos por no-Staff después de mi marcador de lectura.
  Future<int> helpUnreadCount(String roomId) async {
    final member = await memberState(roomId, myUid!);
    final marker = (member?['last_read_at'] as String?) ??
        (member?['joined_at'] as String?) ??
        '1970-01-01T00:00:00Z';
    final staff = await staffUids();
    final rows = await _db
        .from('room_messages')
        .select('sender_uid')
        .eq('room_id', roomId)
        .gt('created_at', marker)
        .order('created_at')
        .limit(300);
    var n = 0;
    for (final r in rows) {
      final sender = r['sender_uid'] as String?;
      if (sender != null && sender != myUid && !staff.contains(sender)) n++;
    }
    return n;
  }

  /// Marco la sala como leída hasta ahora (mi propia fila).
  Future<void> markHelpRead(String roomId) async {
    await _db
        .from('room_members')
        .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('room_id', roomId)
        .eq('uid', myUid!);
  }

  Future<void> updateMyProfile(
      {String? bio,
      String? colorHex,
      String? themeMode,
      String? country,
      String? language,
      bool? showInDirectory,
      bool? dmOpen,
      bool? whispersOpen,
      bool? showSystemNotices,
      bool? soundEnabled,
      bool? vibrateEnabled}) async {
    final patch = <String, dynamic>{};
    if (bio != null) patch['bio'] = bio;
    if (colorHex != null) patch['nickname_color'] = colorHex;
    if (themeMode != null) patch['theme_mode'] = themeMode;
    if (country != null) patch['country'] = country;
    if (language != null) patch['language'] = language;
    if (showInDirectory != null) {
      patch['show_in_directory'] = showInDirectory;
    }
    if (dmOpen != null) patch['dm_open'] = dmOpen;
    if (whispersOpen != null) patch['whispers_open'] = whispersOpen;
    if (showSystemNotices != null) {
      patch['show_system_notices'] = showSystemNotices;
    }
    if (soundEnabled != null) patch['sound_enabled'] = soundEnabled;
    if (vibrateEnabled != null) {
      patch['vibrate_enabled'] = vibrateEnabled;
    }
    if (patch.isEmpty) return;
    await _db.from('profiles').update(patch).eq('uid', myUid!);
  }

  // ---------- Integración Beta (v1.22/v1.23) ----------

  /// Cambio de nickname atómico en el servidor (punto 13).
  /// Devuelve: ok | invalid | taken | same | cooldown |
  /// no_profile | not_authenticated.
  Future<String> changeNickname(String newNick) async {
    final r = await _db.rpc('change_nickname', params: {'p_new': newNick});
    return r as String? ?? 'error';
  }

  /// ¿Puedo escribirle un privado a este usuario? (punto 11)
  Future<bool> canDm(String targetUid) async {
    final r = await _db.rpc('can_dm', params: {'p_target': targetUid});
    return r == true;
  }

  /// ¿Puedo susurrarle a este usuario? (punto 14)
  Future<bool> canWhisper(String targetUid) async {
    final r =
        await _db.rpc('can_whisper', params: {'p_target': targetUid});
    return r == true;
  }

  /// Panel del dueño: cambiar el rol global de otro usuario
  /// (punto 2). Solo el dueño global puede; el servidor protege
  /// al propio dueño y deja auditoría.
  Future<bool> setGlobalRole(String targetUid, String role) async {
    final r = await _db.rpc('set_global_role', params: {
      'p_target': targetUid,
      'p_role': role,
    });
    return r == true;
  }

  /// Buscar perfiles por nickname (panel del dueño).
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    final q = query.trim().replaceAll('%', '').replaceAll('_', '');
    if (q.length < 2) return [];
    final rows = await _db
        .from('profiles')
        .select(profileColumns)
        .ilike('nickname', '%$q%')
        .order('nickname')
        .limit(30);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Aviso del sistema en la sala (punto 12): kind 'system' con
  /// código en el cuerpo ('join' | 'leave'); las sanciones las
  /// inserta el servidor ('mod:mute' | 'mod:ban', sin nick).
  Future<Map<String, dynamic>?> sendSystemNotice(
      String roomId, String code) async {
    try {
      final row = await _db
          .from('room_messages')
          .insert({
            'room_id': roomId,
            'sender_uid': myUid,
            'sender_nickname': await myNickname(),
            'kind': 'system',
            'body': code,
          })
          .select()
          .single();
      return row;
    } catch (_) {
      return null;
    }
  }

  /// ¿Ya avisé esto en esta sala hace poco? (freno anti-spam de
  /// entradas/salidas: 10 minutos).
  Future<bool> recentOwnSystemNotice(String roomId, String code) async {
    final since =
        DateTime.now().toUtc().subtract(const Duration(minutes: 10));
    final rows = await _db
        .from('room_messages')
        .select('id')
        .eq('room_id', roomId)
        .eq('sender_uid', myUid!)
        .eq('kind', 'system')
        .eq('body', code)
        .gt('created_at', since.toIso8601String())
        .limit(1);
    return rows.isNotEmpty;
  }

  // ---------- Galería (web oficial W2) ----------

  Future<List<Map<String, dynamic>>> myGallery() async {
    final rows = await _db
        .from('gallery_photos')
        .select()
        .eq('uid', myUid!)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Sube una foto a la Galería propia (bucket «gallery»,
  /// carpeta `<uid>/`). El límite de 3 gratis lo impone el
  /// servidor: si se alcanza, lanza con mensaje gallery_limit.
  Future<void> uploadGalleryPhoto(List<int> bytes, String fileName) async {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'), '')
        : 'jpg';
    final safeExt = ext.isEmpty ? 'jpg' : ext;
    final path =
        '$myUid/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    await _db.storage.from('gallery').uploadBinary(
          path,
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        );
    final url = _db.storage.from('gallery').getPublicUrl(path);
    await _db.from('gallery_photos').insert({'uid': myUid, 'url': url});
  }

  Future<void> deleteGalleryPhoto(Map<String, dynamic> photo) async {
    final url = photo['url'] as String;
    final marker = '/object/public/gallery/';
    final idx = url.indexOf(marker);
    if (idx >= 0) {
      final path = Uri.decodeComponent(url.substring(idx + marker.length));
      await _db.storage.from('gallery').remove([path]);
    }
    await _db.from('gallery_photos').delete().eq('id', photo['id']);
  }
}
