CREATE TABLE subscriptions (
  endpoint TEXT PRIMARY KEY,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  tz TEXT NOT NULL,
  method TEXT NOT NULL,
  asr TEXT NOT NULL,
  lang TEXT NOT NULL,
  notify_start INTEGER NOT NULL,
  notify_reminder INTEGER NOT NULL,
  last_sent_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
