#!/bin/sh
# Regenerates the bundled Quran text, Quran font and adhan recordings in Salat/Resources.
# Outputs are committed; run only to refresh them. Needs curl, python3, ffmpeg.
set -e
R="$(cd "$(dirname "$0")/.." && pwd)/Salat/Resources"
DATA="$(cd "$(dirname "$0")/../../.." && pwd)/data"  # shared with the website
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$R/adhans"

# Quran text (Uthmani) + surah names, from quran.com.
curl -sf https://api.quran.com/api/v4/chapters -o "$T/chapters.json"
curl -sf https://api.quran.com/api/v4/quran/verses/uthmani -o "$T/verses.json"
python3 -I - "$T/chapters.json" "$T/verses.json" "$DATA/quran.json" <<'PY'
import json, sys
ch = json.load(open(sys.argv[1]))['chapters']
vs = json.load(open(sys.argv[2]))['verses']
out = [{'n': c['id'], 'ar': c['name_arabic'], 'en': c['name_simple'], 'ayahs': []} for c in ch]
for v in vs:
    s, a = map(int, v['verse_key'].split(':'))
    assert len(out[s - 1]['ayahs']) == a - 1
    out[s - 1]['ayahs'].append(v['text_uthmani'])
json.dump(out, open(sys.argv[3], 'w'), ensure_ascii=False, separators=(',', ':'))
PY

# Quran font (SIL OFL).
curl -sfL https://github.com/google/fonts/raw/main/ofl/amiriquran/AmiriQuran-Regular.ttf -o "$R/AmiriQuran-Regular.ttf"
curl -sfL https://github.com/google/fonts/raw/main/ofl/amiriquran/OFL.txt -o "$R/AmiriQuran-OFL.txt"
curl -sfL https://github.com/google/fonts/raw/main/ofl/amiri/Amiri-Regular.ttf -o "$R/Amiri-Regular.ttf"
curl -sfL https://github.com/google/fonts/raw/main/ofl/amiri/OFL.txt -o "$R/Amiri-OFL.txt"
# The website's fonts: Reem Kufi (titles) and IBM Plex Sans Arabic (text), SIL OFL.
curl -sfL "https://github.com/google/fonts/raw/main/ofl/reemkufi/ReemKufi%5Bwght%5D.ttf" -o "$R/ReemKufi.ttf"
curl -sfL https://github.com/google/fonts/raw/main/ofl/reemkufi/OFL.txt -o "$R/ReemKufi-OFL.txt"
for w in Regular SemiBold; do
  curl -sfL "https://github.com/google/fonts/raw/main/ofl/ibmplexsansarabic/IBMPlexSansArabic-$w.ttf" -o "$R/IBMPlexSansArabic-$w.ttf"
done
curl -sfL https://github.com/google/fonts/raw/main/ofl/ibmplexsansarabic/OFL.txt -o "$R/IBMPlexSansArabic-OFL.txt"

# Adhkar (Hisn al-Muslim): merged text, see fetch-adhkar.py for the pairing report.
python3 -I "$(dirname "$0")/fetch-adhkar.py" "$DATA/adhkar.json"

# Adhans from Wikimedia Commons → mono AAC.
adhan() { # id url
  curl -sfL -A "salat-mac-assets/1.0" "$2" -o "$T/$1.src"
  ffmpeg -loglevel error -y -i "$T/$1.src" -vn -ac 1 -b:a 96k "$R/adhans/$1.m4a"
}
adhan hassan2 "https://upload.wikimedia.org/wikipedia/commons/9/9c/Llamada_a_oraci%C3%B3n_Mezquita_Hassan_II.wav"
adhan fakhry "https://upload.wikimedia.org/wikipedia/commons/2/27/Call_to_prayer_by_Sabah_Fakhry.mp3"
adhan beautiful "https://upload.wikimedia.org/wikipedia/commons/b/b0/Beautiful_adhan.ogg"
adhan azan "https://upload.wikimedia.org/wikipedia/commons/8/86/Azan.ogg"

cat > "$R/ATTRIBUTION.md" <<'MD'
# Bundled assets

- `data/quran.json` (repo root, shared with the website): Uthmani text and surah names from [quran.com](https://quran.com) (api.quran.com/api/v4).
- `AmiriQuran-Regular.ttf`: Amiri Quran by Khaled Hosny, SIL Open Font License 1.1 (`AmiriQuran-OFL.txt`).
- `Amiri-Regular.ttf`: Amiri by Khaled Hosny, SIL Open Font License 1.1 (`Amiri-OFL.txt`).
- `ReemKufi.ttf`: Reem Kufi by Khaled Hosny, SIL Open Font License 1.1 (`ReemKufi-OFL.txt`).
- `IBMPlexSansArabic-*.ttf`: IBM Plex Sans Arabic by IBM, SIL Open Font License 1.1 (`IBMPlexSansArabic-OFL.txt`).
- `data/adhkar.json` (repo root, shared with the website): Hisn al-Muslim (حصن المسلم) by Sa'id ibn Wahf al-Qahtani, merged by `scripts/fetch-adhkar.py` from
  - [hisnmuslim.com](https://www.hisnmuslim.com): Arabic text, English translation, repetitions, audio (streamed on demand)
  - [La Citadelle du Musulman, AR-FR](https://github.com/Kiwifu/la-citadelle-du-musulman), edited by Badr B. from the Midad app «حصن المسلم»: French translation and references
  - The book is distributed free: «الكتاب مجاني وغير مسموح ببيعه» (free, not for sale). Salat is and stays free. Ask both sources for permission before any public release.
- `borders.json`: country borders from [country-coder](https://github.com/rapideditor/country-coder) (ISC), exported by `apps/web/test/mac-data.test.ts`.
- `cities.txt`: [GeoNames](https://www.geonames.org) cities5000, CC BY 4.0.
- Adhans (Wikimedia Commons, converted to mono AAC):
  - `adhans/hassan2.m4a`: [Llamada a oración Mezquita Hassan II](https://commons.wikimedia.org/wiki/File:Llamada_a_oraci%C3%B3n_Mezquita_Hassan_II.wav) by Fraguando, CC BY-SA 4.0
  - `adhans/fakhry.m4a`: [Call to prayer by Sabah Fakhry](https://commons.wikimedia.org/wiki/File:Call_to_prayer_by_Sabah_Fakhry.mp3), public domain
  - `adhans/beautiful.m4a`: [Beautiful adhan](https://commons.wikimedia.org/wiki/File:Beautiful_adhan.ogg) by Adam-synagda, CC0
  - `adhans/azan.m4a`: [Azan](https://commons.wikimedia.org/wiki/File:Azan.ogg) by Andrewler, CC BY-SA 4.0
- Adhans downloaded on first use (not bundled, not redistributed by Salat; no license stated by the uploaders) from the
  [Internet Archive](https://archive.org): Madinah, Sheikh Essam Bukhari (`SheikhEssamBukhari`); Mishary Rashid Alafasy
  (`VeryBeautifulAdhaanByMisharyAlAfasy`); Al-Aqsa (`AzanMagribDomeOfRockFri11.4.14`); Abdul Basit and Mishary Fajr
  (`adhans_sunnah`); Makkah Fajr, Sheikh Ali Ahmed Mulla (`MakkahFajrAdhan6913SheikhAliMullah`). Users can also add their own file.
MD
echo "assets → $R"
