/// whether the browser can show notifications. never outside a browser
bool webPushSupported() => false;

/// granted, denied or default (not asked yet)
String webPushPermission() => 'denied';

/// the token of this browser, asking for the permission when [ask]; null when it may not have one
Future<String?> webPushToken(String configJson, String vapidKey, {required bool ask}) async => null;

/// this browser stops getting the notifications
Future<void> webPushRemove(String configJson) async {}
