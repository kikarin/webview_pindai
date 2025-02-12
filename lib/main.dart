import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:safe_device/safe_device.dart';
import 'dart:io';
import 'dart:async';

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
  Timer? _securityCheckTimer; // Timer untuk cek keamanan berkala

  @override
  void initState() {
    super.initState();
    _initialSecurityCheck();
    _requestPermissions();
    
    if (Platform.isAndroid) {
      AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    }

    // Menambahkan pengecekan keamanan berkala setiap 5 detik
    _securityCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkSecurity();
    });
  }

  @override
  void dispose() {
    _securityCheckTimer?.cancel();
    super.dispose();
  }

  /// Pengecekan keamanan awal
  Future<void> _initialSecurityCheck() async {
    bool shouldExit = await _checkSecurity();
    if (shouldExit && mounted) {
      exit(0);
    }
  }

  /// Mengecek apakah perangkat di-root atau menggunakan Fake GPS
  Future<bool> _checkSecurity() async {
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
                  exit(0);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return true;
    }
    return false;
  }

  /// Meminta izin lokasi & kamera sebelum membuka WebView
  Future<void> _requestPermissions() async {
    // Meminta izin lokasi
    var locationStatus = await Permission.location.request();
    if (locationStatus.isDenied && mounted) {
      await Permission.location.request();
    }

    // Meminta izin kamera
    var cameraStatus = await Permission.camera.request();
    if (cameraStatus.isDenied && mounted) {
      await Permission.camera.request();
    }

    // Meminta izin lokasi latar belakang jika diperlukan
    if (locationStatus.isGranted) {
      var backgroundLocation = await Permission.locationAlways.request();
      if (backgroundLocation.isDenied && mounted) {
        await Permission.locationAlways.request();
      }
    }

    // Log status izin untuk debugging
    debugPrint('Location permission: ${await Permission.location.status}');
    debugPrint('Camera permission: ${await Permission.camera.status}');
    debugPrint('Background Location: ${await Permission.locationAlways.status}');
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
                  // Otomatis mengizinkan permintaan lokasi dari webview
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
