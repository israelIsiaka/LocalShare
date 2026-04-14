import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
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

  // ─── Desktop: reveal the file's containing folder ───────────────────────

  Future<void> _openFolderDesktop(String filePath) async {
    final dir = File(filePath).parent.path;
    if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir]);
    }
  }

  // ─── Mobile: bottom sheet with location info + actions ──────────────────

  void _showMobileSheet(BuildContext context, String filePath) {
    final fileName = File(filePath).uri.pathSegments.last;
    final folderLabel = Platform.isAndroid
        ? 'Downloads → LocalShare'
        : 'Files app → LocalShare → LocalShare';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              fileName,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.folder_rounded, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    folderLabel,
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Open File — lets the OS pick the right app for this file type
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open File'),
                onPressed: () async {
                  Navigator.pop(sheetCtx);
                  final result = await OpenFilex.open(filePath);
                  if (result.type != ResultType.done && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No app installed to open this file type'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),

            if (Platform.isIOS) ...[
              const SizedBox(height: 10),
              // Open Files app — user can then browse to LocalShare folder
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Browse in Files App'),
                  onPressed: () async {
                    Navigator.pop(sheetCtx);
                    await launchUrl(Uri.parse('shareddocuments://'));
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
              onPressed: () {
                final path = transfer.savedPath!;
                if (Platform.isAndroid || Platform.isIOS) {
                  _showMobileSheet(context, path);
                } else {
                  _openFolderDesktop(path);
                }
              },
            )
          : null,
    );
  }
}
