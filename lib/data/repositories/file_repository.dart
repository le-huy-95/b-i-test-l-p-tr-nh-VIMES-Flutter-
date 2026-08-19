import 'package:file_picker/file_picker.dart';
import 'package:test_y_app/data/datasources/api_services/file_api_service.dart';
import 'package:test_y_app/data/models/uploaded_file.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';

class FileRepositoryImpl implements FileRepository {
  FileRepositoryImpl({FileApiService? apiService}) : _api = apiService ?? FileApiService();

  final FileApiService _api;

  @override
  Future<UploadedFile> upload(PlatformFile file, {String kind = 'general'}) =>
      _api.upload(file, kind: kind);

  @override
  Future<UploadedFile> replace(String fileId, PlatformFile file, {String? kind}) =>
      _api.replace(fileId, file, kind: kind);
}
