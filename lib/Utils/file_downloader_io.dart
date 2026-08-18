import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<String> saveFileToDevice({
  required String content,
  required String filename,
}) async {
  try {
    Directory? targetDir;

    if (Platform.isAndroid) {
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
      final publicDownloadDir = Directory('/storage/emulated/0/Download');
      if (publicDownloadDir.existsSync()) {
        targetDir = publicDownloadDir;
      } else {
        targetDir = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      }
    } else if (Platform.isIOS) {
      targetDir = await getApplicationDocumentsDirectory();
    } else {
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
      targetDir ??= await getApplicationDocumentsDirectory();
    }

    final filePath = p.join(targetDir.path, filename);
    final file = File(filePath);
    await file.writeAsString(content);

    print("File saved to: $filePath");
    return "Saved $filename to $filePath";
  } catch (e) {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = p.join(tempDir.path, filename);
      final file = File(tempFilePath);
      await file.writeAsString(content);

      print("File saved to fallback path: $tempFilePath");
      return "Saved $filename to $tempFilePath";
    } catch (fallbackError) {
      print("Error saving file: $e");
      return "Error saving file: $e";
    }
  }
}
