import 'dart:convert';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'backup_codec.dart';
import 'drive_oauth_config.dart';

const driveBackupOnOpenPref = 'drive_backup_on_open';
const driveLastBackupMsPref = 'drive_last_backup_ms';

class DriveBackupException implements Exception {
  DriveBackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

String describeDriveAuthError(Object error) {
  final text = error.toString();
  final lower = text.toLowerCase();
  if (lower.contains('access_denied') ||
      lower.contains('403') ||
      (error is GoogleSignInException &&
          (error.description ?? '').toLowerCase().contains('access'))) {
    return 'Google returned 403 access_denied. In Cloud Console, for this '
        'same project: set the OAuth consent screen to Testing, add the Gmail '
        'you sign in with as a Test user, add scope '
        'https://www.googleapis.com/auth/drive.file, and enable the Drive '
        'API. The Web client ID in the APK and the Android client '
        '(com.bltr.sossoldi + this APK SHA-1) must belong to that project.';
  }
  if (error is GoogleSignInException) {
    return error.description ?? error.code.name;
  }
  return text;
}

class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    this.modifiedTime,
  });

  final String id;
  final String name;
  final DateTime? modifiedTime;
}

class _GoogleAuthClient extends http.BaseClient {
  _GoogleAuthClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}

class DriveBackupService {
  DriveBackupService._();
  static final DriveBackupService instance = DriveBackupService._();

  static const _folderName = 'Sossoldi';
  static const _scopes = <String>[drive.DriveApi.driveFileScope];

  GoogleSignInAccount? _user;
  Future<void>? _initFuture;

  bool get isSupported => Platform.isAndroid || Platform.isIOS;

  bool get isConfigured => DriveOAuthConfig.isConfigured;

  GoogleSignInAccount? get currentUser => _user;

  Future<void> ensureInitialized() {
    _initFuture ??= _initialize().catchError((Object error, StackTrace stack) {
      _initFuture = null;
      Error.throwWithStackTrace(error, stack);
    });
    return _initFuture!;
  }

  Future<void> _initialize() async {
    if (!isSupported) {
      throw DriveBackupException(
        'Google Drive backup is available on Android and iOS.',
      );
    }
    if (!isConfigured) {
      throw DriveBackupException(
        'Set GOOGLE_OAUTH_WEB_CLIENT_ID before using Drive backup.',
      );
    }
    await GoogleSignIn.instance.initialize(
      serverClientId: DriveOAuthConfig.webClientId,
    );
  }

  Future<GoogleSignInAccount?> restoreSession() async {
    await ensureInitialized();
    final future = GoogleSignIn.instance.attemptLightweightAuthentication();
    if (future != null) {
      _user = await future;
    }
    return _user;
  }

  Future<GoogleSignInAccount> signIn() async {
    await ensureInitialized();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw DriveBackupException(
        'Google Sign-In is not available on this device.',
      );
    }
    // Do not request Drive scopes during authenticate(). Combining them
    // often returns 403 access_denied when the consent screen is in Testing.
    _user = await GoogleSignIn.instance.authenticate();
    try {
      await _user!.authorizationClient.authorizeScopes(_scopes);
    } on GoogleSignInException catch (error) {
      throw DriveBackupException(describeDriveAuthError(error));
    }
    return _user!;
  }

  Future<void> signOut() async {
    await ensureInitialized();
    await GoogleSignIn.instance.signOut();
    _user = null;
  }

  Future<void> uploadBackup(EncodedBackup backup) async {
    await _withDrive((api) async {
      final folderId = await _ensureFolder(api);
      final bytes = utf8.encode(backup.content);
      final stamp = DateFormat('yyyy-MM-dd-HHmmss').format(DateTime.now());
      final metadata = drive.File()
        ..name = 'sossoldi-backup-$stamp.${backup.extension}'
        ..parents = [folderId]
        ..mimeType = backup.mimeType;
      final media = drive.Media(
        Stream<List<int>>.fromIterable([bytes]),
        bytes.length,
        contentType: backup.mimeType,
      );
      await api.files.create(metadata, uploadMedia: media);
    });
  }

  Future<List<DriveBackupFile>> listBackups() async {
    return _withDrive((api) async {
      final folderId = await _ensureFolder(api);
      final result = await api.files.list(
        q:
            "'$folderId' in parents and trashed = false and "
            "mimeType != 'application/vnd.google-apps.folder'",
        orderBy: 'modifiedTime desc',
        $fields: 'files(id, name, modifiedTime)',
        pageSize: 30,
      );
      return (result.files ?? [])
          .where((file) => file.id != null && file.name != null)
          .map(
            (file) => DriveBackupFile(
              id: file.id!,
              name: file.name!,
              modifiedTime: file.modifiedTime,
            ),
          )
          .toList();
    });
  }

  Future<String> downloadCsv(String fileId) async {
    return _withDrive((api) async {
      final media =
          await api.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;
      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    });
  }

  Future<T> _withDrive<T>(Future<T> Function(drive.DriveApi api) action) async {
    final user = _user ?? await restoreSession();
    if (user == null) {
      throw DriveBackupException('Sign in with Google first.');
    }
    GoogleSignInClientAuthorization authz;
    try {
      authz =
          await user.authorizationClient.authorizationForScopes(_scopes) ??
          await user.authorizationClient.authorizeScopes(_scopes);
    } on GoogleSignInException catch (error) {
      throw DriveBackupException(describeDriveAuthError(error));
    }
    final client = _GoogleAuthClient({
      'Authorization': 'Bearer ${authz.accessToken}',
      'X-Goog-AuthUser': '0',
    });
    try {
      return await action(drive.DriveApi(client));
    } finally {
      client.close();
    }
  }

  Future<String> _ensureFolder(drive.DriveApi api) async {
    final existing = await api.files.list(
      q:
          "name = '$_folderName' and mimeType = "
          "'application/vnd.google-apps.folder' and trashed = false",
      $fields: 'files(id, name)',
      pageSize: 1,
    );
    final files = existing.files;
    if (files != null && files.isNotEmpty && files.first.id != null) {
      return files.first.id!;
    }
    final created = await api.files.create(
      drive.File()
        ..name = _folderName
        ..mimeType = 'application/vnd.google-apps.folder',
    );
    final id = created.id;
    if (id == null) {
      throw DriveBackupException('Could not create the Sossoldi Drive folder.');
    }
    return id;
  }
}
