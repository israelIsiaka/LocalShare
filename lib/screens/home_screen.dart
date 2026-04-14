import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/device.dart';
import '../services/discovery_service.dart';
import '../services/transfer_service.dart';
import '../widgets/device_card.dart';
import '../widgets/transfer_tile.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _sendFiles(
      BuildContext context, Device device, String senderName) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,       // never load file bytes into memory
      withReadStream: false, // we open our own stream in TransferService
    );
    if (result == null || result.files.isEmpty) return;
    if (!context.mounted) return;

    final transferService = context.read<TransferService>();
    final validFiles = result.files.where((file) => file.path != null).toList();

    if (validFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid files selected'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show progress dialog for multiple files
    if (validFiles.length > 1 && context.mounted) {
      _showMultiFileProgressDialog(context, device, validFiles, senderName);
      return;
    }

    // Single file - send directly
    int sent = 0;
    int failed = 0;

    for (final file in validFiles) {
      final path = file.path!;
      try {
        await transferService.sendFile(
          target: device,
          filePath: path,
          senderName: senderName,
        );
        sent++;
      } catch (_) {
        failed++;
      }
    }

    if (!context.mounted) return;
    final total = sent + failed;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failed == 0
            ? (total == 1
                ? 'File sent to ${device.name}'
                : '$total files sent to ${device.name}')
            : '$sent/$total sent to ${device.name}'),
        backgroundColor: failed == 0 ? Colors.green : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMultiFileProgressDialog(
      BuildContext context, Device device, List<PlatformFile> files, String senderName) {
    int completed = 0;
    int failed = 0;
    bool isCancelled = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final total = files.length;
            final progress = total > 0 ? (completed + failed) / total : 0.0;

            return AlertDialog(
              title: Text('Sending $total files to ${device.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      failed > 0 ? Colors.orange : Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$completed of $total completed${failed > 0 ? ', $failed failed' : ''}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (progress < 1.0) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Sending files...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              actions: [
                if (progress < 1.0)
                  TextButton(
                    onPressed: () {
                      isCancelled = true;
                      Navigator.pop(dialogContext);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Cancel'),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Done'),
                  ),
              ],
            );
          },
        );
      },
    );

    // Start sending files concurrently
    _sendFilesConcurrently(
      context,
      device,
      files,
      senderName,
      (completedCount, failedCount) {
        if (isCancelled) return;
        setState(() {
          completed = completedCount;
          failed = failedCount;
        });
      },
      () {
        if (isCancelled) return;
        // Dialog will be closed by the Done button
      },
    );
  }

  Future<void> _sendFilesConcurrently(
      BuildContext context,
      Device device,
      List<PlatformFile> files,
      String senderName,
      Function(int completed, int failed) onProgress,
      Function() onComplete) async {
    final transferService = context.read<TransferService>();
    int completed = 0;
    int failed = 0;

    // Send files concurrently with limited parallelism to avoid overwhelming the network
    final futures = files.map((file) async {
      final path = file.path!;
      try {
        await transferService.sendFile(
          target: device,
          filePath: path,
          senderName: senderName,
        );
        completed++;
        onProgress(completed, failed);
      } catch (_) {
        failed++;
        onProgress(completed, failed);
      }
    });

    // Wait for all transfers to complete
    await Future.wait(futures);
    onComplete();
  }

  void _showSendDialog(BuildContext context, Device device) {
    final discovery = context.read<DiscoveryService>();
    final senderName = discovery.deviceName ?? discovery.deviceId ?? 'This Device';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send to ${device.name}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              device.ip,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Choose Files & Send'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _sendFiles(context, device, senderName);
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.swap_horiz_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'LocalShare',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87),
            ),
          ],
        ),
        actions: [
          Consumer<DiscoveryService>(
            builder: (_, discovery, _) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Chip(
                avatar: Icon(
                  Icons.wifi_rounded,
                  size: 16,
                  color: discovery.localIp != null
                      ? Colors.green
                      : Colors.grey,
                ),
                label: Text(
                  discovery.localIp ?? 'No Network',
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.grey[100],
              ),
            ),
          ),
          PopupMenuButton<_AppMenuItem>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black87),
            onSelected: (item) {
              switch (item) {
                case _AppMenuItem.share:
                  Share.share(
                    'Check out LocalShare — fast, private file sharing over your local WiFi. '
                    'No internet, no accounts, no cloud.\n'
                    'https://github.com/israelIsiaka/LocalShare',
                    subject: 'LocalShare – Local File Sharing',
                  );
                case _AppMenuItem.about:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AboutScreen()),
                  );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _AppMenuItem.share,
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 18, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Share App'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AppMenuItem.about,
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('About'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Nearby Devices',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const Spacer(),
                  Consumer<DiscoveryService>(
                    builder: (_, discovery, _) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${discovery.devices.length} online',
                        style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Consumer<DiscoveryService>(
            builder: (_, discovery, _) {
              final devices = discovery.devices;

              if (devices.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.devices_other_rounded,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'Looking for devices...',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Make sure other devices are on the\nsame WiFi network',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => DeviceCard(
                    device: devices[i],
                    onTap: () => _showSendDialog(context, devices[i]),
                  ),
                  childCount: devices.length,
                ),
              );
            },
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Transfers',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),

          Consumer<TransferService>(
            builder: (_, transferService, _) {
              final transfers = transferService.transfers;

              if (transfers.isEmpty) {
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.history_rounded,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          'No transfers yet',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap a device above to send files',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TransferTile(transfer: transfers[i]),
                  ),
                  childCount: transfers.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

enum _AppMenuItem { share, about }
