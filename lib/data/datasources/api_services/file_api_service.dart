import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:test_y_app/data/datasources/api_endpoints.dart';
import 'package:test_y_app/data/datasources/api_services/base_api_service.dart';
import 'package:test_y_app/data/models/uploaded_file.dart';
import 'package:uuid/uuid.dart';

class FileApiService extends BaseApiService {
  static const _uuid = Uuid();

  UploadedFile _decodeOne(dynamic value) {
    if (value is Map<String, dynamic>) return UploadedFile.fromJson(value);
    return UploadedFile.fromJson(Map<String, dynamic>.from(value as Map));
  }

  Future<UploadedFile> upload(
    PlatformFile file, {
    String kind = 'general',
  }) async {
    final path = file.path;
    if (path == null) {
      throw Exception('Không đọc được đường dẫn file');
    }
    final mime = lookupMimeType(path) ?? 'application/octet-stream';
    final formData = FormData.fromMap({
      'kind': kind,
      'file': await MultipartFile.fromFile(
        path,
        filename: file.name,
        contentType: MediaType.parse(mime),
      ),
    });

    final response = await postMultipartRequest<UploadedFile>(
      ApiEndpoints.files,
      headers: {'Idempotency-Key': _uuid.v4()},
      formData: formData,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(response.error ?? response.message ?? 'Upload file thất bại');
    }
    return response.data!;
  }

  Future<UploadedFile> replace(
    String fileId,
    PlatformFile file, {
    String? kind,
  }) async {
    final path = file.path;
    if (path == null) {
      throw Exception('Không đọc được đường dẫn file');
    }
    final mime = lookupMimeType(path) ?? 'application/octet-stream';
    final formData = FormData.fromMap({
      'kind': kind,
      'file': await MultipartFile.fromFile(
        path,
        filename: file.name,
        contentType: MediaType.parse(mime),
      ),
    });

    final response = await putMultipartRequest<UploadedFile>(
      '${ApiEndpoints.files}/$fileId',
      headers: {'Idempotency-Key': _uuid.v4()},
      formData: formData,
      decode: _decodeOne,
    );
    if (!response.success || response.data == null) {
      throw Exception(
        response.error ?? response.message ?? 'Cập nhật file thất bại',
      );
    }
    return response.data!;
  }

}
