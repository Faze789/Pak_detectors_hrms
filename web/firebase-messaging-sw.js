// firebase-messaging-sw.js
// Place this file at: web/firebase-messaging-sw.js

importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

// ── Your Firebase config ──────────────────────────────────────
// Copy these values from Firebase Console →
// Project Settings → General → Your apps → Web app → SDK setup
firebase.initializeApp({
  apiKey:            "YOUR_API_KEY",
  authDomain:        "YOUR_PROJECT_ID.firebaseapp.com",
  projectId:         "YOUR_PROJECT_ID",
  storageBucket:     "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_SENDER_ID",
  appId:             "YOUR_APP_ID",
});

const messaging = firebase.messaging();

// Handle background messages on web
messaging.onBackgroundMessage((payload) => {
  console.log("[SW] Background message:", payload);

  const title = payload.notification?.title ?? payload.data?.title ?? "HRMS";
  const body  = payload.notification?.body  ?? payload.data?.body  ?? "";

  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
  });
});