import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/shared/bottom_sheet/app_bottom_sheet_service.dart';
import 'package:test_y_app/data/models/uploaded_file.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

class FileUploadBottomSheet extends StatefulWidget {
  const FileUploadBottomSheet({
    super.key,
    required this.repository,
    required this.kind,
    this.allowKinds = const ['image', 'pdf'],
  });

  final FileRepository repository;
  final String kind;
  final List<String> allowKinds;

  static Future<UploadedFile?> show(
    BuildContext context, {
    required FileRepository repository,
    required String kind,
    List<String> allowKinds = const ['image', 'pdf'],
  }) {
    return AppBottomSheetService.show<UploadedFile>(
      context: context,
      showHandle: false,
      contentPadding: EdgeInsets.zero,
      content: FileUploadBottomSheet(
        repository: repository,
        kind: kind,
        allowKinds: allowKinds,
      ),
      actions: const [],
    );
  }

  @override
  State<FileUploadBottomSheet> createState() => _FileUploadBottomSheetState();
}

class _FileUploadBottomSheetState extends State<FileUploadBottomSheet> {
  bool _uploading = false;
  PlatformFile? _picked;
  String? _error;

  Future<void> _pick() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (!mounted) return;
    setState(() {
      _picked = file;
      _error = null;
    });
  }

  Future<void> _upload() async {
    final file = _picked;
    if (file == null) {
      setState(() => _error = 'Vui lòng chọn file trước');
      return;
    }
    if ((file.size / (1024 * 1024)) > 25) {
      setState(() => _error = 'File quá lớn, tối đa 25MB');
      return;
    }

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final uploaded = await widget.repository.upload(file, kind: widget.kind);
      if (!mounted) return;
      Navigator.of(context).pop(uploaded);
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error = message);
      SimpleSnackbarService.showError(message);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorSkin.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload file giấy ủy quyền',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pick,
                icon: const Icon(Icons.attach_file),
                label: Text(_picked == null ? 'Chọn file' : _picked!.name),
              ),
              if (_picked != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Dung lượng: ${(_picked!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _uploading ? null : _upload,
                      child: _uploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Upload'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Chỉ chấp nhận ảnh / PDF ≤ 25MB',
                style: TextStyle(color: ColorSkin.subtitle, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
