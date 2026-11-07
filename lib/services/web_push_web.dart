import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// window.wcPush, which the page loads before the app (ci/web_push.js). null when it is not there
JSObject? get _bridge => globalContext.has('wcPush') ? globalContext['wcPush'] as JSObject? : null;

/// whether the browser can show notifications
bool webPushSupported() {
  final bridge = _bridge;
  if (bridge == null) return false;
  try {
    return bridge.callMethod<JSBoolean>('supported'.toJS).toDart;
  } catch (_) {
    return false;
  }
}

/// granted, denied or default (not asked yet)
String webPushPermission() {
  final bridge = _bridge;
  if (bridge == null) return 'denied';
  try {
    return bridge.callMethod<JSString>('permission'.toJS).toDart;
  } catch (_) {
    return 'denied';
  }
}

/// the token of this browser, asking for the permission when [ask]; null when it may not have one
Future<String?> webPushToken(String configJson, String vapidKey, {required bool ask}) async {
  final bridge = _bridge;
  if (bridge == null) return null;
  final token = await bridge
      .callMethod<JSPromise<JSString?>>('token'.toJS, configJson.toJS, vapidKey.toJS, ask.toJS)
      .toDart;
  return token?.toDart;
}

/// this browser stops getting the notifications
Future<void> webPushRemove(String configJson) async {
  final bridge = _bridge;
  if (bridge == null) return;
  await bridge.callMethod<JSPromise<JSAny?>>('remove'.toJS, configJson.toJS).toDart;
}
