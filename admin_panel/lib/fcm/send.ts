// FCM send logic — handles all four targeting modes.
// Returns success/failure counts without throwing (errors captured in result).

import { getFcm } from './admin';
import type { App, Notification } from '../supabase/types';

export interface FcmResult {
  success: number;
  failure: number;
  error?: string;
}

type NotifPayload = Pick<Notification,
  'title' | 'body' | 'image_url' | 'deep_link_url' | 'category' | 'target_type' | 'target_value'
>;

export async function sendNotification(app: App, notif: NotifPayload): Promise<FcmResult> {
  const fcm = getFcm();

  const baseMessage: any = {
    notification: {
      title: notif.title,
      body:  notif.body,
      ...(notif.image_url ? { imageUrl: notif.image_url } : {})
    },
    data: {
      ...(notif.deep_link_url ? { url: notif.deep_link_url } : {}),
      category: notif.category,
      app_id:   app.id
    },
    android: {
      priority: 'high',
      notification: {
        channelId: notif.category,
        sound:     'default'
      }
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          badge: 1,
          'mutable-content': 1
        }
      }
    }
  };

  try {
    // "all" = all users of this specific app (via per-app topic)
    if (notif.target_type === 'all') {
      const topic = `app_${app.id.replace(/-/g, '_')}`;
      await fcm.send({ ...baseMessage, topic });
      return { success: 1, failure: 0 };
    }

    // explicit topic
    if (notif.target_type === 'topic' && notif.target_value) {
      await fcm.send({ ...baseMessage, topic: notif.target_value });
      return { success: 1, failure: 0 };
    }

    // comma-separated tokens
    if (notif.target_type === 'tokens' && notif.target_value) {
      const tokens = notif.target_value.split(',').map(t => t.trim()).filter(Boolean);
      if (tokens.length === 0) return { success: 0, failure: 0, error: 'No tokens provided' };
      const resp = await fcm.sendEachForMulticast({ ...baseMessage, tokens });
      return { success: resp.successCount, failure: resp.failureCount };
    }

    return { success: 0, failure: 0, error: `Unsupported target_type: ${notif.target_type}` };
  } catch (err: any) {
    return { success: 0, failure: 1, error: err.message || String(err) };
  }
}
