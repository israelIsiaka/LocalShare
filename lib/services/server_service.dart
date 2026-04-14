import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../models/transfer.dart';

const int _transferPort = 55123;
const _downloadsChannel = MethodChannel('com.localshare/downloads');

class ServerService {
  HttpServer? _server;

  int get port => _server?.port ?? _transferPort;

  /// Called once when a transfer starts (status = receiving, progress = 0).
  void Function(Transfer transfer)? onTransferStart;

  /// Called repeatedly as bytes arrive.
  void Function(String id, double progress)? onTransferProgress;

  /// Called when the file is fully saved.
  void Function(Transfer transfer)? onTransferComplete;

  /// Return true to accept, false to decline.
  /// If null, all transfers are auto-accepted.
  Future<bool> Function(String fileName, int fileSize, String senderName)?
      onTransferConfirmation;

  Future<void> start() async {
    final router = Router();
    router.post('/upload', _handleUpload);
    router.get('/ping', (_) => Response.ok('pong'));

    final handler =
        Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    // Try multiple ports in case the default is in use
    const maxAttempts = 10;
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final port = _transferPort + attempt;
      try {
        _server = await shelf_io.serve(
          handler,
          InternetAddress.anyIPv4,
          port,
        );
        debugPrint('File server running on port $port');
        return; // Success, exit the loop
      } catch (e) {
        debugPrint('Server start error on port $port: $e');
        if (attempt == maxAttempts - 1) {
          debugPrint('Failed to start server after $maxAttempts attempts');
        }
      }
    }
  }

  Future<Response> _handleUpload(Request request) async {
    // --- Sanitize sender name (prevent long strings reaching the UI) ---
    final rawSender = request.headers['x-sender-name'] ?? 'Unknown';
    final senderName = rawSender.length > 64
        ? rawSender.substring(0, 64)
        : rawSender;

    final encodedName = request.headers['x-filename'];
    if (encodedName == null || encodedName.isEmpty) {
      return Response.badRequest(body: 'Missing x-filename header');
    }

    // --- Sanitize filename: prevent path traversal attacks ---
    final fileName = _sanitizeFileName(encodedName);

    final contentLength =
        int.tryParse(request.headers['content-length'] ?? '');

    // --- Ask the user whether to accept this transfer ---
    if (onTransferConfirmation != null) {
      final approved = await onTransferConfirmation!(
          fileName, contentLength ?? 0, senderName);
      if (!approved) {
        await request.read().drain<void>(); // consume body so sender doesn't hang
        return Response.forbidden('Transfer declined');
      }
    }

    final transferId = DateTime.now().millisecondsSinceEpoch.toString();

    onTransferStart?.call(Transfer(
      id: transferId,
      fileName: fileName,
      fileSize: contentLength ?? 0,
      peerName: senderName,
      status: TransferStatus.receiving,
      progress: 0,
      timestamp: DateTime.now(),
    ));

    try {
      String savedPath = await _streamToFile(
        fileName,
        transferId,
        contentLength,
        request.read(),
      );

      // On Android, move the file from app-specific storage to the public
      // Downloads/LocalShare folder so it's visible in the Files app.
      if (Platform.isAndroid) {
        try {
          final publicPath = await _downloadsChannel.invokeMethod<String>(
            'publishToDownloads',
            {'path': savedPath, 'fileName': fileName},
          );
          if (publicPath != null && publicPath.isNotEmpty) {
            savedPath = publicPath;
          }
        } catch (e) {
          debugPrint('publishToDownloads error (keeping original path): $e');
        }
      }

      final fileSize = await File(savedPath).length();
      final completed = Transfer(
        id: transferId,
        fileName: fileName,
        fileSize: fileSize,
        peerName: senderName,
        status: TransferStatus.done,
        progress: 1.0,
        savedPath: savedPath,
        timestamp: DateTime.now(),
      );

      onTransferComplete?.call(completed);
      return Response.ok('File received');
    } catch (e) {
      debugPrint('Upload handler error: $e');
      return Response.internalServerError(body: 'Upload failed: $e');
    }
  }

  /// Strips path separators and control characters so a crafted filename
  /// like `../../.bashrc` cannot escape the save directory.
  String _sanitizeFileName(String raw) {
    final decoded = Uri.decodeComponent(raw);
    // Keep only the final path component
    final basename = decoded.split(RegExp(r'[/\\]')).last;
    // Remove null bytes and ASCII control characters
    final clean =
        basename.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
    return clean.isEmpty ? 'received_file' : clean;
  }

  /// Streams body directly to disk — no full-file buffering.
  /// Also throttles progress callbacks to avoid flooding the UI thread.
  Future<String> _streamToFile(
    String fileName,
    String transferId,
    int? contentLength,
    Stream<List<int>> stream,
  ) async {
    final dir = await _receiveDirectory();
    final savePath = await _uniquePath(dir, fileName);

    try {
      final sink = File(savePath).openWrite();
      int bytesReceived = 0;
      double lastNotified = -1;
      int lastNotifyMs = 0;

      try {
        await sink.addStream(
          stream.map((chunk) {
            bytesReceived += chunk.length;
            if (contentLength != null && contentLength > 0) {
              final progress =
                  (bytesReceived / contentLength).clamp(0.0, 0.99);
              final nowMs = DateTime.now().millisecondsSinceEpoch;
              if (progress - lastNotified >= 0.01 ||
                  nowMs - lastNotifyMs >= 300) {
                lastNotified = progress;
                lastNotifyMs = nowMs;
                onTransferProgress?.call(transferId, progress);
              }
            }
            return chunk;
          }),
        );
      } finally {
        await sink.close();
      }

      debugPrint('Saved file to $savePath');
      return savePath;
    } catch (e) {
      debugPrint('Failed to save file to $savePath: $e');
      // Try to clean up the partially written file
      try {
        final file = File(savePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  Future<Directory> _receiveDirectory() async {
    Directory dir;
    if (Platform.isAndroid) {
      // Use Downloads directory for better visibility and accessibility
      // This makes received files visible in the Downloads folder in file managers
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        dir = Directory('${downloads.path}/LocalShare');
      } else {
        // Fallback to app-specific external storage
        final ext = await getExternalStorageDirectory();
        final base = ext ?? await getApplicationDocumentsDirectory();
        dir = Directory('${base.path}/LocalShare');
      }
    } else if (Platform.isIOS) {
      final base = await getApplicationDocumentsDirectory();
      dir = Directory('${base.path}/LocalShare');
    } else {
      final downloads = await getDownloadsDirectory();
      dir = Directory('${downloads!.path}/LocalShare');
    }

    // Create directory if it doesn't exist, or use existing one
    // This handles both fresh installs and reinstalls gracefully
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint('Created LocalShare directory: ${dir.path}');
    } else {
      debugPrint('Using existing LocalShare directory: ${dir.path}');
      // Check if directory has existing files
      try {
        final files = await dir.list().length;
        if (files > 0) {
          debugPrint('LocalShare directory contains $files existing items');
        }
      } catch (e) {
        debugPrint('Could not list existing files in LocalShare directory: $e');
      }
    }

    // Verify we can write to the directory
    try {
      final testFile = File('${dir.path}/.localshare_test');
      await testFile.writeAsString('test');
      await testFile.delete();
      debugPrint('LocalShare directory is writable');
    } catch (e) {
      debugPrint('Warning: LocalShare directory may not be writable: $e');
      // Continue anyway - the actual file write will fail with a proper error
    }

    return dir;
  }

  Future<String> _uniquePath(Directory dir, String fileName) async {
    final ext =
        fileName.contains('.') ? '.${fileName.split('.').last}' : '';
    final base = ext.isNotEmpty
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    String path = '${dir.path}/$fileName';
    int count = 1;
    while (await File(path).exists()) {
      path = '${dir.path}/${base}_$count$ext';
      count++;
    }
    return path;
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
  }
}
