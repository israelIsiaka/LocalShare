import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'models/transfer.dart';
import 'screens/home_screen.dart';
import 'services/discovery_service.dart';
import 'services/server_service.dart';
import 'services/transfer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const LocalShareApp());
}

class LocalShareApp extends StatelessWidget {
  const LocalShareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DiscoveryService()),
        ChangeNotifierProvider(create: (_) => TransferService()),
        Provider(create: (_) => ServerService()),
      ],
      child: MaterialApp(
        title: 'LocalShare',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
        ),
        home: const _AppInit(),
      ),
    );
  }
}

class _AppInit extends StatefulWidget {
  const _AppInit();

  @override
  State<_AppInit> createState() => _AppInitState();
}

class _AppInitState extends State<_AppInit> {
  @override
  void initState() {
    super.initState();
    // Fire and forget — errors are caught inside _init and shown to the user.
    _init();
  }

  Future<void> _init() async {
    final discovery = context.read<DiscoveryService>();
    final server = context.read<ServerService>();
    final transfers = context.read<TransferService>();

    server.onTransferConfirmation = _confirmTransfer;

    server.onTransferStart = (Transfer transfer) {
      if (!mounted) return;
      transfers.addIncoming(transfer);
    };

    server.onTransferProgress = (String id, double progress) {
      if (!mounted) return;
      transfers.updateTransfer(id, progress: progress);
    };

    server.onTransferComplete = (Transfer transfer) {
      if (!mounted) return;
      transfers.updateTransfer(
        transfer.id,
        status: TransferStatus.done,
        progress: 1.0,
        savedPath: transfer.savedPath,
      );
      _showIncomingBanner(transfer);
    };

    try {
      await Future.wait([
        discovery.start(),
        server.start(),
      ]);
    } catch (e) {
      if (!mounted) return;
      _showStartupError(e);
    }
  }

  void _showStartupError(Object error) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Startup Error'),
        content: Text(
          'LocalShare could not start its network services.\n\n'
          'Make sure no other app is using the same ports (55123 / 55124) '
          'and try restarting the app.\n\nDetails: $error',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _init(); // retry
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmTransfer(
      String fileName, int fileSize, String senderName) async {
    if (!mounted) return false;
    final isLarge = fileSize > 2 * 1024 * 1024 * 1024; // > 2 GB
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Incoming File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$senderName wants to send:'),
            const SizedBox(height: 10),
            Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              _formatSize(fileSize),
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            if (isLarge) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This file is over 2 GB. Make sure you have enough storage.',
                      style: TextStyle(
                          color: Colors.orange[800], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    return approved ?? false;
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return 'Unknown size';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showIncomingBanner(Transfer transfer) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Saved "${transfer.fileName}" from ${transfer.peerName}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: transfer.savedPath != null
            ? SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () => _openSavedFile(transfer.savedPath!),
              )
            : null,
      ),
    );
  }

  Future<void> _openSavedFile(String filePath) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await OpenFilex.open(filePath);
      } else if (Platform.isMacOS) {
        await Process.run('open', [filePath]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', filePath]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [File(filePath).parent.path]);
      }
    } catch (_) {
      // Best-effort — if it fails the user can still find the file in the
      // transfer list and tap the folder button there.
    }
  }

  @override
  void dispose() {
    context.read<DiscoveryService>().stop();
    context.read<ServerService>().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
