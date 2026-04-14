enum TransferStatus { sending, receiving, done, failed }

class Transfer {
  final String id;
  final String fileName;
  final int fileSize;
  final String peerName;
  final TransferStatus status;
  final double progress;
  final String? savedPath;
  final DateTime timestamp;

  Transfer({
    required this.id,
    required this.fileName,
    required this.fileSize,
    required this.peerName,
    required this.status,
    this.progress = 0,
    this.savedPath,
    required this.timestamp,
  });

  Transfer copyWith({
    TransferStatus? status,
    double? progress,
    String? savedPath,
  }) {
    return Transfer(
      id: id,
      fileName: fileName,
      fileSize: fileSize,
      peerName: peerName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      savedPath: savedPath ?? this.savedPath,
      timestamp: timestamp,
    );
  }

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
