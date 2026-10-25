import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Hiển thị ảnh từ URL mạng, Flutter assets hoặc đường dẫn ảnh cục bộ.
class VenueImage extends StatelessWidget {
  const VenueImage({
    super.key,
    required this.source,
    required this.placeholder,
  });

  final String source;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    // 1. Ảnh từ URL mạng.
    if (source.startsWith('https://') ||
        source.startsWith('http://')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    // 2. Ảnh nằm trong Flutter assets.
    if (source.startsWith('assets/')) {
      return Image.asset(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }

    // 3. Ảnh cục bộ do image_picker trả về.
    return FutureBuilder<Uint8List>(
      future: XFile(source).readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => placeholder,
          );
        }

        return placeholder;
      },
    );
  }
}
