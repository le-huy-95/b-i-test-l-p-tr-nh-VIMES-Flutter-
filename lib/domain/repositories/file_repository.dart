import 'package:file_picker/file_picker.dart';
import 'package:test_y_app/data/models/uploaded_file.dart';

abstract class FileRepository {
  Future<UploadedFile> upload(PlatformFile file, {String kind = 'general'});
  Future<UploadedFile> replace(String fileId, PlatformFile file, {String? kind});
}
