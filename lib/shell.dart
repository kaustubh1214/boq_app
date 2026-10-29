import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'config.dart';
import 'scanner.dart';
import 'settings.dart';

/// The whole app: the live AV BOQ web app (same screens as on a computer) plus the phone-only parts
/// a web page can't do — camera QR scan, saving/opening PDFs and Excel files, photo upload, back button.
/// The web side talks to it through the `AvBoqApp` channel (boq-ui/src/lib/native.ts).
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  WebViewController? _web;
  String _server = defaultServer;
  int _progress = 0;
  bool _loaded = false; // first page shown at least once
  bool _slow = false; // first load is taking long: offer settings on the splash
  String? _error; // why the page could not be opened
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final server = await ServerConfig.load();
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(paper)
      ..setUserAgent(appUserAgent)
      ..addJavaScriptChannel('AvBoqApp', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? true) _fail(_describe(e));
        },
        onHttpError: (e) {
          // Only the page itself: API errors (401, 409, 422…) are shown by the web app.
          final uri = e.request?.uri;
          final status = e.response?.statusCode ?? 0;
          if (uri == null || uri.host != Uri.parse(_server).host) return;
          if (uri.path.startsWith('/api/') || uri.path.startsWith('/assets/')) return;
          if (status >= 400) {
            _fail(status == 404 || status >= 500
                ? 'The office server is not online right now. Ask the office to start it (laptop on, BOQ app and ngrok running).'
                : 'Server answered with error $status.');
          }
        },
        onNavigationRequest: _onNavigate,
      ));
    final platform = c.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
      await platform.setOnShowFileSelector(_pickFiles);
    }
    if (!mounted) return;
    setState(() {
      _web = c;
      _server = server;
    });
    _load();
  }

  void _load({bool reload = false}) {
    final c = _web;
    if (c == null) return;
    setState(() {
      _error = null;
      _progress = 0;
      _slow = false;
    });
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && !_loaded) setState(() => _slow = true);
    });
    if (reload && _loaded) {
      c.reload();
    } else {
      c.loadRequest(Uri.parse('$_server/'));
    }
  }

  void _fail(String why) {
    if (mounted) setState(() => _error = why);
  }

  String _describe(WebResourceError e) {
    switch (e.errorType) {
      case WebResourceErrorType.hostLookup:
      case WebResourceErrorType.connect:
        return 'No internet connection, or the server address is wrong.';
      case WebResourceErrorType.timeout:
        return 'The server took too long to answer. Is the office laptop on?';
      case WebResourceErrorType.failedSslHandshake:
        return 'Secure connection failed. Check the server address in Settings.';
      default:
        return 'Could not open the BOQ app (${e.description}).';
    }
  }

  /// Our own pages stay inside the app; phone numbers, mail, WhatsApp and other sites open in their apps.
  NavigationDecision _onNavigate(NavigationRequest r) {
    final u = Uri.tryParse(r.url);
    if (u == null) return NavigationDecision.prevent;
    if (u.scheme == 'about' || u.scheme == 'blob' || u.scheme == 'data') return NavigationDecision.navigate;
    if (u.host == Uri.parse(_server).host || !r.isMainFrame) return NavigationDecision.navigate;
    launchUrl(u, mode: LaunchMode.externalApplication);
    return NavigationDecision.prevent;
  }

  // ---- messages from the web app ------------------------------------------------------------

  Future<void> _onMessage(JavaScriptMessage m) async {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(m.message) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (msg['type']) {
      case 'file':
        await _saveFile(msg['name'] as String? ?? 'download', msg['data'] as String? ?? '');
      case 'scan':
        await _scan();
    }
  }

  /// PDFs (gate passes) and Excel exports: saved inside the app, opened in the phone's viewer, shareable to WhatsApp.
  Future<void> _saveFile(String name, String data) async {
    try {
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/files');
      await dir.create(recursive: true);
      final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/$safe');
      await file.writeAsBytes(base64Decode(data), flush: true);
      final opened = await OpenFilex.open(file.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(opened.type == ResultType.done ? 'Saved $safe' : 'Saved $safe. No app on this phone can open it — share it instead.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(label: 'Share', onPressed: () => Share.shareXFiles([XFile(file.path)])),
      ));
    } catch (_) {
      _snack('Could not save the file. Try again.');
    }
  }

  Future<void> _scan() async {
    if (!await ensureCameraPermission(context) || !mounted) {
      await _web?.runJavaScript('window.__avboqScan && window.__avboqScan(null)');
      return;
    }
    final text = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScannerPage()));
    await _web?.runJavaScript('window.__avboqScan && window.__avboqScan(${jsonEncode(text)})');
  }

  /// `<input type="file">` in the web app (invoice photos, CSV imports).
  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final accept = params.acceptTypes.join(',').toLowerCase();
    var fromCamera = false;
    if (accept.contains('image')) {
      final choice = await _askSource();
      if (choice == null) return const [];
      fromCamera = choice;
    }
    try {
      if (fromCamera) {
        // Android refuses the camera to an app that declares the permission but was not given it.
        if (!mounted || !await ensureCameraPermission(context)) return const [];
        final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 2000);
        return x == null ? const [] : [Uri.file(x.path).toString()];
      }
      final res = await FilePicker.platform.pickFiles(allowMultiple: params.mode == FileSelectorMode.openMultiple);
      return res?.files.where((f) => f.path != null).map((f) => Uri.file(f.path!).toString()).toList() ?? const [];
    } catch (_) {
      _snack('Could not open the camera or files. Check the app permissions.');
      return const [];
    }
  }

  /// true = camera, false = files, null = cancelled.
  Future<bool?> _askSource() => showModalBottomSheet<bool>(
        context: context,
        backgroundColor: paper,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Text('Choose from phone'),
              subtitle: const Text('Photos or PDF'),
              onTap: () => Navigator.pop(ctx, false),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---- back button ------------------------------------------------------------------------------

  /// Back closes an open dialog/menu first, then goes to the previous screen, then leaves the app.
  Future<void> _back() async {
    final c = _web;
    if (c == null || _error != null) {
      SystemNavigator.pop();
      return;
    }
    try {
      final r = await c.runJavaScriptReturningResult(
        "(function(){if(document.querySelector('[role=dialog],[role=alertdialog],[role=menu],[role=listbox]')){"
        "document.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true}));return 'closed';}return 'none';})()",
      );
      if (r.toString().contains('closed')) return;
    } catch (_) {
      // page not ready; fall through
    }
    if (await c.canGoBack()) {
      await c.goBack();
    } else {
      SystemNavigator.pop();
    }
  }

  Future<void> _openSettings() async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => SettingsPage(current: _server)));
    if (changed == true) {
      final server = await ServerConfig.load();
      setState(() {
        _server = server;
        _loaded = false;
      });
      await _web?.clearCache();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _web;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: paper,
        body: SafeArea(
          child: Stack(children: [
            if (c != null) WebViewWidget(controller: c),
            if (_progress < 100 && _loaded && _error == null)
              LinearProgressIndicator(value: _progress / 100, minHeight: 2, color: gold, backgroundColor: Colors.transparent),
            if (!_loaded && _error == null) _Splash(slow: _slow, onSettings: _openSettings, onRetry: () => _load()),
            if (_error != null) _Offline(message: _error!, server: _server, onRetry: () => _load(reload: true), onSettings: _openSettings),
          ]),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/logo.webp', width: 88, height: 88, fit: BoxFit.contain)),
        const SizedBox(height: 14),
        const Text('AV Group · BOQ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink)),
        const SizedBox(height: 4),
        const Text('Material management', style: TextStyle(color: mutedText)),
      ]);
}

