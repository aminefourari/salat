-- Which prayers notify (start and 10-min reminder), a bitmask in PRAYERS order: fajr=1, dhuhr=2, asr=4, maghrib=8, isha=16.
ALTER TABLE subscriptions ADD COLUMN notify_prayers INTEGER NOT NULL DEFAULT 31;
