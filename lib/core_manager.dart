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
    
    if (!await File(path).exists()) throw Exception("Core binary is missing. Please update.");

    // Ensure executable permissions
    await Process.run('chmod', ['+x', path]);

    print("Starting core at $path...");
    _process = await Process.start(
      path,
      ['webui', '--auth.user', 'admin', '--auth.password', 'admin'],
      mode: ProcessStartMode.detached,
    );
    
    print("Core started successfully. PID: ${_process?.pid}");
  }

  Future<void> stopCore() async {
    if (_process != null) {
      _process!.kill();
      _process = null;
    }
    // Force kill any orphaned processes
    try {
      await Process.run('pkill', ['-f', 'xray-knife']);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> checkUpdate(String currentVersion) async {
    try {
      final url = Uri.parse("https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest");
      // Timeout added to prevent infinite hanging
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      
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
            // Returning direct GitHub link
            return {
              'hasUpdate': true,
              'version': latestTag,
              'url': asset['browser_download_url']
            };
          }
        }
      }
    } catch (e) {
      print("Update check error: $e");
      throw Exception("Failed to check for updates. Check your internet connection.");
    }
    return {'hasUpdate': false};
  }

  Future<void> downloadAndInstall({
    required String downloadUrl,
    required Function(int received, int total) onDownloadProgress,
    required Function() onExtracting,
  }) async {
    await stopCore();
    
    final dir = await getApplicationDocumentsDirectory();
    final zipPath = "${dir.path}/update.zip";
    final execPath = await _executablePath;
    
    final dio = Dio();
    
    // Strict timeouts for direct GitHub downloads
    dio.options.connectTimeout = const Duration(seconds: 20);
    dio.options.receiveTimeout = const Duration(minutes: 5);

    try {
      // 1. Download Phase
      await dio.download(
        downloadUrl, 
        zipPath, 
        onReceiveProgress: onDownloadProgress // خطای تایپی اینجا بود که اصلاح شد
      );

      // 2. Extraction Phase
      onExtracting(); // Notify UI that download is done, extraction started
      
      final inputStream = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeBuffer(inputStream);
      
      for (final file in archive) {
        if (file.isFile) {
          final outputStream = OutputFileStream(execPath);
          file.writeContent(outputStream);
          outputStream.close();
        }
      }
      inputStream.close();
      
      // 3. Cleanup & Permissions
      await File(zipPath).delete();
      await Process.run('chmod', ['+x', execPath]);
      
    } catch (e) {
      print("Installation error: $e");
      // Cleanup broken files on failure
      if (await File(zipPath).exists()) await File(zipPath).delete();
      throw Exception("Installation failed: ${e.toString()}");
    }
  }
}
