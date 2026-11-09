# Salat for macOS: Adhkar — design

Extends `2026-11-09-salat-macos-design.md`. Built on the same `feat/macos-app` branch, so the Mac app merges once (my call).

## Intent

A Hisn al-Muslim library in the Mac app: the user opens it, picks a category (after salah, morning, evening,
before sleep, travel, rain, Eid…) and reads the adhkar, optionally listening to each one. Like Hisn al-Muslim in
Muslim Pro. The project will always remain free (user decision), which is the basis for using the sources below.

## Goals

- **No automatic prompts (user decision).** Nothing pops up after salah or at events; the user goes to the adhkar.
- **Entry points:** an "Adhkar" button in the menu-bar panel next to "Quran"; an `Adhkar` window (`Window(id: "adhkar")`).
- **Categories (my call):** the book's chapters as they are. Morning and evening stay one chapter
  ("أذكار الصباح والمساء"), as in both sources: entries are written in their morning wording with the evening
  wording in brackets, and the audio recites that text. Splitting them would mean writing evening Arabic that no
  recording matches.
- **Window:** sidebar with all categories in the book's order (hisnmuslim chapter ID order) and a search field that filters category titles
  (in the UI language, plus Arabic). The detail pane lists the category's adhkar. The window reopens on the last category.
- **Each dhikr shows (user decision):**
  - the Arabic text, large, in a proper Arabic font, right-to-left;
  - the repetition count as "×N" (only when N > 1); **no counter** (user decision). The book's Arabic already carries
    count notes inline ("(ثلاث مرات)", "(سبع مرات)", conditional ones like "عشر مرات أو مرة واحدة عند الكسل"), and
    hisnmuslim's `REPEAT` field is sometimes wrong (ID 83: `1` but the text says seven times). **My call:** the Arabic
    is shown as-is (it matches the audio), and the "×N" badge from `REPEAT` is shown only when the Arabic has no
    inline count note; otherwise the text itself states the count. Never show a badge that contradicts the text;
  - a translation in the UI language: English or French; none when the UI is Arabic (my call);
  - the source reference, e.g. "Muslim 4/2083", when one exists;
  - a play button when a recording exists (user decision: audio "if available").
- **Languages:** category titles and dhikr translations follow the app language (ar/en/fr).

### Content sources (user decision: use these two, credited; project stays free; ask permission before any public release)

1. **hisnmuslim.com JSON feed** (`http://www.hisnmuslim.com/api/{ar,en}/husn_{ar,en}.json`, then each chapter's `TEXT`
   URL): 132 chapters; per dhikr `ARABIC_TEXT`, `TRANSLATED_TEXT` (English), `REPEAT`, `AUDIO` (per-dhikr Arabic
   recitation MP3, ~0.3–1.3 MB). No French; references almost always missing.
2. **"La Citadelle du Musulman" AR-FR edition** (`github.com/Kiwifu/la-citadelle-du-musulman`,
   `La_Citadelle_du_Musulman_AR-FR.md`, edited by Badr B. from the Midad "حصن المسلم" app): all 283 numbered
   adhkar under numbered chapter headings, each with Arabic, transliteration, French and the reference line
   (`— *Al-Bukhârî … 11/113, Muslim 4/2083*`).

- **Pairing facts (checked):** hisnmuslim chapter ID n is French chapter n+1 (the French edition adds a "mérite"
  chapter 1), which gives the French title for every chapter. 13 French entries abbreviate long Quranic Arabic
  (Ayat al-Kursi, the three Quls), so matching must handle prefix/containment. Only 213 of 283 French entries have a
  reference line. hisnmuslim chapter 126's JSON has control characters and must be cleaned. Audio is also served
  over HTTPS; use HTTPS.
- **Merge (build time, my call):** a script downloads both and pairs each hisnmuslim dhikr with a French entry by
  comparing Arabic text after normalisation (strip diacritics/tatweel/punctuation, unify alef/ya/ta-marbuta forms),
  best match above a similarity threshold. Chapters are paired the same way via their adhkar. The French title of a
  chapter comes from the French edition's heading. The reference comes from the French entry and is shown as-is
  in every UI language (it is transliterated Latin, readable in English too).
- The script prints a report: unmatched hisnmuslim adhkar (shown without French translation/reference), unmatched
  French entries, and low-confidence pairs. The output is committed as `Salat/Resources/adhkar.json`; the build never
  touches the network.
- The hisnmuslim Arabic is the displayed Arabic (it is what the audio recites). Repeat counts come from hisnmuslim.
- Credits for both sources go in `ATTRIBUTION.md`, with the "free, not for sale" note.

### Audio (my call)

- All recordings together are ~150 MB, too much to bundle. Each dhikr's recording downloads from hisnmuslim.com on
  first play and is kept on disk (`~/Library/Application Support/Salat/adhkar/{id}.mp3`), like Quran recitations.
  Offline and not yet downloaded → a clear message; the text stays readable.
- Settings → Quran tab (renamed "Quran & Adhkar", or a separate Adhkar section, builder's call): "Download all
  adhkar audio" with progress and cancel, size on disk, Delete.
- Playing a dhikr stops a playing Quran recitation and vice-versa; an adhan stops both.
- hisnmuslim.com becomes the second online service the Mac app may contact (only for adhkar audio). The JSON feed
  is only read by the build script.

## Non-goals

- Counter / tasbih, favourites, transliteration, full-text search inside adhkar (left out; transliteration exists in
  the French source if wanted later).
- Notifications or reminders for adhkar (morning/evening reminders etc.).
- Adhkar on the website.

## Anti-goals

- Wrong pairing: a French translation or reference shown under a different dhikr. When unsure, show none.
- Arabic text that doesn't match the audio.
- The app needing the internet to read adhkar.
- Any sale, ads or paid tier (project stays free; the content is "not for sale").

## Left to the builder

- Arabic font for adhkar (the bundled Amiri Quran is tuned for Quran text; a general Arabic font with an OFL
  license, e.g. Amiri, is fine).
- Exact similarity metric/threshold, as long as the report shows the result and spot checks pass
  (e.g. morning/evening Ayat al-Kursi, waking-up adhkar, after-salah tasbih ×33).
- Layout details of the window, matching the Quran window's look.
