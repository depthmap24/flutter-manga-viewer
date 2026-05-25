import 'dart:io';

class ImageFile {
  final String path;

  const ImageFile(this.path);

  String get name => path.split('/').last;

  String get extension {
    final n = name;
    final dot = n.lastIndexOf('.');
    if (dot < 0) return '';
    return n.substring(dot).toLowerCase();
  }

  File get file => File(path);

  bool get isSvg => extension == '.svg';

  @override
  bool operator ==(Object other) => other is ImageFile && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'ImageFile($name)';
}
