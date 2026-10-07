import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Đọc cả URL mạng và đường dẫn ảnh do image_picker trả về trên Android/Web.
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
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return Image.network(
        source,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    }
    return FutureBuilder<Uint8List>(
      future: XFile(source).readAsBytes(),
      builder: (context, snapshot) => snapshot.hasData
          ? Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            )
          : placeholder,
    );
  }
}
