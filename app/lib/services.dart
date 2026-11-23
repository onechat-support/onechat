import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce los errores de autenticación a lenguaje claro para el
/// usuario (nunca se muestra el texto técnico crudo).
String friendlyAuthError(Object e) {
  final t = e.toString();
  if (t.contains('over_email_send_rate_limit') ||
      t.contains('email rate limit')) {
    return 'Se alcanzó el límite de correos por ahora: el servicio de correo de esta etapa es muy reducido. Espera unos minutos y vuelve a intentarlo; tu nickname no se pierde.';
  }
  if (t.contains('user_already_exists') ||
      t.contains('already registered') ||
      t.contains('already exists')) {
    return 'Ese correo ya tiene una cuenta. Entra con tu nickname y tu contraseña; si aún no confirmaste el correo, pide el reenvío desde el paso de contraseña.';
  }
  if (t.contains('email_not_confirmed') || t.contains('not confirmed')) {
    return 'Tu correo aún no está confirmado. Revisa tu bandeja (y la carpeta de spam) o reenvía la confirmación.';
  }
  if (t.contains('invalid_credentials') ||
      t.contains('Invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (t.contains('weak_password') || t.contains('Password should')) {
    return 'La contraseña es muy débil: usa al menos 8 caracteres.';
  }
  if (t.contains('invalid_email') || t.contains('Unable to validate email')) {
    return 'Ese correo no parece válido. Revísalo e inténtalo de nuevo.';
  }
  return 'Algo salió mal. Inténtalo de nuevo en un momento.';
}

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
      return 'Usa de 3 a 20 caracteres: letras, números o guion bajo.';
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
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
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
    if (user == null) throw Exception('No se pudo crear la sesión de invitado.');
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
        throw Exception('Ese nickname ya está en uso. Prueba con otro.');
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
    if (user == null) throw Exception('No se pudo crear la cuenta.');
    if (res.session == null) return null; // falta confirmar el correo
    try {
      return await _createProfile(
          uid: user.id, nickname: nickname, isGuest: false, email: email);
    } catch (e) {
      if (_isNicknameTaken(e)) {
        throw Exception('Ese nickname ya está en uso. Inicia sesión y elige otro.');
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
      throw Exception('Nickname o contraseña incorrectos.');
    } on FunctionException {
      throw Exception('Nickname o contraseña incorrectos.');
    }
  }

  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final uid = myUid;
    if (uid == null) return null;
    final rows =
        await _db.from('profiles').select().eq('uid', uid).limit(1);
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

  // ---------- Salas y chat ----------

  Future<List<Map<String, dynamic>>> fetchRooms() async {
    final rows = await _db
        .from('rooms')
        .select()
        .eq('is_public', true)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
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

  Future<Map<String, dynamic>?> profileByUid(String uid) async {
    final rows = await _db.from('profiles').select().eq('uid', uid).limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> profilesByUids(List<String> uids) async {
    if (uids.isEmpty) return [];
    final rows = await _db.from('profiles').select().inFilter('uid', uids);
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
    for (final uid in mentionUids) {
      await _db.from('notifications').insert({
        'uid': uid,
        'kind': 'mention',
        'payload': {'room_id': roomId, 'message_id': inserted['id']},
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

  Future<void> updateMyProfile({String? bio, String? colorHex}) async {
    final patch = <String, dynamic>{};
    if (bio != null) patch['bio'] = bio;
    if (colorHex != null) patch['nickname_color'] = colorHex;
    if (patch.isEmpty) return;
    await _db.from('profiles').update(patch).eq('uid', myUid!);
  }
}
