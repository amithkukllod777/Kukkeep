import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'offline_store.dart';
import 'push.dart';

// Every network call gets a consistent ceiling instead of hanging forever on
// a stalled connection (qa-audit SEC-007).
const _kRequestTimeout = Duration(seconds: 20);

// Offline-first notes (qa-audit REMEDIATION_PLAN.md, medium-term item): tells
// a genuine "can't reach the server" failure apart from a real server-side
// rejection (bad input, 404, etc.) — only the former should fall back to the
// local cache / queue into the outbox. The latter must still surface to the
// caller so existing error handling (friendlyError, retry UI) keeps working.
bool _isConnectivityError(Object e) => e is SocketException || e is TimeoutException || e is http.ClientException;

/// Minimal tRPC-over-HTTP client for the KukLabs backend.
///
/// The server uses tRPC v11 with the superjson transformer and httpBatchLink, so
/// every call is wrapped as a batch of one: input goes as {"0":{"json":<input>}}
/// and the response comes back as [{"result":{"data":{"json":<data>}}}].
/// Auth is a Bearer token (returned by auth.directLogin); the active company is
/// passed via the x-company-id header.
class Api {
  Api._();
  static final Api instance = Api._();

  // KukKeep's own subdomain; the API is the shared KukLabs platform backend
  // (one backend + DB + accounts for every Kuk app).
  static const String base = 'https://keep.kuklabs.com';

  // The Bearer session token is the one genuinely sensitive value this app
  // stores — it's kept in Keystore-backed secure storage (Android
  // EncryptedSharedPreferences under the hood), not plain SharedPreferences,
  // so it isn't readable in plaintext via a rooted device or an insecure
  // backup (qa-audit SEC-001). Company id / display name aren't secrets and
  // stay in ordinary SharedPreferences.
  static const _secureStorage = FlutterSecureStorage();

  String? _token;
  int? _companyId;
  String? userName;

  String? get token => _token;
  int? get companyId => _companyId;
  bool get isLoggedIn => _token != null;

  Future<void> load() async {
    _token = await _secureStorage.read(key: 'kk_token');
    final p = await SharedPreferences.getInstance();
    _companyId = p.getInt('kk_company');
    userName = p.getString('kk_user');
  }

  Future<void> _save() async {
    if (_token != null) await _secureStorage.write(key: 'kk_token', value: _token!);
    final p = await SharedPreferences.getInstance();
    if (_companyId != null) await p.setInt('kk_company', _companyId!);
    if (userName != null) await p.setString('kk_user', userName!);
  }

  Future<void> logout() async {
    // Best-effort server-side logout (qa-audit SEC-002): the shared backend's
    // auth.logout only clears its own session cookie today — it doesn't (and,
    // being a stateless JWT with no revocation list, currently can't) invalidate
    // this Bearer token — but it does log a security event, so it's worth
    // calling. Never let a failed/offline call block the local sign-out.
    try { await mutate('auth.logout', {}); } catch (_) {}
    _token = null;
    _companyId = null;
    userName = null;
    _lastRegisteredPushToken = null; // next user re-registers this device's token
    await _secureStorage.delete(key: 'kk_token');
    final p = await SharedPreferences.getInstance();
    await p.remove('kk_company');
    await p.remove('kk_user');
  }

  void setCompany(int id) {
    _companyId = id;
    _save();
  }

