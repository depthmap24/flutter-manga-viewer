import 'package:share_plus/share_plus.dart';

class ShareService {
  ShareService._();

  static Future<void> shareImage(String path) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)]),
    );
  }
}
