import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safe_device/safe_device.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pindai.me',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  InAppWebViewController? _controller;
  bool isLoading = true;
  String currentUrl = "https://app.pindai.me";

  @override
  void initState() {
    super.initState();
    _checkSecurity();
    _requestPermissions();
    
    if (Platform.isAndroid) {
      AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    }
  }

  /// Mengecek apakah perangkat di-root atau menggunakan Fake GPS
  Future<void> _checkSecurity() async {
    bool isRooted = false;
    bool isMockLocation = false;

    try {
      isRooted = await SafeDevice.isJailBroken;
      isMockLocation = await SafeDevice.isMockLocation;
    } catch (e) {
      debugPrint('Error checking security: $e');
    }

    if (isRooted || isMockLocation) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Peringatan Keamanan'),
            content: const Text(
              'Aplikasi tidak dapat dijalankan karena perangkat Anda terdeteksi menggunakan root atau fake GPS. Mohon gunakan perangkat yang aman.'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  exit(0); // ✅ Langsung keluar tanpa Navigator.pop()
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Meminta izin lokasi & kamera sebelum membuka WebView
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ].request();

    // Cek status permission lokasi
    if (statuses[Permission.location]!.isDenied ||
        statuses[Permission.locationWhenInUse]!.isDenied) {
      // Tampilkan dialog jika permission ditolak
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Izin Lokasi Diperlukan'),
            content: const Text(
              'Aplikasi memerlukan akses lokasi untuk berfungsi dengan baik. '
              'Mohon aktifkan izin lokasi di pengaturan.',
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Buka Pengaturan'),
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Batal'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_controller == null) return true;
        if (await _controller!.canGoBack()) {
          _controller!.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(currentUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  geolocationEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  useHybridComposition: true,
                  supportZoom: false,
                  clearCache: false,
                  cacheEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  useWideViewPort: true,
                  safeBrowsingEnabled: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  allowFileAccess: true,
                  allowContentAccess: true,
                  loadWithOverviewMode: true,
                ),
                onGeolocationPermissionsShowPrompt: (controller, origin) async {
                  return GeolocationPermissionShowPromptResponse(
                    origin: origin,
                    allow: true,
                    retain: true
                  );
                },
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onLoadError: (controller, url, code, message) {
                  print('WebView Error: $code - $message');
                },
                onConsoleMessage: (controller, consoleMessage) {
                  print('Console: ${consoleMessage.message}');
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    isLoading = true;
                    currentUrl = url.toString();
                  });
                },
                onLoadStop: (controller, url) {
                  setState(() {
                    isLoading = false;
                    currentUrl = url.toString();
                  });
                },
              ),
              if (isLoading) 
                Container(
                  color: Colors.white,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
