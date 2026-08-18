// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

Future<String> saveFileToDevice({
  required String content,
  required String filename,
}) async {
  try {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    return "Downloaded $filename to your downloads folder";
  } catch (e) {
    return "Error downloading file: $e";
  }
}
