import 'dart:async';

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/community.dart';
import 'web_push.dart';

/// set by the release build from the repository secrets. without them the
/// app has no push notifications and never touches firebase
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

/// a browser is a web app of the Firebase project, with an app id of its own, and its Web Push certificate
const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
const _vapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

bool get pushConfigured => kIsWeb
    ? _apiKey.isNotEmpty &&
        _webAppId.isNotEmpty &&
        _senderId.isNotEmpty &&
        _projectId.isNotEmpty &&
        _vapidKey.isNotEmpty
    : _apiKey.isNotEmpty && _appId.isNotEmpty && _senderId.isNotEmpty && _projectId.isNotEmpty;

/// what the page's bridge starts Firebase with in a browser
String get _webConfig => jsonEncode({
      'apiKey': _apiKey,
      'projectId': _projectId,
      'messagingSenderId': _senderId,
      'appId': _webAppId,
    });

bool _ready = false;

/// whether firebase could be started, and the community backend is there to
/// register with
bool get pushReady => _ready && communityReady;

/// notifications that arrive while the app is open. android shows nothing
/// on its own then, the shell shows them in the app instead
final pushWhileOpen = StreamController<RemoteMessage>.broadcast();

/// a notification that was tapped while the app was in the background, with what it carried
final pushTapped = StreamController<Map<String, dynamic>>.broadcast();

/// the notification that was tapped to start the app, with what it carried, until the shell has used it
Map<String, dynamic>? initialPushData;

StreamSubscription<String>? _tokenRefresh;

/// the language the device was last registered in, which a renewed token is registered in too
String _lang = 'en';

/// starts firebase with the values from the build, no google-services.json
/// needed. a failure only switches notifications off
Future<void> initPush() async {
  if (!pushConfigured) return;
  // a browser goes through the page's bridge, which keeps the service worker next to the app
  if (kIsWeb) {
    _ready = webPushSupported();
    return;
  }
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
      ),
    );
    FirebaseMessaging.onMessage.listen(pushWhileOpen.add);
    FirebaseMessaging.onMessageOpenedApp.listen((message) => pushTapped.add(Map<String, dynamic>.from(message.data)));
    final first = await FirebaseMessaging.instance.getInitialMessage();
    if (first != null) initialPushData = Map<String, dynamic>.from(first.data);
    _ready = true;
  } catch (_) {
    _ready = false;
  }
}

/// asks for permission on android 13 and later, and registers this device
/// for the signed in player's reminders in [lang]. false when not allowed.
/// [quiet] asks nothing: a browser is only registered when it already may show notifications, as a browser asks
/// only after a click of the player
Future<bool> enablePush(String lang, {bool quiet = false}) async {
  if (!pushReady || Supabase.instance.client.auth.currentSession == null) return false;
  _lang = lang;
  if (kIsWeb) {
    final token = await webPushToken(_webConfig, _vapidKey, ask: !quiet);
    if (token == null || token.isEmpty) return false;
    await _register(token, lang);
    return true;
  }
  final messaging = FirebaseMessaging.instance;
  final permission = await messaging.requestPermission();
  if (permission.authorizationStatus == AuthorizationStatus.denied) return false;
  final token = await messaging.getToken();
  if (token == null) return false;
  await _register(token, lang);
  // firebase renews tokens now and then, the new one replaces the old
  _tokenRefresh ??= messaging.onTokenRefresh.listen((fresh) => _register(fresh, _lang).catchError((_) {}));
  return true;
}

Future<void> _register(String token, String lang) async {
  if (Supabase.instance.client.auth.currentSession == null) return;
  await Supabase.instance.client.rpc('register_push_device', params: {'p_token': token, 'p_lang': lang});
}

/// this device stops receiving the player's notifications. before signing
/// out, or when they are switched off
Future<void> disablePush() async {
  if (!pushReady) return;
  if (kIsWeb) {
    try {
      final token = await webPushToken(_webConfig, _vapidKey, ask: false);
      if (token != null && Supabase.instance.client.auth.currentSession != null) {
        await Supabase.instance.client.rpc('unregister_push_device', params: {'p_token': token});
      }
      await webPushRemove(_webConfig);
    } catch (_) {
      // signing out goes on
    }
    return;
  }
  await _tokenRefresh?.cancel();
  _tokenRefresh = null;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && Supabase.instance.client.auth.currentSession != null) {
      await Supabase.instance.client.rpc('unregister_push_device', params: {'p_token': token});
    }
  } catch (_) {
    // signing out goes on, the server forgets tokens firebase drops anyway
  }
}
