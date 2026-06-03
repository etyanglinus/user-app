importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyBhPVJQjVKv5BqlJIyg1p8FtyLlqBzY1sg",
  authDomain: "fasta-rides-457315.firebaseapp.com",
  databaseURL: "https://fasta-rides-457315-default-rtdb.firebaseio.com",
  projectId: "fasta-rides-457315",
  storageBucket: "fasta-rides-457315.firebasestorage.app",
  messagingSenderId: "833886382257",
  appId: "1:833886382257:web:b347c19f1400383595da90",
  measurementId: "G-R3Q3BLB5ZK"
});

const messaging = firebase.messaging();

messaging.setBackgroundMessageHandler(function (payload) {
    const promiseChain = clients
        .matchAll({
            type: "window",
            includeUncontrolled: true
        })
        .then(windowClients => {
            for (let i = 0; i < windowClients.length; i++) {
                const windowClient = windowClients[i];
                windowClient.postMessage(payload);
            }
        })
        .then(() => {
            const title = payload.notification.title;
            const options = {
                body: payload.notification.score
              };
            return registration.showNotification(title, options);
        });
    return promiseChain;
});
self.addEventListener('notificationclick', function (event) {
    console.log('notification received: ', event)
});