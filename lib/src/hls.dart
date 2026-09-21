import 'dart:convert';

/// Read only variant URLs declared by the HLS master, never invent resolutions.
Map<String, Uri> hlsVariants(String manifest, Uri master) {
  final result = <String, Uri>{'Auto': master};
  int? height;
  bool variant = false;
  for (final raw in manifest.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('#EXT-X-STREAM-INF:')) {
      variant = true;
      height = int.tryParse(
        RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(line)?.group(1) ?? '',
      );
    } else if (line.isNotEmpty && !line.startsWith('#') && variant) {
      final uri = master.resolve(line);
      var filename = uri.path;
      final playlist = uri.queryParameters['playlist'];
      if (playlist != null) {
        try {
          filename = utf8.decode(
            base64Url.decode(base64Url.normalize(playlist)),
          );
        } catch (_) {
          /* Unknown playlist name: retain automatic quality. */
        }
      }
      height ??= int.tryParse(
        RegExp(r'(?:^|/)(\d{3,4})p\.m3u8$').firstMatch(filename)?.group(1) ??
            '',
      );
      if (height != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
        result[height == 2160
                ? '4K'
                : height == 1440
                ? '2K'
                : '${height}p'] =
            uri;
      }
      height = null;
      variant = false;
    }
  }
  return result;
}
