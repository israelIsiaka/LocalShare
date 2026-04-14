class Device {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String platform;
  DateTime lastSeen;

  Device({
    required this.id,
    required this.name,
    required this.ip,
    required this.port,
    required this.platform,
    required this.lastSeen,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int,
      platform: json['platform'] as String,
      lastSeen: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ip': ip,
        'port': port,
        'platform': platform,
      };

  String get address => 'http://$ip:$port';

  bool get isStale =>
      DateTime.now().difference(lastSeen).inSeconds > 10;
}