  /// Make a storage URL absolute. The backend returns relative paths like
  /// "/local-storage/<id>" (served from the app origin); the mobile app must
  /// prefix them with the host or Image.network can't load them.
  String absoluteUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$base${url.startsWith('/') ? '' : '/'}$url';
  }

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (_token != null) 'authorization': 'Bearer $_token',
        if (_companyId != null) 'x-company-id': '$_companyId',
      };

  dynamic _unwrap(http.Response res) {
    // A 401 only means "session expired" when we HAD a session. During login the
    // server's real message (e.g. "Invalid email or password") also arrives as
    // 401 — fall through and show it instead of masking it.
    if (res.statusCode == 401 && _token != null) {
      throw ApiError('Session expired. Please log in again.', unauthorized: true);
    }
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      // Non-JSON body (proxy/nginx error page) — don't show raw HTML to the user.
      throw ApiError('Server unavailable (${res.statusCode}). Please try again.');
    }
    // Batch responses are arrays; single calls come back as one element.
    final entry = body is List ? body[0] : body;
    if (entry is Map && entry['error'] != null) {
      final msg = entry['error']?['json']?['message'] ?? entry['error']?['message'] ?? 'Request failed';
      throw ApiError(msg.toString(), unauthorized: res.statusCode == 401);
    }
    return entry?['result']?['data']?['json'];
  }

  Future<dynamic> query(String proc, [Map<String, dynamic>? input]) async {
    // tRPC batch envelope: a no-arg query must send {"0":{"json":null}}.
    final payload = Uri.encodeComponent(jsonEncode({'0': {'json': input}}));
    final url = Uri.parse('$base/api/trpc/$proc?batch=1&input=$payload');
    final res = await http.get(url, headers: _headers).timeout(_kRequestTimeout);
    return _unwrap(res);
  }

  Future<dynamic> mutate(String proc, Map<String, dynamic> input) async {
    final url = Uri.parse('$base/api/trpc/$proc?batch=1');
    final res = await http.post(url, headers: _headers, body: jsonEncode({'0': {'json': input}}))
        .timeout(_kRequestTimeout);
    return _unwrap(res);
  }

  // ── Auth ──
  /// Returns true on success. Throws ApiError on bad credentials.
  Future<bool> login(String email, String password) async {
    final data = await mutate('auth.directLogin', {'email': email, 'password': password});
    if (data is Map && data['mfaRequired'] == true) {
      throw ApiError('Two-factor is enabled on this account. Please log in on the web first.');
    }
    final token = data is Map ? data['token'] : null;
    if (token == null) throw ApiError('Login failed');
    _token = token.toString();
    userName = (data['user']?['name'] ?? '').toString();
    await _save();
    return true;
  }

  Future<List<Company>> companies() async {
    final data = await query('company.list');
    if (data is List) return data.map((e) => Company.fromJson(e)).toList();
    return [];
  }

  // ── Signup (central KukLabs auth — same accounts as the web + every Kuk app) ──
  /// Step 1: create a pending account and email a 6-digit OTP.
  Future<void> register({required String name, required String email, required String phone, required String password}) async {
    await mutate('auth.directRegister', {
      'name': name, 'email': email, 'phone': phone, 'password': password, 'acceptedTerms': true,
    });
  }

  /// Step 2: verify the OTP — completes signup and logs the user in (returns a token).
  Future<void> verifyOtp(String email, String otp) async {
    final data = await mutate('auth.verifyOtp', {'email': email, 'otp': otp});
    final token = data is Map ? data['token'] : null;
    if (token == null) throw ApiError('Verification failed');
    _token = token.toString();
    userName = (data['user']?['name'] ?? '').toString();
    await _save();
  }

  Future<void> resendOtp(String email) => mutate('auth.resendOtp', {'email': email});

  // ── Data & Privacy (qa-audit: Google Play Account Deletion policy) ──
  /// Exports the signed-in user's personal data (profile, workspaces, KukChat
  /// handle) via the shared platform's GDPR/DPDP data-export endpoint.
  Future<Map<String, dynamic>> exportMyData() async {
    final data = await query('auth.exportMyData');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  /// Deletes (anonymizes) the signed-in user's account via the shared
  /// platform's GDPR/DPDP account-deletion endpoint. Throws an ApiError with
  /// a user-actionable message if the account can't be deleted yet (e.g. the
  /// user still solely owns a company and must transfer ownership first).
  Future<void> deleteAccount() async {
    await mutate('auth.deleteMyAccount', {'confirm': true});
    // The server already cleared its own session; drop the local one too.
    _token = null;
    _companyId = null;
    userName = null;
    _lastRegisteredPushToken = null;
    await _secureStorage.delete(key: 'kk_token');
    final p = await SharedPreferences.getInstance();
    await p.remove('kk_company');
    await p.remove('kk_user');
  }

  // ── Google sign-in (server-side OAuth — the app only opens a browser) ──
  /// The browser URL that starts the flow; the server deep-links back to
  /// kukkeep://auth with a one-time code when Google finishes.
  static const String googleStartUrl = '$base/api/auth/google/start?app=kukkeep';

  /// Whether this deployment has Google OAuth configured (hides the button when not).
  Future<bool> googleEnabled() async {
    try {
      final res = await http.get(Uri.parse('$base/api/auth/google/status'))
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return false;
      final b = jsonDecode(res.body);
      return b is Map && b['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Trade the one-time deep-link code for a session token (same Bearer token
  /// as directLogin — 30-day native TTL). POSTed in the body, not a query
  /// string — a one-time secret shouldn't end up in server/proxy access logs
  /// (qa-audit SEC-004).
  Future<void> googleExchange(String code) async {
    final res = await http.post(
        Uri.parse('$base/api/auth/google/app-exchange'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'code': code}))
        .timeout(_kRequestTimeout);
    dynamic b;
    try { b = jsonDecode(res.body); } catch (_) {
      throw ApiError('Google sign-in failed. Please try again.');
    }
    final token = b is Map ? b['token'] : null;
    if (token == null) {
      final msg = (b is Map ? b['error'] : null)?.toString();
      throw ApiError(msg == null || msg.isEmpty ? 'Google sign-in failed. Please try again.' : msg);
    }
    _token = token.toString();
    userName = (b['name'] ?? '').toString();
    await _save();
  }

  String _slugify(String name) {
    final base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'(^-|-$)'), '');
    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return '${base.isEmpty ? 'workspace' : base}-$suffix';
  }

  /// Create a free notes workspace (company) for the signed-in user.
  Future<void> _createDefaultCompany(String name, String phone) async {
    await mutate('company.create', {
      'name': name, 'slug': _slugify(name), 'phone': phone,
      'productType': 'tasks', 'signupModule': 'keep',
    });
  }

  /// Make sure the logged-in user has an active company; create a free one if none.
  /// Silent — no setup screen. Phone is optional (a placeholder is used only when
  /// a brand-new account has no workspace and none was provided).
  /// Returns the active company id, or null if it couldn't be resolved.
  Future<int?> ensureCompany({required String name, String phone = ''}) async {
    var list = await companies();
    if (list.isEmpty) {
      await _createDefaultCompany(name.trim().isEmpty ? 'My Notes' : name, phone.trim().isEmpty ? '0000000' : phone);
      list = await companies();
    }
    if (list.isEmpty) return null;
    setCompany(list.first.id);
    return list.first.id;
  }

  // ── Notes (KukKeep `keep` router → kuk_keep_notes table) ──
  //
  // Offline-first (qa-audit REMEDIATION_PLAN.md): every method below tries the
  // network first — identical behavior to before when online. On a genuine
  // connectivity failure (never a real server rejection), it falls back to /
  // queues into OfflineStore instead of throwing, so the screens' existing
  // optimistic-update + catch-block code needs no changes at all. A `create`
  // made offline gets a negative temp id; further offline edits to that same
  // note coalesce into the still-queued create instead of stacking ops
  // against a server id that doesn't exist yet.

  bool _flushingOutbox = false;
  bool _lastNotesFromCache = false;
  // The FCM device token last registered with the backend this session — so we
  // only POST it when it's new/changed (and re-register after a login switch).
  String? _lastRegisteredPushToken;
  /// True if the most recent `notes()` call served the local cache instead of
  /// a live server response (lets the UI show a small "offline" indicator).
  bool get isOffline => _lastNotesFromCache;

  Future<List<Note>> notes({bool archived = false, bool trashed = false}) async {
    try {
      final data = await query('keep.list', {'archived': archived, 'trashed': trashed});
      final list = data is List ? data.map((e) => Note.fromJson(e)).toList() : <Note>[];
      _lastNotesFromCache = false;
      unawaited(OfflineStore.instance.saveNotes(archived: archived, trashed: trashed, notes: list));
      unawaited(flushOutbox()); // a successful round-trip proves we're online
      unawaited(_maybeRegisterPushToken()); // also proves we're logged in + have a company
      return list;
    } catch (e) {
      if (_isConnectivityError(e) && await OfflineStore.instance.hasCacheFor(archived: archived, trashed: trashed)) {
        _lastNotesFromCache = true;
        return OfflineStore.instance.loadNotes(archived: archived, trashed: trashed);
      }
      rethrow;
    }
  }

  /// Register this device's FCM token with the backend so the server can push
  /// reminders even when the OS has killed the app (the reliable delivery path
  /// on battery-optimizing OEMs). Best-effort: requires a session + an active
  /// company + a token, only re-sends when the token is new, and never throws.
  Future<void> _maybeRegisterPushToken() async {
    if (_token == null || _companyId == null) return;
    final t = Push.instance.token;
    if (t == null || t.isEmpty || t == _lastRegisteredPushToken) return;
    try {
      await mutate('notifications.registerFcmToken', {'token': t, 'platform': 'android'});
      _lastRegisteredPushToken = t;
    } catch (_) {/* best-effort — a returning tick or app launch retries */}
  }

  Future<void> createNote(Map<String, dynamic> input) async {
    await createNoteReturningId(input);
  }

  /// Create a note and return its new id (used to attach images/files/drawings
  /// to a brand-new note without a separate Save step). Offline, returns a
  /// negative temp id immediately — callers that only need "a note exists
  /// now" (autosave, attachments-gate) work unchanged; attachment upload
  /// itself still requires a real (positive) id since file bytes aren't
  /// queued in this scope.
  Future<int?> createNoteReturningId(Map<String, dynamic> input) async {
    try {
      final data = await mutate('keep.create', input);
      if (data is Map && data['id'] != null) {
        final id = (data['id'] as num).toInt();
        unawaited(OfflineStore.instance.cacheCreate(id, input));
        return id;
      }
      return null;
    } catch (e) {
      if (_isConnectivityError(e)) {
        final tempId = await OfflineStore.instance.nextTempId();
        await OfflineStore.instance.cacheCreate(tempId, input);
        await OfflineStore.instance.enqueue('create', input, coalesceLocalNoteId: tempId);
        return tempId;
      }
      rethrow;
    }
  }

  Future<void> updateNote(Map<String, dynamic> input) async {
    final id = input['id'] is num ? (input['id'] as num).toInt() : null;
    try {
      await mutate('keep.update', input);
      if (id != null) unawaited(OfflineStore.instance.cacheUpdate(id, input));
    } catch (e) {
      if (_isConnectivityError(e) && id != null) {
        await OfflineStore.instance.cacheUpdate(id, input);
        if (id < 0) {
          // Note hasn't synced yet — fold this edit into the pending create.
          await OfflineStore.instance.enqueue('create', {...input}..remove('id'), coalesceLocalNoteId: id);
        } else {
          await OfflineStore.instance.enqueue('update', input);
        }
        return;
      }
      rethrow;
    }
  }

  Future<void> trashNote(int id) => _trashOrRestore(id, trashed: true);   // move to Trash
  Future<void> restoreNote(int id) => _trashOrRestore(id, trashed: false); // restore

  Future<void> _trashOrRestore(int id, {required bool trashed}) async {
    if (id < 0) {
      // Never-synced note — trashing it is the same as it never existing.
      if (trashed) await OfflineStore.instance.discardTempNote(id);
      return;
    }
    final payload = {'id': id, 'trashed': trashed};
    try {
      await mutate('keep.trash', payload);
      unawaited(trashed ? OfflineStore.instance.cacheMoveToTrash(id) : OfflineStore.instance.cacheRestoreFromTrash(id));
    } catch (e) {
      if (_isConnectivityError(e)) {
        if (trashed) {
          await OfflineStore.instance.cacheMoveToTrash(id);
        } else {
          await OfflineStore.instance.cacheRestoreFromTrash(id);
        }
        await OfflineStore.instance.enqueue('trash', payload);
        return;
      }
      rethrow;
    }
  }

  Future<void> removeNote(int id) async {
    // permanent delete
    if (id < 0) { await OfflineStore.instance.discardTempNote(id); return; }
    try {
      await mutate('keep.remove', {'id': id});
      unawaited(OfflineStore.instance.cacheRemove(id));
    } catch (e) {
      if (_isConnectivityError(e)) {
        await OfflineStore.instance.cacheRemove(id);
        await OfflineStore.instance.enqueue('remove', {'id': id});
        return;
      }
      rethrow;
    }
  }

  Future<void> emptyTrash() async {
    try {
      await mutate('keep.emptyTrash', {'all': true});
      unawaited(OfflineStore.instance.cacheEmptyTrash());
    } catch (e) {
      if (_isConnectivityError(e)) {
        await OfflineStore.instance.cacheEmptyTrash();
        await OfflineStore.instance.enqueue('emptyTrash', {'all': true});
        return;
      }
      rethrow;
    }
  }

  // ── Labels ──
  Future<void> renameLabel(String from, String to) async {
    final payload = {'from': from, 'to': to};
    try {
      await mutate('keep.renameLabel', payload);
      unawaited(OfflineStore.instance.cacheRenameLabel(from, to));
    } catch (e) {
      if (_isConnectivityError(e)) {
        await OfflineStore.instance.cacheRenameLabel(from, to);
        await OfflineStore.instance.enqueue('renameLabel', payload);
        return;
      }
      rethrow;
    }
  }

  Future<void> deleteLabel(String label) async {
    final payload = {'label': label};
    try {
      await mutate('keep.deleteLabel', payload);
      unawaited(OfflineStore.instance.cacheDeleteLabel(label));
    } catch (e) {
      if (_isConnectivityError(e)) {
        await OfflineStore.instance.cacheDeleteLabel(label);
        await OfflineStore.instance.enqueue('deleteLabel', payload);
        return;
      }
      rethrow;
    }
  }

  /// Replays queued offline writes in order once a request actually reaches
  /// the server. Stops (leaving the rest queued) at the first sign we're
  /// still offline; drops — rather than retries forever — an op the server
  /// genuinely rejects (e.g. a note deleted elsewhere in the meantime), so one
  /// stale op can't wedge every op behind it. Calls the raw tRPC methods
  /// directly (never the wrapped methods above) so a still-offline replay
  /// can't re-queue the very op it's trying to send.
  Future<void> flushOutbox() async {
    if (_flushingOutbox) return;
    _flushingOutbox = true;
    try {
      final ops = await OfflineStore.instance.outbox();
      for (final op in ops) {
        try {
          switch (op['type']) {
            case 'create':
              final payload = Map<String, dynamic>.from(op['payload']);
              final data = await mutate('keep.create', payload);
              final realId = (data is Map && data['id'] != null) ? (data['id'] as num).toInt() : null;
              if (realId != null && op['localId'] != null) {
                await OfflineStore.instance.replaceTempNoteId(op['localId'] as int, realId);
              }
              break;
            case 'update':
              await mutate('keep.update', Map<String, dynamic>.from(op['payload']));
              break;
            case 'trash':
              await mutate('keep.trash', Map<String, dynamic>.from(op['payload']));
              break;
            case 'remove':
              await mutate('keep.remove', Map<String, dynamic>.from(op['payload']));
              break;
            case 'emptyTrash':
              await mutate('keep.emptyTrash', Map<String, dynamic>.from(op['payload']));
              break;
            case 'renameLabel':
              await mutate('keep.renameLabel', Map<String, dynamic>.from(op['payload']));
              break;
            case 'deleteLabel':
              await mutate('keep.deleteLabel', Map<String, dynamic>.from(op['payload']));
              break;
          }
          await OfflineStore.instance.removeOp(op['opId'] as int);
        } catch (e) {
          if (_isConnectivityError(e)) return; // still offline — retry next time
          await OfflineStore.instance.removeOp(op['opId'] as int); // genuine rejection — drop it, keep draining
        }
      }
    } finally {
      _flushingOutbox = false;
    }
  }

  // ── Attachments (image / file notes + OCR) ──
  Future<List<Attachment>> listAttachments(int noteId) async {
    final data = await query('keep.listAttachments', {'noteId': noteId});
    if (data is List) return data.map((e) => Attachment.fromJson(e)).toList();
    return [];
  }

  /// Upload a base64 file to a note. When [ocr] is true and the file is an image,
  /// the server extracts text and returns it. Returns the parsed result map.
  Future<Map<String, dynamic>> addAttachment({
    required int noteId,
    required String fileName,
    required String fileType,
    required String base64Data,
    bool ocr = false,
  }) async {
    final data = await mutate('keep.addAttachment', {
      'noteId': noteId, 'fileName': fileName, 'fileType': fileType, 'data': base64Data, 'ocr': ocr,
    });
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> deleteAttachment(int id) => mutate('keep.deleteAttachment', {'id': id});

  // ── AI Memory ──
  /// action: title | summary | clean | keypoints. Returns the AI text.
  Future<String> aiAction(String action, String content) async {
    final data = await mutate('keep.ai', {'action': action, 'content': content});
    return (data is Map ? (data['text'] ?? '') : '').toString();
  }

  /// Ask your notes — returns an answer drawn from the user's notes.
  Future<String> askNotes(String query) async {
    final data = await mutate('keep.ask', {'query': query});
    return (data is Map ? (data['answer'] ?? '') : '').toString();
  }
}

class ApiError implements Exception {
  final String message;
  final bool unauthorized;
  ApiError(this.message, {this.unauthorized = false});
  @override
  String toString() => message;
}
