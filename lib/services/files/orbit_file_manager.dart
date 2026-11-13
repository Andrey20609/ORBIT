import '../../data/database/orbit_data_engine.dart';
import '../../data/models/file_record.dart';

final class OrbitFileManager {
  OrbitFileManager({required OrbitDataEngine dataEngine})
      : _dataEngine = dataEngine;

  final OrbitDataEngine _dataEngine;

  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB limit

  Future<List<FileRecord>> getFiles({
    String? workspaceId,
    String? associatedEntityId,
  }) async {
    return _dataEngine.getFiles(
      workspaceId: workspaceId,
      associatedEntityId: associatedEntityId,
    );
  }

  Future<FileRecord> attachFile({
    required String fileName,
    required int sizeBytes,
    required String mimeType,
    String? localPath,
    String? remoteUri,
    String? associatedEntityType,
    String? associatedEntityId,
    String? workspaceId,
  }) async {
    if (sizeBytes > maxFileSizeBytes) {
      throw ArgumentError(
        'Файл превышает максимально допустимый размер 50 МБ ($sizeBytes байт)',
      );
    }

    final ext = fileName.contains('.') ? fileName.split('.').last : '';
    final id = 'file_${DateTime.now().millisecondsSinceEpoch}_${fileName.hashCode.abs()}';
    final now = DateTime.now();

    final record = FileRecord(
      id: id,
      workspaceId: workspaceId ?? _dataEngine.activeWorkspaceId,
      fileName: fileName,
      extension: ext,
      sizeBytes: sizeBytes,
      mimeType: mimeType,
      localPath: localPath,
      remoteUri: remoteUri,
      associatedEntityType: associatedEntityType,
      associatedEntityId: associatedEntityId,
      createdAt: now,
      updatedAt: now,
    );

    await _dataEngine.saveFile(record);
    return record;
  }

  Future<void> removeFile(String fileId) async {
    await _dataEngine.deleteFile(fileId);
  }

  Future<int> getTotalStorageUsed({String? workspaceId}) async {
    final files = await _dataEngine.getFiles(workspaceId: workspaceId);
    return files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
  }
}
