import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';

import 'asset_file.dart';

class ShareService {
  ShareService._();

  static Future<bool> shareAsset(AssetEntity asset) async {
    final file = await resolveAssetFile(asset);
    if (file == null) return false;
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
    return true;
  }

  static Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }
}
