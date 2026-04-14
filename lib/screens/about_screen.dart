import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
        _buildNumber = info.buildNumber;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareApp() {
    Share.share(
      'Check out LocalShare — fast, private file sharing over your local WiFi network. '
      'No internet required, no accounts, no cloud. '
      'Get it at: https://github.com/localshare-app/localshare',
      subject: 'LocalShare – Local File Sharing App',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'About',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // --- App identity ---
          Center(
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'LocalShare',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  _version.isNotEmpty
                      ? 'Version $_version (build $_buildNumber)'
                      : 'Version 1.0.0',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Fast. Private. Local.',
                    style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- Description ---
          _Card(
            child: const Text(
              'LocalShare lets you send files between devices on the same WiFi network '
              'instantly — no internet, no accounts, no cloud. Just fast, private transfers '
              'that stay entirely on your local network.',
              style: TextStyle(
                  color: Colors.black87, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // --- Features ---
          _SectionHeader(title: 'Features'),
          _Card(
            child: Column(
              children: const [
                _FeatureRow(
                  icon: Icons.wifi_rounded,
                  color: Colors.blue,
                  title: 'LAN Discovery',
                  description: 'Automatically finds devices on your network',
                ),
                Divider(height: 1),
                _FeatureRow(
                  icon: Icons.bolt_rounded,
                  color: Colors.orange,
                  title: 'Fast Streaming',
                  description:
                      'Files stream directly — no memory buffering, no size limits',
                ),
                Divider(height: 1),
                _FeatureRow(
                  icon: Icons.lock_rounded,
                  color: Colors.green,
                  title: 'Accept / Decline',
                  description: 'You approve every incoming transfer before it saves',
                ),
                Divider(height: 1),
                _FeatureRow(
                  icon: Icons.folder_open_rounded,
                  color: Colors.purple,
                  title: 'Easy Access',
                  description: 'Tap any received file to open its folder',
                ),
                Divider(height: 1),
                _FeatureRow(
                  icon: Icons.devices_rounded,
                  color: Colors.teal,
                  title: 'Cross-Platform',
                  description: 'iOS, Android, macOS, and Windows',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- How it works ---
          _SectionHeader(title: 'How It Works'),
          _Card(
            child: Column(
              children: const [
                _StepRow(number: '1', text: 'Open LocalShare on both devices'),
                SizedBox(height: 10),
                _StepRow(number: '2', text: 'Tap the device you want to send to'),
                SizedBox(height: 10),
                _StepRow(number: '3', text: 'Choose one or more files'),
                SizedBox(height: 10),
                _StepRow(
                    number: '4',
                    text: 'Receiver accepts — file saves instantly'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Developer ---
          _SectionHeader(title: 'Developer'),
          _Card(
            child: Column(
              children: [
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(0xFF1565C0),
                    child: Icon(Icons.person_rounded,
                        color: Colors.white, size: 20),
                  ),
                  title: Text(
                    'LocalShare Team',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Built with Flutter',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _LinkButton(
                        icon: Icons.code_rounded,
                        label: 'Source Code',
                        onTap: () => _launchUrl(
                            'https://github.com/localshare-app/localshare'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LinkButton(
                        icon: Icons.bug_report_rounded,
                        label: 'Report Issue',
                        onTap: () => _launchUrl(
                            'https://github.com/localshare-app/localshare/issues'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Share & legal ---
          _SectionHeader(title: 'Share & Legal'),
          _Card(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.share_rounded,
                        color: Colors.blue, size: 20),
                  ),
                  title: const Text('Share LocalShare',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                  subtitle: const Text('Tell a friend about the app',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Colors.grey),
                  onTap: _shareApp,
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.privacy_tip_rounded,
                        color: Colors.grey, size: 20),
                  ),
                  title: const Text('Privacy Policy',
                      style: TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 14)),
                  subtitle: const Text('No data leaves your network',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Colors.grey),
                  onTap: () => _launchUrl(
                      'https://github.com/localshare-app/localshare#privacy'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- Footer ---
          Center(
            child: Text(
              'Made with \u2665 using Flutter',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '\u00a9 ${DateTime.now().year} LocalShare. All rights reserved.',
              style: TextStyle(color: Colors.grey[400], fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            letterSpacing: 0.3),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _FeatureRow(
      {required this.icon,
      required this.color,
      required this.title,
      required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 1),
                Text(description,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ),
      ],
    );
  }
}

class _LinkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
