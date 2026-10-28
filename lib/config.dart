import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The live AV BOQ web app (ngrok tunnel to the office laptop). Changeable in Settings without a rebuild.
const defaultServer = 'https://keturah-incontestable-subaxially.ngrok-free.dev';

/// A non-browser user agent: ngrok's free plan skips its "you are about to visit" page for these.
const appUserAgent = 'AVBOQ-Android/1.0 (WebView)';

// Same palette as the web app (neutral ink + gold accent).
const gold = Color(0xFFE0A526);
const ink = Color(0xFF211F1B);
const paper = Color(0xFFFAF9F6);
const hairline = Color(0xFFE6E3DC);
const mutedText = Color(0xFF6F6B63);
const danger = Color(0xFFB42318);

class ServerConfig {
  static const _key = 'server_url';

  static Future<String> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_key) ?? defaultServer;
  }

  static Future<void> save(String url) async {
    final p = await SharedPreferences.getInstance();
    if (url == defaultServer) {
      await p.remove(_key);
    } else {
      await p.setString(_key, url);
    }
  }

  /// Trims, adds https:// when missing and drops trailing slashes. Returns null if it isn't a usable address.
  static String? normalise(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;
    if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'https://$s';
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    final u = Uri.tryParse(s);
    if (u == null || u.host.isEmpty) return null;
    return s;
  }

  /// null when the server answered, otherwise a short reason for the person on site.
  static Future<String?> check(String base) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(Uri.parse('$base/'));
      req.headers.set(HttpHeaders.userAgentHeader, appUserAgent);
      final res = await req.close().timeout(const Duration(seconds: 15));
      await res.drain<void>();
      if (res.statusCode == 200) return null;
      if (res.statusCode == 404) return 'The tunnel is up but the BOQ app is not running on the office laptop.';
      return 'Server answered with error ${res.statusCode}.';
    } on SocketException {
      return 'No internet, or the address is wrong.';
    } on HandshakeException {
      return 'Secure connection failed. Check the address.';
    } catch (_) {
      return 'Server did not answer. Is the office laptop on?';
    } finally {
      client.close(force: true);
    }
  }
}
