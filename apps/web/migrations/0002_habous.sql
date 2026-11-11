-- Official Moroccan timetable (Ministry of Habous), imported once per month from habous.gov.ma.
CREATE TABLE habous_months (
  month TEXT PRIMARY KEY,      -- YYYY-MM
  fetched_at INTEGER NOT NULL
);
CREATE TABLE habous_times (
  city INTEGER NOT NULL,       -- Habous city id (src/server/habous-cities.json)
  date TEXT NOT NULL,          -- YYYY-MM-DD, Moroccan calendar day
  fajr INTEGER NOT NULL, sunrise INTEGER NOT NULL, dhuhr INTEGER NOT NULL, -- epoch ms
  asr INTEGER NOT NULL, maghrib INTEGER NOT NULL, isha INTEGER NOT NULL,
  PRIMARY KEY (city, date)
);
