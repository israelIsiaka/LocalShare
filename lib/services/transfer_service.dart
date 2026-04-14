import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/device.dart';
import '../models/transfer.dart';

class TransferService extends ChangeNotifier {
  final List<Transfer> _transfers = [];

  List<Transfer> get transfers => List.unmodifiable(_transfers);

  /// Adds a new incoming transfer (receiving status) and returns its id.
  String addIncoming(Transfer transfer) {
    _transfers.insert(0, transfer);
    notifyListeners();
    return transfer.id;
  }

  /// Updates progress / status of any transfer by id.
  void updateTransfer(String id,
      {TransferStatus? status, double? progress, String? savedPath}) {
    final idx = _transfers.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    _transfers[idx] = _transfers[idx].copyWith(
      status: status,
      progress: progress,
      savedPath: savedPath,
    );
    notifyListeners();
  }

  Future<void> sendFile({
    required Device target,
    required String filePath,
    required String senderName,
    Function(double)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found: $filePath');

    final fileName = file.uri.pathSegments.last;
    final fileSize = await file.length();

    final transfer = Transfer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      fileSize: fileSize,
      peerName: target.name,
      status: TransferStatus.sending,
      progress: 0,
      timestamp: DateTime.now(),
    );

    _transfers.insert(0, transfer);
    notifyListeners();

    final client = http.Client();
    try {
      final uri = Uri.parse('${target.address}/upload');
      final request = http.StreamedRequest('POST', uri)
        ..headers['content-type'] = 'application/octet-stream'
        ..headers['content-length'] = fileSize.toString()
        ..headers['x-filename'] = Uri.encodeComponent(fileName)
        ..headers['x-sender-name'] = senderName;

      // Open connection first so back-pressure comes from the network socket,
      // not a local buffer.
      final responseFuture = client.send(request);

      // Stream file → request body, throttling UI updates to avoid flooding
      // the main thread (every 65 KB chunk would cause thousands of rebuilds).
      int bytesSent = 0;
      double lastNotified = -1;
      int lastNotifyMs = 0;

      await request.sink.addStream(
        file.openRead().map((chunk) {
          bytesSent += chunk.length;
          final progress = (bytesSent / fileSize).clamp(0.0, 0.95);
          final nowMs = DateTime.now().millisecondsSinceEpoch;
          // Only rebuild UI when progress moves ≥1% OR every 300 ms
          if (progress - lastNotified >= 0.01 || nowMs - lastNotifyMs >= 300) {
            lastNotified = progress;
            lastNotifyMs = nowMs;
            onProgress?.call(progress);
            updateTransfer(transfer.id,
                status: TransferStatus.sending, progress: progress);
          }
          return chunk;
        }),
      );
      await request.sink.close();

      final response = await responseFuture;
      await response.stream.drain<void>();

      if (response.statusCode == 200) {
        updateTransfer(transfer.id,
            status: TransferStatus.done, progress: 1.0);
        onProgress?.call(1.0);
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Send error: $e');
      updateTransfer(transfer.id, status: TransferStatus.failed, progress: 0);
      rethrow;
    } finally {
      client.close();
    }
  }
}
