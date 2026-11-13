import 'package:flutter/foundation.dart';

@immutable
final class FileRecord {
  const FileRecord({
    required this.id,
    required this.workspaceId,
    required this.fileName,
    required this.extension,
    required this.sizeBytes,
    required this.mimeType,
    this.localPath,
    this.remoteUri,
    this.associatedEntityType,
    this.associatedEntityId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String fileName;
  final String extension;
  final int sizeBytes;
  final String mimeType;
  final String? localPath;
  final String? remoteUri;
  final String? associatedEntityType; // 'email', 'event', 'task', 'note'
  final String? associatedEntityId;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes Б';
    if (sizeBytes < 1024 * 1024) {
      final kb = sizeBytes / 1024;
      return '${kb.toStringAsFixed(1).replaceAll('.', ',')} КБ';
    }
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1).replaceAll('.', ',')} МБ';
  }

  bool get isPdf => extension.toLowerCase() == 'pdf' || mimeType == 'application/pdf';
  bool get isSpreadsheet =>
      extension.toLowerCase() == 'xlsx' ||
      extension.toLowerCase() == 'xls' ||
      mimeType.contains('spreadsheet') ||
      mimeType.contains('excel');
  bool get isImage =>
      ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(extension.toLowerCase()) ||
      mimeType.startsWith('image/');
  bool get isDocument =>
      ['doc', 'docx', 'txt', 'md', 'pdf'].contains(extension.toLowerCase());

  Map<String, Object?> toMap() => {
    'id': id,
    'workspace_id': workspaceId,
    'file_name': fileName,
    'extension': extension,
    'size_bytes': sizeBytes,
    'mime_type': mimeType,
    'local_path': localPath,
    'remote_uri': remoteUri,
    'associated_entity_type': associatedEntityType,
    'associated_entity_id': associatedEntityId,
    'created_at': createdAt.millisecondsSinceEpoch,
    'updated_at': updatedAt.millisecondsSinceEpoch,
  };

  factory FileRecord.fromMap(Map<String, Object?> map) {
    return FileRecord(
      id: map['id']! as String,
      workspaceId: (map['workspace_id'] as String?) ?? 'workspace-work',
      fileName: (map['file_name'] as String?) ?? '',
      extension: (map['extension'] as String?) ?? '',
      sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
      mimeType: (map['mime_type'] as String?) ?? 'application/octet-stream',
      localPath: map['local_path'] as String?,
      remoteUri: map['remote_uri'] as String?,
      associatedEntityType: map['associated_entity_type'] as String?,
      associatedEntityId: map['associated_entity_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  FileRecord copyWith({
    String? id,
    String? workspaceId,
    String? fileName,
    String? extension,
    int? sizeBytes,
    String? mimeType,
    String? localPath,
    String? remoteUri,
    String? associatedEntityType,
    String? associatedEntityId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FileRecord(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      fileName: fileName ?? this.fileName,
      extension: extension ?? this.extension,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      remoteUri: remoteUri ?? this.remoteUri,
      associatedEntityType: associatedEntityType ?? this.associatedEntityType,
      associatedEntityId: associatedEntityId ?? this.associatedEntityId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
