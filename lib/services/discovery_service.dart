import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/device.dart';

const int _discoveryPort = 55124;
const int _transferPort = 55123;

class DiscoveryService extends ChangeNotifier {
  final Map<String, Device> _devices = {};
  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  Timer? _broadcastTimer;
  Timer? _pruneTimer;
  String? _localIp;
  String? _deviceId;
  String? _deviceName;
  String? _platform;
  bool _isRunning = false;

  List<Device> get devices =>
      _devices.values.where((d) => !d.isStale).toList();
  String? get localIp => _localIp;
  String? get deviceId => _deviceId;
  String? get deviceName => _deviceName;

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    await _initDeviceInfo();
    await _initLocalIp();

    try {
      // On macOS, binding to anyIPv4 with broadcast enabled works better
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
      );
      _socket!.broadcastEnabled = true;
      _socketSubscription = _socket!.listen(_onData);

      _broadcastTimer =
          Timer.periodic(const Duration(seconds: 3), (_) => _broadcast());
      _pruneTimer =
          Timer.periodic(const Duration(seconds: 5), (_) => _pruneStale());

      notifyListeners();
      _broadcast();
    } catch (e) {
      debugPrint('Discovery bind error: $e');
    }
  }

  void stop() {
    _isRunning = false;
    _broadcastTimer?.cancel();
    _pruneTimer?.cancel();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
  }

  Future<void> _initDeviceInfo() async {
    final info = DeviceInfoPlugin();
    _platform = Platform.operatingSystem;

    if (Platform.isAndroid) {
      final d = await info.androidInfo;
      _deviceName = d.model;
      _deviceId = d.id;
    } else if (Platform.isIOS) {
      final d = await info.iosInfo;
      _deviceName = d.name;
      _deviceId = d.identifierForVendor ?? 'ios-unknown';
    } else if (Platform.isMacOS) {
      final d = await info.macOsInfo;
      _deviceName = d.computerName;
      _deviceId = d.systemGUID ?? 'mac-unknown';
    } else if (Platform.isWindows) {
      final d = await info.windowsInfo;
      _deviceName = d.computerName;
      _deviceId = d.deviceId;
    } else {
      _deviceName = 'Linux Device';
      _deviceId = 'linux-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _initLocalIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip != null && ip.isNotEmpty) _localIp = ip;
    } catch (_) {}

    // Fallback: enumerate interfaces, prefer private LAN addresses
    if (_localIp == null || _localIp!.isEmpty) {
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLoopback: false,
        );
        String? firstNonLoopback;
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            if (addr.isLoopback) continue;
            final a = addr.address;
            // Prefer private LAN ranges (192.168.x.x, 10.x.x.x, 172.16-31.x.x)
            if (a.startsWith('192.168.') ||
                a.startsWith('10.') ||
                RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(a)) {
              _localIp = a;
              notifyListeners();
              return;
            }
            firstNonLoopback ??= a;
          }
        }
        // Use whatever we found if no LAN address matched
        if (firstNonLoopback != null) {
          _localIp = firstNonLoopback;
        }
      } catch (e) {
        debugPrint('IP detection error: $e');
      }
    }

    notifyListeners();
  }

  void _broadcast() {
    if (_socket == null || _localIp == null) return;

    final payload = jsonEncode({
      'id': _deviceId,
      'name': _deviceName,
      'ip': _localIp,
      'port': _transferPort,
      'platform': _platform,
    });

    // Calculate subnet broadcast address
    final broadcastAddr = _getSubnetBroadcast(_localIp!);

    try {
      _socket!.send(
        utf8.encode(payload),
        InternetAddress(broadcastAddr),
        _discoveryPort,
      );
    } catch (e) {
      debugPrint('Broadcast error: $e');
    }
  }

  String _getSubnetBroadcast(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length == 4) {
        // For 192.168.1.x networks, broadcast is 192.168.1.255
        // For 10.x.x.x networks, broadcast is 10.255.255.255
        // For 172.16-31.x.x networks, broadcast is 172.x.255.255
        final first = int.parse(parts[0]);
        final second = int.parse(parts[1]);

        if (first == 192 && second == 168) {
          return '${parts[0]}.${parts[1]}.${parts[2]}.255';
        } else if (first == 10) {
          return '10.255.255.255';
        } else if (first == 172 && second >= 16 && second <= 31) {
          return '172.${parts[1]}.255.255';
        }
      }
    } catch (e) {
      debugPrint('Discovery: Error calculating broadcast address: $e');
    }

    // Fallback to global broadcast
    return '255.255.255.255';
  }

  void _onData(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;

    try {
      final json = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      final incoming = Device.fromJson(json);

      // Ignore ourselves
      if (incoming.id == _deviceId) return;

      if (_devices.containsKey(incoming.id)) {
        _devices[incoming.id]!.lastSeen = DateTime.now();
      } else {
        _devices[incoming.id] = incoming;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Parse discovery packet error: $e');
    }
  }

  void _pruneStale() {
    final before = _devices.length;
    _devices.removeWhere((_, d) => d.isStale);
    if (_devices.length != before) notifyListeners();
  }
}
