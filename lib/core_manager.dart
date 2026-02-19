import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CoreManager {
  static const String _repoOwner = "lilendian0x00";
  static const String _repoName = "xray-knife";
  static const String _assetName = "Xray-knife-android-arm64-v8a.zip";
  
  // پورت وب یو آی
  static const String webUiUrl = "http://127.0.0.1:8080";

  Process? _process;

  /// مسیر فایل اجرایی را برمی‌گرداند
  Future<String> get _executablePath async {
    final dir = await getApplicationDocumentsDirectory();
    return "${dir.path}/xray-knife";
  }

  /// چک می‌کند آیا هسته نصب شده است؟
  Future<bool> isInstalled() async {
    final path = await _executablePath;
    return File(path).exists();
  }

  /// اجرای هسته
  Future<void> startCore() async {
    await stopCore(); // اول مطمئن شویم قبلی بسته شده
    final path = await _executablePath;
    
    if (!await File(path).exists()) throw Exception("Core not found!");

    // مطمئن شویم قابلیت اجرا دارد
    await Process.run('chmod', ['+x', path]);

    print("Starting core at $path...");
    _process = await Process.start(
      path,
      ['webui', '--auth.user', 'admin', '--auth.password', 'admin'],
      mode: ProcessStartMode.detached,
    );
    print("Core started. PID: ${_process?.pid}");
  }

  /// توقف هسته
  Future<void> stopCore() async {
    if (_process != null) {
      _process!.kill();
      _process = null;
    }
    // کشتن پروسه‌های احتمالی یتیم مانده
    try {
      await Process.run('pkill', ['xray-knife']);
    } catch (_) {}
  }

  /// بررسی آپدیت از گیت‌هاب
  /// خروجی: [آیا آپدیت هست؟, نام نسخه جدید, لینک دانلود]
  Future<List<dynamic>> checkUpdate(String currentVersion) async {
    try {
      final url = Uri.parse("https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest");
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String latestTag = data['tag_name'];
        
        // اگر نسخه فعلی با جدیدترین فرق داشت (ساده‌ترین منطق)
        if (latestTag != currentVersion) {
          // پیدا کردن لینک دانلود برای معماری اندروید
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

  /// دانلود و نصب آپدیت
  Future<void> downloadAndInstall(String downloadUrl, Function(double) onProgress) async {
    await stopCore(); // توقف قبل از جایگزینی
    
    final dir = await getApplicationDocumentsDirectory();
    final zipPath = "${dir.path}/update.zip";
    
    // 1. دانلود
    final dio = Dio();
    await dio.download(downloadUrl, zipPath, onReceiveProgress: (rec, total) {
      if (total != -1) {
        onProgress(rec / total);
      }
    });

    // 2. اکسترکت
    final inputStream = InputFileStream(zipPath);
    final archive = ZipDecoder().decodeBuffer(inputStream);
    
    for (final file in archive) {
      if (file.isFile) {
        final outputStream = OutputFileStream('${dir.path}/xray-knife'); // نام فایل خروجی را ثابت می‌کنیم
        file.writeContent(outputStream);
        outputStream.close();
      }
    }
    inputStream.close();
    
    // 3. پاک کردن فایل زیپ
    await File(zipPath).delete();

    // 4. مجوز اجرا
    final execPath = await _executablePath;
    await Process.run('chmod', ['+x', execPath]);
  }
}