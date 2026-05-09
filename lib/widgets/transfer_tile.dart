import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/transfer.dart';

class TransferTile extends StatelessWidget {
  final Transfer transfer;

  const TransferTile({super.key, required this.transfer});

  IconData get _statusIcon {
    switch (transfer.status) {
      case TransferStatus.sending:
        return Icons.upload_rounded;
      case TransferStatus.receiving:
        return Icons.download_rounded;
      case TransferStatus.done:
        return transfer.savedPath != null
            ? Icons.download_done_rounded
            : Icons.check_circle_rounded;
      case TransferStatus.failed:
        return Icons.error_outline_rounded;
    }
  }

  Color get _statusColor {
    switch (transfer.status) {
      case TransferStatus.sending:
        return Colors.blue;
      case TransferStatus.receiving:
        return Colors.orange;
      case TransferStatus.done:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
    }
  }

  String get _statusLabel {
    switch (transfer.status) {
      case TransferStatus.sending:
        return 'Sending to ${transfer.peerName}';
      case TransferStatus.receiving:
        return 'Receiving from ${transfer.peerName}';
      case TransferStatus.done:
        return transfer.savedPath != null
            ? 'Received from ${transfer.peerName}'
            : 'Sent to ${transfer.peerName}';
      case TransferStatus.failed:
        return 'Failed';
    }
  }

  // Opens the folder containing the received file on every platform.
  static const _channel = MethodChannel('com.localshare/downloads');

  Future<void> _openFolder(String filePath) async {
    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod('openFolder');
      } catch (_) {}
    } else if (Platform.isIOS) {
      await launchUrl(Uri.parse('shareddocuments://'));
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isWindows) {
      final winPath = filePath.replaceAll('/', '\\');
      await Process.run('explorer', ['/select,$winPath'], runInShell: true);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [File(filePath).parent.path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool inProgress = transfer.status == TransferStatus.sending ||
        transfer.status == TransferStatus.receiving;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(_statusIcon, color: _statusColor, size: 22),
      ),
      title: Text(
        transfer.fileName,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_statusLabel • ${transfer.formattedSize}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          if (inProgress) ...[
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: transfer.progress,
              backgroundColor: Colors.grey[200],
              color: _statusColor,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ],
      ),
      trailing: transfer.status == TransferStatus.done &&
              transfer.savedPath != null
          ? IconButton(
              icon: const Icon(
                Icons.folder_open_rounded,
                color: Colors.blue,
                size: 20,
              ),
              tooltip: 'Show in folder',
              onPressed: () => _openFolder(transfer.savedPath!),
            )
          : null,
    );
  }
}