class _Splash extends StatelessWidget {
  const _Splash({required this.slow, required this.onSettings, required this.onRetry});

  final bool slow;
  final VoidCallback onSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        color: paper,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _Logo(),
          const SizedBox(height: 28),
          const SizedBox(width: 160, child: LinearProgressIndicator(color: gold, backgroundColor: hairline)),
          if (slow) ...[
            const SizedBox(height: 24),
            const Text('Still connecting to the office server…', style: TextStyle(color: mutedText)),
            const SizedBox(height: 12),
            Row(mainAxisSize: MainAxisSize.min, children: [
              OutlinedButton(onPressed: onSettings, child: const Text('Server settings')),
              const SizedBox(width: 12),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ]),
          ],
        ]),
      );
}

class _Offline extends StatelessWidget {
  const _Offline({required this.message, required this.server, required this.onRetry, required this.onSettings});

  final String message;
  final String server;
  final VoidCallback onRetry;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Container(
        color: paper,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const _Logo(),
            const SizedBox(height: 28),
            const Icon(Icons.cloud_off_outlined, size: 40, color: mutedText),
            const SizedBox(height: 12),
            const Text("Can't reach the BOQ server", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ink)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: mutedText, height: 1.4)),
            const SizedBox(height: 6),
            Text(Uri.parse(server).host, textAlign: TextAlign.center, style: const TextStyle(color: mutedText, fontSize: 12)),
            const SizedBox(height: 24),
            SizedBox(width: 240, child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again'))),
            const SizedBox(height: 10),
            SizedBox(width: 240, child: OutlinedButton.icon(onPressed: onSettings, icon: const Icon(Icons.settings_outlined), label: const Text('Server settings'))),
          ]),
        ),
      );
}
