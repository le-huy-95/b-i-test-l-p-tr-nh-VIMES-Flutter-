import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const defaultTenantLogoAssetPath =
    'lib/assets/image/app_icon_foreground.png';

/// Copies bundled default tenant logo to a temp file for multipart upload.
Future<String> resolveDefaultTenantLogoPath() async {
  final bytes = await rootBundle.load(defaultTenantLogoAssetPath);
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/default_tenant_logo.png');
  await file.writeAsBytes(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    flush: true,
  );
  return file.path;
}
