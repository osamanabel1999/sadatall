import 'dart:io';
import 'dart:typed_data';
import 'package:minio/minio.dart';
import 'package:path/path.dart' as path;
import '../constants/app_constants.dart';

class WasabiService {
  static final WasabiService _instance = WasabiService._internal();
  factory WasabiService() => _instance;
  WasabiService._internal();

  Minio? _minioClient;

  Minio get _client {
    if (_minioClient == null) {
      final endpointUri = Uri.parse(AppConstants.wasabiEndpoint);
      _minioClient = Minio(
        endPoint: "s3.${AppConstants.wasabiRegion}.wasabisys.com",
        accessKey: AppConstants.wasabiAccessKey,
        secretKey: AppConstants.wasabiSecretKey,
        useSSL: endpointUri.scheme == 'https',
        region: AppConstants.wasabiRegion,
      );
    }
    return _minioClient!;
  }

  /// Upload a file to Wasabi S3.
  /// Returns the S3 path (not presigned URL) on success, or throws with the
  /// real reason on failure — callers must not treat a null/absent result
  /// as "no attachment," since that silently drops the upload with zero
  /// feedback to the user.
  Future<String> uploadFile({
    required File file,
    required String fileName,
  }) async {
    final String objectName = 'order-attachments/$fileName';
    final String contentType = _getContentType(fileName);

    final bytes = await file.readAsBytes();
    final uint8list = Uint8List.fromList(bytes);
    final stream = Stream<Uint8List>.value(uint8list);

    // putObject itself throws on any S3/network/auth failure, so reaching
    // the return below means the upload genuinely succeeded.
    await _client.putObject(
      AppConstants.wasabiBucket,
      objectName,
      stream,
      size: bytes.length,
      metadata: {'Content-Type': contentType},
    );

    return objectName;
  }

  /// Generate a unique filename for attachments
  String generateFileName({
    required String orderId,
    required String extension,
    int? index,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    if (index != null) {
      return '${timestamp}_$index.$extension';
    }
    return '$timestamp.$extension';
  }

  /// Get content type based on file extension
  String _getContentType(String fileName) {
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.m4a':
        return 'audio/m4a';
      case '.aac':
        return 'audio/aac';
      case '.mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
