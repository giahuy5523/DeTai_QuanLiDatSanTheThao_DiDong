import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Image files only; profile metadata stays in MockStore until SQLite.
class AvatarStorage {
  Future<Directory> _directory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}${Platform.pathSeparator}avatars');
    return directory.create(recursive: true);
  }

  Future<String> save(Uint8List png) async {
    final directory = await _directory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'avatar_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(png, flush: true);
    return file.path;
  }

  Future<void> remove(String? path) async {
    if (path == null) return;
    final directory = await _directory();
    final file = File(path);
    // Never delete picker/source files outside the application's avatar folder.
    if (file.parent.absolute.path == directory.absolute.path &&
        await file.exists()) {
      await file.delete();
    }
  }
}
