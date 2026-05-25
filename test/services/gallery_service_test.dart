import 'package:flutter_test/flutter_test.dart';
import 'package:imageviewer/models/image_file.dart';
import 'package:imageviewer/services/gallery_service.dart';

void main() {
  final svc = GalleryService();

  group('GalleryService.filterImages', () {
    test('keeps only supported extensions', () {
      final files = [
        ImageFile('/a/photo.jpg'),
        ImageFile('/a/doc.pdf'),
        ImageFile('/a/image.PNG'),
        ImageFile('/a/video.mp4'),
        ImageFile('/a/icon.svg'),
        ImageFile('/a/anim.webp'),
      ];
      final result = svc.filterImages(files);
      final names = result.map((f) => f.name).toList();
      expect(names, containsAll(['photo.jpg', 'image.PNG', 'icon.svg', 'anim.webp']));
      expect(names, isNot(contains('doc.pdf')));
      expect(names, isNot(contains('video.mp4')));
    });
  });

  group('GalleryService.sortImages', () {
    test('returns files in case-insensitive alphabetical order', () {
      final files = [
        ImageFile('/a/Zebra.jpg'),
        ImageFile('/a/apple.png'),
        ImageFile('/a/Mango.webp'),
      ];
      final sorted = svc.sortImages(files);
      expect(sorted.map((f) => f.name).toList(),
          ['apple.png', 'Mango.webp', 'Zebra.jpg']);
    });
  });

  group('GalleryService.safUriToPath', () {
    test('passes through a real /storage/... path unchanged', () {
      const p = '/storage/emulated/0/Pictures/NovelAI';
      expect(svc.safUriToPath(p), p);
    });

    test('converts primary SAF URI to real path', () {
      const uri =
          'content://com.android.externalstorage.documents/tree/primary%3APictures%2FNovelAI';
      expect(svc.safUriToPath(uri), '/storage/emulated/0/Pictures/NovelAI');
    });

    test('returns null for unrecognised URI scheme', () {
      expect(svc.safUriToPath('ftp://something'), isNull);
    });
  });
}
