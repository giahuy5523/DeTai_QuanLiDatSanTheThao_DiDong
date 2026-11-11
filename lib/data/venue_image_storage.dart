import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Copies picker-cache images into app documents before persisting their paths.
class VenueImageStorage {
  VenueImageStorage._();
  static int _sequence = 0;

  static Future<String> persist(String source) async {
    if (source.startsWith('assets/') ||
        source.startsWith('http://') ||
        source.startsWith('https://') ||
        source.startsWith('blob:')) {
      return source;
    }

    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'venue_images'));
    await directory.create(recursive: true);
    final sourceFile = File(source);
    if (p.equals(
          p.normalize(sourceFile.absolute.path),
          p.normalize(directory.absolute.path),
        ) ||
        p.isWithin(directory.absolute.path, sourceFile.absolute.path)) {
      return source;
    }
    if (!await sourceFile.exists()) return source;

    final extension = p.extension(sourceFile.path);
    final destination = File(
      p.join(
        directory.path,
        'venue_${DateTime.now().microsecondsSinceEpoch}_${_sequence++}$extension',
      ),
    );
    return (await sourceFile.copy(destination.path)).path;
  }
}
