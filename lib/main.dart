import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core_manager.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: XrayApp(),
  ));
}

class XrayApp extends StatefulWidget {
  const XrayApp({super.key});

  @override
  State<XrayApp> createState() => _XrayAppState();
}

class _XrayAppState extends State<XrayApp> {
  final CoreManager _core = CoreManager();
  WebViewController? _webController;
  
  bool _isCoreRunning = false;
  String _status = "Initializing...";
  String _currentVersion = "v0.0.0"; 

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _initSequence();
  }

  Future<void> _loadVersion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentVersion = prefs.getString('xray_version') ?? "v0.0.0";
    });
  }

  Future<void> _saveVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('xray_version', version);
  }

  Future<void> _initSequence() async {
    bool installed = await _core.isInstalled();
    
    if (!installed) {
      setState(() => _status = "Core missing. Checking for download...");
      _checkForUpdates(forceDownload: true);
    } else {
      _startAndShow();
    }
  }

  Future<void> _startAndShow() async {
    setState(() => _status = "Starting Xray Core...");
    try {
      await _core.startCore();
      await Future.delayed(const Duration(seconds: 3)); 
      
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadRequest(Uri.parse(CoreManager.webUiUrl));

      setState(() {
        _isCoreRunning = true;
        _status = "Running";
      });
    } catch (e) {
      setState(() => _status = "Error: $e");
    }
  }

  Future<void> _checkForUpdates({bool forceDownload = false}) async {
    if (!forceDownload) setState(() => _status = "Checking for updates...");
    
    final result = await _core.checkUpdate(_currentVersion);
    final bool hasUpdate = result[0];
    final String? newVersion = result[1];
    final String? downloadUrl = result[2];

    if (forceDownload || (hasUpdate && downloadUrl != null)) {
      if (!forceDownload) {
        bool? confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Update Available"),
            content: Text("New version $newVersion is available. Update now?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Update")),
            ],
          ),
        );
        if (confirm != true) return;
      }

      _showProfessionalDownloadDialog(downloadUrl!, newVersion!);
    } else {
      if (!forceDownload) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No updates available.")));
      }
      if (!_isCoreRunning) _startAndShow();
    }
  }

  void _showProfessionalDownloadDialog(String url, String version) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          double progress = 0;
          String downloadedSize = "0 MB";
          String totalSize = "...";
          String percentage = "0%";
          bool isIndeterminate = false;

          _core.downloadAndInstall(url, (received, total) {
            setState(() {
              downloadedSize = _formatBytes(received);
              
              if (total != -1) {
                // اگر حجم مشخص است
                progress = received / total;
                percentage = "${(progress * 100).toStringAsFixed(1)}%";
                totalSize = _formatBytes(total);
                isIndeterminate = false;
              } else {
                // اگر حجم نامشخص است (Chunked Transfer)
                isIndeterminate = true;
                totalSize = "Unknown";
                percentage = "...";
              }
            });

            // شرط پایان: اگر حجم مشخص بود و ۱۰۰٪ شد، یا اگر حجم نامشخص بود ولی دانلود تمام شد (اینجا باگ منطقی نداریم چون تابع وقتی تمام شود success برمیگرداند)
            if (!isIndeterminate && progress >= 1.0) {
               Future.delayed(const Duration(seconds: 1), () {
                 // بررسی اینکه دیالوگ هنوز باز است یا نه
                 if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                    _currentVersion = version;
                    _saveVersion(version);
                    _startAndShow();
                 }
               });
            }
          }).then((_) {
              // وقتی دانلود کامل شد (چه با حجم معلوم چه نامعلوم)
               if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                  _currentVersion = version;
                  _saveVersion(version);
                  _startAndShow();
               }
          }).catchError((error) {
              // بستن دیالوگ در صورت خطا
              if (Navigator.canPop(context)) {
                 Navigator.pop(context);
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download Failed: $error")));
              // تلاش مجدد برای شروع (شاید فایل قبلی موجود باشد)
              _initSequence();
          });

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Row(
              children: const [
                Icon(Icons.cloud_download, color: Colors.blueAccent),
                SizedBox(width: 10),
                Text("Downloading Core"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Installing latest Xray engine...", style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 20),
                
                // نوار پیشرفت: اگر حجم نامشخص باشد، می‌چرخد
                LinearProgressIndicator(
                  value: isIndeterminate ? null : (progress > 0 ? progress : null),
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  minHeight: 8,
                ),
                
                const SizedBox(height: 10),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$downloadedSize / $totalSize", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(percentage, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return "${d.toStringAsFixed(1)} ${suffixes[i]}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isCoreRunning 
        ? null 
        : AppBar(title: const Text("Xray Manager")), 
      body: SafeArea(
        child: _isCoreRunning && _webController != null
            ? WebViewWidget(controller: _webController!)
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 50, height: 50,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 20),
                    Text(_status, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 40),
                    if (_status.startsWith("Error") || _status.startsWith("Download Failed"))
                      ElevatedButton.icon(
                        onPressed: () => _initSequence(),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                      )
                  ],
                ),
              ),
      ),
      floatingActionButton: _isCoreRunning 
        ? FloatingActionButton.small(
            onPressed: () => _checkForUpdates(),
            child: const Icon(Icons.system_update),
            tooltip: "Check Updates",
            backgroundColor: Colors.white.withOpacity(0.8),
          ) 
        : null,
    );
  }
}
