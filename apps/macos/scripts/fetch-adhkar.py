"""Builds Salat/Resources/adhkar.json from two Hisn al-Muslim sources (run by fetch-assets.sh):
  - hisnmuslim.com JSON feed: Arabic, English, repeat count, per-dhikr audio URL
  - "La Citadelle du Musulman" AR-FR edition (Badr B., from the Midad app): French + reference
Pairs them by normalised Arabic text; uncertain pairs get no French/reference.
Usage: python3 -I fetch-adhkar.py OUT.json
"""
import difflib, json, re, sys, urllib.request

HISN = 'https://www.hisnmuslim.com/api'
FR_MD = 'https://raw.githubusercontent.com/Kiwifu/la-citadelle-du-musulman/main/La_Citadelle_du_Musulman_AR-FR.md'
THRESHOLD = 0.6
# hisnmuslim chapter 86 ("for one who says 'may Allah forgive you'") holds only a misplaced copy of dhikr 198
# (chapter 87): drop it, pin the French chapter, and use the French edition's own entry (no audio) instead.
MISPLACED = {86: (198,)}
FR_CHAPTER = {86: 87}


def get(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'salat-mac-assets/1.0'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode('utf-8-sig', errors='replace')


def get_json(url):
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', ' ', get(url).replace('﻿', ''))
    text = re.sub(r'^(\s*)"([^"\n]+):\s*$', r'\1"\2":', text, flags=re.M)  # en chapter 126 lacks a closing quote
    return list(json.loads(text, strict=False).values())[0]


def norm(s):
    s = re.sub('[ً-ٰٟۖ-ۭـ]', '', s)
    for a, b in (('أ', 'ا'), ('إ', 'ا'), ('آ', 'ا'), ('ٱ', 'ا'), ('ى', 'ي'), ('ة', 'ه'), ('ؤ', 'و'), ('ئ', 'ي')):
        s = s.replace(a, b)
    s = re.sub(r'[^ء-ي ]', ' ', s)
    return ' '.join(s.split())


def fragments(raw):
    """The French edition abbreviates long Quran passages ("…", "[آية الكرسي]"): keep the quoted pieces."""
    return [f for f in (norm(x) for x in re.split(r'\.\.\.|…|\[[^\]]*\]', raw)) if len(f) >= 12]


def score(a_raw, b_raw):
    a, b = norm(a_raw), norm(b_raw)
    if not a or not b:
        return 0.0
    ratio = difflib.SequenceMatcher(None, a, b, autojunk=False).ratio()
    short, long_ = sorted((a, b), key=len)
    short_raw = a_raw if len(a) <= len(b) else b_raw
    frags = fragments(short_raw)
    # An abbreviated Quran passage ("…", "[آية الكرسي]") stands for the whole text.
    if len(frags) > 1 or re.search(r'\.\.\.|…|\[', short_raw):
        if frags and sum(map(len, frags)) >= 20 and all(f in long_ for f in frags):
            return max(ratio, 0.9)
    # Plain containment counts only as much as it covers: a quoted verse or one phrase of a longer dua
    # must not beat the dua's real entry.
    if len(short) >= 25 and short in long_:
        return max(ratio, 0.45 + 0.5 * len(short) / len(long_))  # below the 0.6 threshold under ~30% coverage
    return ratio


COUNT_RE = re.compile(r'\b(مره|مرات|مايه|ميه|ثلاثا|سبعا|عشر)\b')  # norm() maps ئ→ي, ة→ه;  # matched against norm(text)


def parse_fr(md):
    """{chapter_no: {'title': str, 'items': [{'ar','fr','ref'}]}}"""
    chapters, cur, item = {}, None, None
    lines = md.split('\n')
    for i, line in enumerate(lines):
        m = re.match(r'^## (\d+)\. (.+)$', line)
        if m:
            cur = chapters.setdefault(int(m.group(1)), {'title': m.group(2).strip(), 'items': []})
            item = None
            continue
        if cur is None:
            continue
        if re.match(r'^\*\*\d+\.\*\*', line):
            item = {'ar': '', 'fr': None, 'ref': None}
            cur['items'].append(item)
            continue
        if item is None:
            continue
        if line.startswith('>'):
            item['ar'] += ' ' + line.lstrip('> ').strip()
        elif line.startswith('— '):
            item['ref'] = line[2:].strip().strip('*').strip()
        elif line.strip() and not line.startswith('*') and not line.startswith('#') and item['fr'] is None and item['ar']:
            item['fr'] = line.strip()
    return chapters


def main(out):
    ar_index = get_json(f'{HISN}/ar/husn_ar.json')
    en_index = {c['ID']: c for c in get_json(f'{HISN}/en/husn_en.json')}
    fr = parse_fr(get(FR_MD))
    result, matched, unmatched, weak = [], 0, [], []
    for ch in sorted(ar_index, key=lambda c: int(c['ID'])):
        cid = int(ch['ID'])
        ar_items = [a for a in get_json(ch['TEXT'].replace('http://', 'https://')) if int(a['ID']) not in MISPLACED.get(cid, ())]
        en_ch = en_index.get(ch['ID']) or en_index.get(cid)
        en_items = {int(x['ID']): x for x in get_json(en_ch['TEXT'].replace('http://', 'https://'))} if en_ch else {}
        # French chapter numbers drift from hisnmuslim's (+1 mostly): pair the chapter with the nearby French chapter
        # whose adhkar match best, then match one-to-one inside that chapter only (a dhikr's reference depends on context).
        def chapter_fit(n):
            return sum(max((score(a['ARABIC_TEXT'], x['ar']) for x in fr[n]['items']), default=0) for a in ar_items)
        cands = [n for n in range(cid - 1, cid + 4) if n in fr]
        fr_no = FR_CHAPTER.get(cid) or max(cands, key=lambda n: (chapter_fit(n), -abs(n - (cid + 1)))) if cands else None
        fr_ch = fr.get(fr_no, {'title': None, 'items': []})
        # A strong direct match (ratio ≥ 0.75) beats abbreviation/containment matches; then by score, then ratio.
        def ratio(x, y):
            return difflib.SequenceMatcher(None, norm(x), norm(y), autojunk=False).ratio()
        pairs = sorted(((r >= 0.75, score(a['ARABIC_TEXT'], x['ar']), r, ai, fi)
                        for ai, a in enumerate(ar_items) for fi, x in enumerate(fr_ch['items'])
                        for r in [ratio(a['ARABIC_TEXT'], x['ar'])]), reverse=True)
        used_a, used_f, best = set(), set(), {}
        for _, sc, _, ai, fi in pairs:
            if ai in used_a or fi in used_f:
                continue
            used_a.add(ai); used_f.add(fi)
            best[ai] = (sc, fr_ch['items'][fi])
        items = []
        for ai, a in enumerate(ar_items):
            did = int(a['ID'])
            s, f = best.get(ai, (0, None))
            ok = f is not None and s >= THRESHOLD
            if ok:
                matched += 1
                if s < 0.75:
                    weak.append((did, round(s, 2)))
            else:
                unmatched.append(did)
            en = en_items.get(did, {})
            audio = (a.get('AUDIO') or '').replace('http://', 'https://') or None
            items.append({
                'id': did,
                'ar': a['ARABIC_TEXT'].strip(),
                'en': (en.get('TRANSLATED_TEXT') or '').strip() or None,
                'fr': f['fr'] if ok else None,
                'ref': f['ref'] if ok else None,
                'repeat': int(a.get('REPEAT') or 1),
                'count_in_text': bool(COUNT_RE.search(norm(a['ARABIC_TEXT']))),
                'audio': audio,
            })
        if not items:  # only the French edition has this chapter's dhikr
            items = [{'id': -(cid * 100 + k), 'ar': f['ar'].strip(' «».'), 'en': None, 'fr': f['fr'],
                      'ref': f['ref'], 'repeat': 1, 'count_in_text': False, 'audio': None}
                     for k, f in enumerate(fr_ch['items'], 1)]
            print(f'chapter {cid}: filled from the French edition ({len(items)} adhkar, no audio)')
        result.append({'id': cid, 'ar': ch['TITLE'].strip(), 'en': (en_ch or {}).get('TITLE', ch['TITLE']).strip(),
                       'fr': fr_ch['title'], 'items': items})
    json.dump(result, open(out, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    total = sum(len(c['items']) for c in result)
    print(f'{len(result)} chapters, {total} adhkar; French matched {matched}, unmatched {len(unmatched)}; weak (<0.75): {len(weak)}')
    print('unmatched ids:', unmatched)
    print('weak:', weak)


if __name__ == '__main__':
    main(sys.argv[1])
