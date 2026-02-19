import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core_manager.dart';

void main() {
  runApp(const MaterialApp(home: XrayApp()));
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
      await Future.delayed(const Duration(seconds: 2));
      
      _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
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
    setState(() => _status = "Checking for updates...");
    
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

      _showDownloadDialog(downloadUrl!, newVersion!);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No updates available.")));
      if (!forceDownload && !_isCoreRunning) _startAndShow();
    }
  }

  void _showDownloadDialog(String url, String version) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          double progress = 0;
          
          _core.downloadAndInstall(url, (p) {
            setState(() => progress = p);
            if (p >= 1.0) {
              Navigator.pop(context);
              _currentVersion = version;
              _startAndShow();
            }
          });

          return AlertDialog(
            title: const Text("Downloading Core..."),
            content: LinearProgressIndicator(value: progress),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Xray Knife Manager"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _webController?.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.system_update),
            onPressed: () => _checkForUpdates(),
          ),
        ],
      ),
      body: _isCoreRunning && _webController != null
          ? WebViewWidget(controller: _webController!)
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_status),
                ],
              ),
            ),
    );
  }
}
