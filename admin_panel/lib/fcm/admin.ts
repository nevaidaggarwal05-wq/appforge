// Firebase Admin SDK — singleton for FCM send operations.
// This is the ONLY place we touch Firebase in the whole admin panel.

import { initializeApp, getApps, cert, type App as FirebaseApp } from 'firebase-admin/app';
import { getMessaging, type Messaging } from 'firebase-admin/messaging';

let appInstance: FirebaseApp | null = null;

export function getFirebaseApp(): FirebaseApp {
  if (appInstance) return appInstance;
  const existing = getApps();
  if (existing.length > 0) {
    appInstance = existing[0];
    return appInstance;
  }

  const privateKey = (process.env.FIREBASE_PRIVATE_KEY || '').replace(/\\n/g, '\n');
  if (!process.env.FIREBASE_PROJECT_ID || !process.env.FIREBASE_CLIENT_EMAIL || !privateKey) {
    throw new Error('Firebase Admin SDK env vars missing. See .env.local.example');
  }

  appInstance = initializeApp({
    credential: cert({
      projectId:   process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey
    })
  });
  return appInstance;
}

export function getFcm(): Messaging {
  return getMessaging(getFirebaseApp());
}
