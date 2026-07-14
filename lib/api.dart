import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

// Every network call gets a consistent ceiling instead of hanging forever on
// a stalled connection (qa-audit SEC-007).
const _kRequestTimeout = Duration(seconds: 20);

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
  /// as directLogin — 30-day native TTL).
  Future<void> googleExchange(String code) async {
    final res = await http.get(
        Uri.parse('$base/api/auth/google/app-exchange?code=${Uri.encodeComponent(code)}'))
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
  Future<List<Note>> notes({bool archived = false, bool trashed = false}) async {
    final data = await query('keep.list', {'archived': archived, 'trashed': trashed});
    if (data is List) return data.map((e) => Note.fromJson(e)).toList();
    return [];
  }

  Future<void> createNote(Map<String, dynamic> input) => mutate('keep.create', input);
  /// Create a note and return its new id (used to attach images/files/drawings
  /// to a brand-new note without a separate Save step).
  Future<int?> createNoteReturningId(Map<String, dynamic> input) async {
    final data = await mutate('keep.create', input);
    if (data is Map && data['id'] != null) return (data['id'] as num).toInt();
    return null;
  }
  Future<void> updateNote(Map<String, dynamic> input) => mutate('keep.update', input);
  Future<void> trashNote(int id) => mutate('keep.trash', {'id': id, 'trashed': true});   // move to Trash
  Future<void> restoreNote(int id) => mutate('keep.trash', {'id': id, 'trashed': false}); // restore
  Future<void> removeNote(int id) => mutate('keep.remove', {'id': id});                   // permanent delete
  Future<void> emptyTrash() => mutate('keep.emptyTrash', {'all': true});

  // ── Labels ──
  Future<void> renameLabel(String from, String to) => mutate('keep.renameLabel', {'from': from, 'to': to});
  Future<void> deleteLabel(String label) => mutate('keep.deleteLabel', {'label': label});

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
