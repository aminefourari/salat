-- Morning/evening adhkar and Friday reminders; per-prayer minute offsets (JSON, e.g. {"maghrib":3}).
ALTER TABLE subscriptions ADD COLUMN notify_adhkar INTEGER NOT NULL DEFAULT 0;
ALTER TABLE subscriptions ADD COLUMN notify_friday INTEGER NOT NULL DEFAULT 0;
ALTER TABLE subscriptions ADD COLUMN adjust TEXT NOT NULL DEFAULT '{}';
