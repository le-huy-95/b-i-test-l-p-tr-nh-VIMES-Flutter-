import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:test_y_app/core/skin/color_skin.dart';
import 'package:test_y_app/data/models/uploaded_file.dart';
import 'package:test_y_app/domain/repositories/file_repository.dart';
import 'package:test_y_app/shared/snackbar/simple_snackbar_service.dart';

class AuthorizationSelectDialogItem {
  const AuthorizationSelectDialogItem({required this.id, required this.title, this.subtitle});

  final String id;
  final String title;
  final String? subtitle;
}

class AuthorizationSelectDialog extends StatefulWidget {
  const AuthorizationSelectDialog({super.key, required this.items});

  final List<AuthorizationSelectDialogItem> items;

  static Future<List<String>?> show(
    BuildContext context, {
    required List<AuthorizationSelectDialogItem> items,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => AuthorizationSelectDialog(items: items),
    );
  }

  @override
  State<AuthorizationSelectDialog> createState() => _AuthorizationSelectDialogState();
}

class _AuthorizationSelectDialogState extends State<AuthorizationSelectDialog> {
  final _query = TextEditingController();
  final Set<String> _selected = {};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((item) {
            return item.title.toLowerCase().contains(q) ||
                (item.subtitle?.toLowerCase().contains(q) ?? false);
          }).toList();

    return AlertDialog(
      title: const Text('Chọn giấy ủy quyền'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Tìm giấy ủy quyền...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: filtered.isEmpty
                  ? const Center(child: Text('Không tìm thấy kết quả'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final selected = _selected.contains(item.id);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: selected,
                          title: Text(item.title),
                          subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(item.id);
                              } else {
                                _selected.remove(item.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Đóng')),
        FilledButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.toList()),
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}

Future<List<String>?> pickAndUploadAuthorizationFiles(
  BuildContext context, {
  required FileRepository repository,
  required String kind,
}) async {
  final pick = await FilePicker.platform.pickFiles(withData: false);
  if (pick == null || pick.files.isEmpty) return null;
  final uploadedIds = <String>[];
  for (final file in pick.files) {
    try {
      final uploaded = await repository.upload(file, kind: kind);
      uploadedIds.add(uploaded.id);
    } catch (e) {
      SimpleSnackbarService.showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }
  return uploadedIds.isEmpty ? null : uploadedIds;
}

class UploadedFileChip extends StatelessWidget {
  const UploadedFileChip({super.key, required this.file});

  final UploadedFile file;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(file.originalName),
      avatar: const Icon(Icons.insert_drive_file_outlined, size: 18),
      backgroundColor: ColorSkin.tealLight,
    );
  }
}
