// The notifications of the app in a browser. Firebase would put its service worker at the root of the site, which on
// GitHub Pages is not the app's: it is put next to the app instead, and Firebase is told to use that one.
// window.wcPush is what the app calls (lib/services/web_push_web.dart).
(function () {
  'use strict';
  var SDK = 'https://www.gstatic.com/firebasejs/10.14.1/';
  var base = new URL('./', document.baseURI);
  var started = null;

  function supported() {
    return 'serviceWorker' in navigator && 'Notification' in window && 'PushManager' in window;
  }

  // the service worker next to the app, once it is running
  async function worker() {
    var reg = await navigator.serviceWorker.register(new URL('firebase-messaging-sw.js', base).pathname, {
      scope: base.pathname,
    });
    if (reg.active) return reg;
    var sw = reg.installing || reg.waiting;
    // a worker that cannot be installed turns redundant and is never activated: it is given up after a while, so that
    // the switch does not turn for ever
    await new Promise(function (done, fail) {
      var timer = setTimeout(function () {
        fail(new Error('the service worker did not start'));
      }, 15000);
      sw.addEventListener('statechange', function () {
        if (sw.state === 'activated') {
          clearTimeout(timer);
          done();
        } else if (sw.state === 'redundant') {
          clearTimeout(timer);
          fail(new Error('the service worker could not be installed'));
        }
      });
    });
    return reg;
  }

  async function start(config) {
    if (started) return started;
    var app = await import(SDK + 'firebase-app.js');
    var m = await import(SDK + 'firebase-messaging.js');
    var messaging = m.getMessaging(app.initializeApp(config, 'wc-push'));
    // while the page is open the browser shows nothing by itself: it is shown here, as it would be closed
    m.onMessage(messaging, async function (payload) {
      var n = payload.notification || {};
      var reg = await navigator.serviceWorker.getRegistration(base.pathname);
      if (!reg) return;
      reg.showNotification(n.title || '', {
        body: n.body || '',
        icon: new URL('icons/Icon-192.png', base).href,
        data: { link: (payload.fcmOptions && payload.fcmOptions.link) || base.href },
      });
    });
    started = { m: m, messaging: messaging };
    return started;
  }

  window.wcPush = {
    supported: supported,
    // granted, denied or default (not asked yet)
    permission: function () {
      return supported() ? Notification.permission : 'denied';
    },
    // asks for the permission when [ask], and gives the token of this browser, or null when it may not have one
    token: async function (configJson, vapidKey, ask) {
      if (!supported()) return null;
      if (Notification.permission !== 'granted') {
        if (!ask || (await Notification.requestPermission()) !== 'granted') return null;
      }
      var s = await start(JSON.parse(configJson));
      return await s.m.getToken(s.messaging, { vapidKey: vapidKey, serviceWorkerRegistration: await worker() });
    },
    // this browser stops getting the notifications
    remove: async function (configJson) {
      try {
        var s = await start(JSON.parse(configJson));
        await s.m.deleteToken(s.messaging);
      } catch (e) {
        // the server forgets a token that is not used
      }
    },
  };
})();
