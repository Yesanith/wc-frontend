// The service worker of the app's notifications, next to the app (see web_push.js). A message that comes while the
// app is closed is shown by Firebase, and opens the page it carries when it is clicked. The configuration is written
// in when the site is built.
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

// a notification the page showed while it was open opens the page it is about
self.addEventListener('notificationclick', function (event) {
  var link = event.notification.data && event.notification.data.link;
  if (!link) return;
  event.notification.close();
  event.waitUntil(clients.openWindow(link));
});

firebase.initializeApp(__FIREBASE_CONFIG__);
firebase.messaging();
