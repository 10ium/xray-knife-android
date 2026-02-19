import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CoreManager {
  static const String _repoOwner = "lilendian0x00";
  static const String _repoName = "xray-knife";
  // دقت کنید: نام فایل در ریلیزهای گیت‌هاب باید دقیق باشد
  static const String _assetName = "Xray-knife-android-arm64-v8a.zip";
  
  static const String webUiUrl = "http://127.0.0.1:8080";

  Process? _process;

  Future<String> get _executablePath async {
    final dir = await getApplicationDocumentsDirectory();
    return "${dir.path}/xray-knife";
  }

  Future<bool> isInstalled() async {
    final path = await _executablePath;
    return File(path).exists();
  }

  Future<void> startCore() async {
    await stopCore();
    final path = await _executablePath;
    
    if (!await File(path).exists()) throw Exception("Core not found!");

    await Process.run('chmod', ['+x', path]);

    print("Starting core at $path...");
    _process = await Process.start(
      path,
      ['webui', '--auth.user', 'admin', '--auth.password', 'admin'],
      mode: ProcessStartMode.detached,
    );
    print("Core started. PID: ${_process?.pid}");
  }

  Future<void> stopCore() async {
    if (_process != null) {
      _process!.kill();
      _process = null;
    }
    try {
      await Process.run('pkill', ['xray-knife']);
    } catch (_) {}
  }

  Future<List<dynamic>> checkUpdate(String currentVersion) async {
    try {
      final url = Uri.parse("https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest");
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String latestTag = data['tag_name'];
        
        if (latestTag != currentVersion) {
          final assets = data['assets'] as List;
          final asset = assets.firstWhere(
            (element) => element['name'] == _assetName,
            orElse: () => null,
          );
          
          if (asset != null) {
            return [true, latestTag, asset['browser_download_url']];
          }
        }
      }
    } catch (e) {
      print("Update check error: $e");
    }
    return [false, null, null];
  }

  // تغییر مهم: کالبک حالا دو عدد دریافت می‌کند (دریافتی، کل)
  Future<void> downloadAndInstall(String downloadUrl, Function(int received, int total) onProgress) async {
    await stopCore();
    
    final dir = await getApplicationDocumentsDirectory();
    final zipPath = "${dir.path}/update.zip";
    
    final dio = Dio();
    // دانلود با گزارش دقیق حجم
    await dio.download(downloadUrl, zipPath, onReceiveProgress: (rec, total) {
      onProgress(rec, total);
    });

    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    
    for (final file in archive) {
      if (file.isFile) {
        final outputStream = OutputFileStream('${dir.path}/xray-knife');
        file.writeContent(outputStream);
        outputStream.close();
      }
    }
    inputStream.close();
    
    await File(zipPath).delete();

    final execPath = await _executablePath;
    await Process.run('chmod', ['+x', execPath]);
  }
}
