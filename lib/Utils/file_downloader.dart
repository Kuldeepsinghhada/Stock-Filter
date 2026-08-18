import 'file_downloader_stub.dart'
    if (dart.library.html) 'file_downloader_web.dart'
    if (dart.library.io) 'file_downloader_io.dart';

class FileDownloader {
  static Future<String> downloadFile({
    required String content,
    required String filename,
  }) async {
    return saveFileToDevice(content: content, filename: filename);
  }
}
