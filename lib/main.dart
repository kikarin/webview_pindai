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
  bool isRooted = false;
  bool isMockLocation = false;

  @override
  void initState() {
    super.initState();
    _initialSecurityCheck();
    _requestPermissions();
    
    if (Platform.isAndroid) {
      AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
    }

    // Pengecekan keamanan berkala
    _securityCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      bool isSecurityViolated = await _checkSecurity();
      if (isSecurityViolated && mounted) {
        _showSecurityWarningDialog();
      }
    });
  }

  @override
  void dispose() {
    _securityCheckTimer?.cancel();
    super.dispose();
  }

  /// Pengecekan keamanan awal
  Future<void> _initialSecurityCheck() async {
    bool isSecurityViolated = await _checkSecurity();
    if (isSecurityViolated && mounted) {
      _showSecurityWarningDialog();
    }
  }

  /// Mengecek apakah perangkat di-root atau menggunakan Fake GPS
  Future<bool> _checkSecurity() async {
    try {
      isRooted = await SafeDevice.isJailBroken;
      isMockLocation = await SafeDevice.isMockLocation;
    } catch (e) {
      debugPrint('Error checking security: $e');
    }

    return isRooted || isMockLocation;
  }

  /// Menampilkan dialog peringatan keamanan
  void _showSecurityWarningDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, 
                   color: Colors.red[700],
                   size: 28),
              const SizedBox(width: 8),
              const Text('Peringatan Keamanan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aplikasi mendeteksi adanya pelanggaran keamanan pada perangkat Anda:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              if (isRooted) ...[
                const Text('• Perangkat dalam kondisi ROOT/Jailbreak'),
                const SizedBox(height: 8),
              ],
              if (isMockLocation) ...[
                const Text('• Terdeteksi penggunaan Fake GPS/Mock Location'),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Text(
                'Untuk alasan keamanan, aplikasi tidak dapat dijalankan pada perangkat yang sudah di-root atau menggunakan Fake GPS.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                exit(0);
              },
              child: const Text('Tutup Aplikasi'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }

  /// Meminta izin lokasi & kamera sebelum membuka WebView
  Future<void> _requestPermissions() async {
    // Meminta izin kamera terlebih dahulu
    var cameraStatus = await Permission.camera.request();
    if (cameraStatus.isDenied && mounted) {
      // Coba minta lagi jika ditolak
      cameraStatus = await Permission.camera.request();
    }

    // Meminta izin lokasi
    var locationStatus = await Permission.location.request();
    if (locationStatus.isDenied && mounted) {
      locationStatus = await Permission.location.request();
    }

    // Meminta izin lokasi latar belakang jika diperlukan
    if (locationStatus.isGranted) {
      var backgroundLocation = await Permission.locationAlways.request();
      if (backgroundLocation.isDenied && mounted) {
        await Permission.locationAlways.request();
      }
    }

    // Log status izin untuk debugging
    debugPrint('Camera permission: ${await Permission.camera.status}');
    debugPrint('Location permission: ${await Permission.location.status}');
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
                  mediaPlaybackRequiresUserGesture: false,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                ),
                onGeolocationPermissionsShowPrompt: (controller, origin) async {
                  return GeolocationPermissionShowPromptResponse(
                    origin: origin,
                    allow: true,
                    retain: true
                  );
                },
                onPermissionRequest: (controller, resources) async {
                  return PermissionResponse(
                    resources: resources.resources,
                    action: PermissionResponseAction.GRANT);
                },
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onLoadError: (controller, url, code, message) {
                  debugPrint('WebView Error: $code - $message');
                },
                onConsoleMessage: (controller, consoleMessage) {
                  debugPrint('Console: ${consoleMessage.message}');
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
