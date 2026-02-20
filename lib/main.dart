import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // برای دسترسی به کلیپ‌بورد اضافه شد
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core_manager.dart';

void main() {
  runApp(const XrayApp());
}

// App Status Enum for bulletproof state management
enum AppState { initial, checking, downloading, extracting, starting, running, error }

class XrayApp extends StatelessWidget {
  const XrayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Xray Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final CoreManager _core = CoreManager();
  WebViewController? _webController;
  
  AppState _appState = AppState.initial;
  String _errorMessage = "";
  String _currentVersion = "v0.0.0"; 

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _appState = AppState.checking);
    
    final prefs = await SharedPreferences.getInstance();
    _currentVersion = prefs.getString('xray_version') ?? "v0.0.0";

    bool installed = await _core.isInstalled();
    
    if (!installed) {
      await _checkForUpdates(forceDownload: true);
    } else {
      await _startEngine();
    }
  }

  Future<void> _startEngine() async {
    setState(() => _appState = AppState.starting);
    
    try {
      await _core.startCore();
      
      // Wait for the local server to fully spin up
      await Future.delayed(const Duration(seconds: 3)); 
      
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadRequest(Uri.parse(CoreManager.webUiUrl));

      setState(() => _appState = AppState.running);
    } catch (e) {
      setState(() {
        _appState = AppState.error;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _checkForUpdates({bool forceDownload = false}) async {
    if (!forceDownload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Checking for updates..."), duration: Duration(seconds: 1)),
      );
    }

    try {
      final updateInfo = await _core.checkUpdate(_currentVersion);
      
      if (updateInfo?['hasUpdate'] == true) {
        final newVersion = updateInfo!['version'];
        final downloadUrl = updateInfo['url'];

        // Ask user if not forced
        if (!forceDownload) {
          bool? confirm = await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("New Engine Available"),
              content: Text("Version $newVersion is ready. Do you want to update now?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Later")),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Update")),
              ],
            ),
          );
          if (confirm != true) return;
        }

        await _startDownloadProcess(downloadUrl, newVersion);
      } else {
        if (!forceDownload) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You are on the latest version.")),
          );
        }
        if (_appState != AppState.running) _startEngine();
      }
    } catch (e) {
      if (forceDownload) {
        setState(() {
          _appState = AppState.error;
          _errorMessage = e.toString();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _startDownloadProcess(String url, String newVersion) async {
    // Show modern bottom sheet for download progress
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DownloadSheet(
        url: url,
        coreManager: _core,
        onComplete: () async {
          Navigator.pop(context); // Close sheet
          
          // Save new version
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('xray_version', newVersion);
          _currentVersion = newVersion;
          
          _startEngine();
        },
        onError: (err) {
          Navigator.pop(context);
          setState(() {
            _appState = AppState.error;
            _errorMessage = err;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Modern Animated transition between states
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _buildBody(),
      ),
      floatingActionButton: _appState == AppState.running 
        ? FloatingActionButton(
            onPressed: () => _checkForUpdates(),
            child: const Icon(Icons.sync),
            tooltip: "Check for updates",
          ) 
        : null,
    );
  }

  Widget _buildBody() {
    switch (_appState) {
      case AppState.running:
        return SafeArea(child: WebViewWidget(controller: _webController!));
      
      case AppState.error:
        // --- رابط کاربری جدید ارور با قابلیت کپی لاگ ---
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                const SizedBox(height: 16),
                const Text("Something went wrong", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                // باکس ترمینال‌مانند برای نمایش ارور
                Container(
                  padding: const EdgeInsets.all(12),
                  height: 150, // محدود کردن ارتفاع که صفحه شلوغ نشود
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _errorMessage,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // دکمه‌های کپی و تلاش مجدد
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        // کپی کردن متن ارور در کلیپ‌بورد سیستم
                        await Clipboard.setData(ClipboardData(text: _errorMessage));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Error log copied to clipboard!")),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text("Copy Log"),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: _initialize,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text("Retry"),
                    ),
                  ],
                )
              ],
            ),
          ),
        );

      default:
        // Splash / Loading Screen
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.rocket_launch, size: 50, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _getStatusText(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1.2),
              ),
            ],
          ),
        );
    }
  }

  String _getStatusText() {
    switch (_appState) {
      case AppState.checking: return "CHECKING SYSTEM...";
      case AppState.starting: return "STARTING ENGINE...";
      default: return "INITIALIZING...";
    }
  }
}

// --- Modern Download Bottom Sheet Widget ---
class DownloadSheet extends StatefulWidget {
  final String url;
  final CoreManager coreManager;
  final VoidCallback onComplete;
  final Function(String) onError;

  const DownloadSheet({
    super.key,
    required this.url,
    required this.coreManager,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<DownloadSheet> {
  double _progress = 0;
  String _downloadedSize = "0 MB";
  String _totalSize = "...";
  bool _isExtracting = false;
  bool _isIndeterminate = false;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      await widget.coreManager.downloadAndInstall(
        downloadUrl: widget.url,
        onDownloadProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadedSize = _formatBytes(received);
            if (total != -1) {
              _progress = received / total;
              _totalSize = _formatBytes(total);
              _isIndeterminate = false;
            } else {
              _isIndeterminate = true;
              _totalSize = "Unknown";
            }
          });
        },
        onExtracting: () {
          if (!mounted) return;
          setState(() {
            _isExtracting = true;
          });
        },
      );
      
      if (mounted) widget.onComplete();

    } catch (e) {
      if (mounted) widget.onError(e.toString());
    }
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_isExtracting ? Icons.unarchive : Icons.cloud_download, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                _isExtracting ? "Extracting Files..." : "Downloading Core...",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LinearProgressIndicator(
            value: (_isIndeterminate || _isExtracting) ? null : _progress,
            borderRadius: BorderRadius.circular(8),
            minHeight: 10,
          ),
          const SizedBox(height: 12),
          if (!_isExtracting)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$_downloadedSize / $_totalSize", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                if (!_isIndeterminate)
                  Text("${(_progress * 100).toStringAsFixed(1)}%", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
        ],
      ),
    );
  }
}
