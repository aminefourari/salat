import Foundation

struct Surah: Codable, Identifiable, Sendable {
    let n: Int
    let ar: String
    let en: String
    let ayahs: [String]
    /// [ayah, rubʿ number] where one of the 240 quarters (rubʿ al-hizb) starts in this surah.
    let rub: [[Int]]
    var id: Int { n }
}

/// Rubʿ (1…240) → its juz (1…30), hizb (1…60) and quarter within the hizb (0 = the hizb starts here).
struct RubInfo: Equatable, Sendable {
    let juz, hizb, quarter: Int
    init(_ rub: Int) { juz = (rub + 7) / 8; hizb = (rub + 3) / 4; quarter = (rub - 1) % 4 }
}

struct HizbStart: Equatable, Sendable { let hizb, juz, surah, ayah: Int }

/// A saved ayah (newest first in the list); per device, like the reading position (mirrors the website's `Bookmark`).
struct Bookmark: Codable, Equatable, Sendable { let surah, ayah: Int; let at: Date }
let maxBookmarks = 20
func isBookmarked(_ list: [Bookmark], surah: Int, ayah: Int) -> Bool { list.contains { $0.surah == surah && $0.ayah == ayah } }
/// Adds the ayah at the top (keeping the newest `maxBookmarks`), or removes it when it's already saved.
func toggleBookmark(_ list: [Bookmark], surah: Int, ayah: Int, now: Date) -> [Bookmark] {
    if isBookmarked(list, surah: surah, ayah: ayah) { return list.filter { !($0.surah == surah && $0.ayah == ayah) } }
    return Array(([Bookmark(surah: surah, ayah: ayah, at: now)] + list).prefix(maxBookmarks))
}

/// Where each of the 60 hizbs starts (mirrors `hizbStarts` in apps/web/src/lib/quran.ts).
func hizbStarts(_ surahs: [Surah]) -> [HizbStart] {
    surahs.flatMap { s in
        s.rub.filter { $0[1] % 4 == 1 }.map { HizbStart(hizb: ($0[1] + 3) / 4, juz: ($0[1] + 7) / 8, surah: s.n, ayah: $0[0]) }
    }
}

/// quran.com tafsirs by UI language: Tafsir al-Muyassar (16), plus Ibn Kathir abridged (169) in English (same as the website).
struct TafsirSource: Identifiable, Sendable {
    let id: Int
    let name: String
    var isArabic: Bool { id == 16 }
    static func forLang(_ l: Lang) -> [TafsirSource] {
        let muyassar = TafsirSource(id: 16, name: "التفسير الميسر")
        return l == .en ? [TafsirSource(id: 169, name: "Ibn Kathir (abridged)"), muyassar] : [muyassar]
    }
    func url(surah: Int, ayah: Int) -> URL {
        URL(string: "https://api.quran.com/api/v4/tafsirs/\(id)/by_ayah/\(surah):\(ayah)")!
    }
}

/// quran.com tafsir HTML → plain paragraphs (mirrors `tafsirText` on the web).
func tafsirText(_ html: String) -> [String] {
    let entities = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]
    var s = html.replacing(/(?i)<br\s*\/?>|<\/(p|h\d|div|li)>/, with: "\n")
    s = s.replacing(/<[^>]*>/, with: "")
    s = s.replacing(/(?i)&(#\d+|[a-z]+);/) { m in
        let e = String(m.output.1)
        if e.hasPrefix("#") { return Int(e.dropFirst()).flatMap(UnicodeScalar.init).map { String(Character($0)) } ?? String(m.output.0) }
        return entities[e.lowercased()] ?? String(m.output.0)
    }
    return s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
}

/// Search key for Arabic (mirrors `searchKey` on the web): drops tashkeel, Quranic marks, tatweel, spaces, every alef
/// and lone hamza; a waw carrying a dagger alef (ٱلصَّلَوٰة) reads as an alef, so it matches the typed الصلاة.
func searchKey(_ s: String) -> String {
    var out = String.UnicodeScalarView(), prev: Unicode.Scalar?
    for u in s.unicodeScalars {
        defer { prev = u }
        switch u.value {
        case 0x0670 where prev?.value == 0x0648: out.removeLast()
        case 0x064B...0x065F, 0x0670, 0x06D6...0x06ED, 0x0640, 0x0621, 0x0627, 0x0622, 0x0623, 0x0625, 0x0671: continue
        case 0x0649: out.append(Unicode.Scalar(0x064A)!)
        default: if !u.properties.isWhitespace { out.append(u) }
        }
    }
    return String(out)
}

struct AyahRef: Hashable, Sendable { let surah, ayah: Int }

/// Ayahs containing `q` in mushaf order (at most `limit`); "2:255" (Latin or Arabic digits) is that ayah (mirrors the web).
func searchAyahs(_ q: String, limit: Int = 50) -> [AyahRef] {
    let surahs = QuranText.surahs
    let latin = String(q.unicodeScalars.map { (0x0660...0x0669).contains($0.value) ? Character(Unicode.Scalar($0.value - 0x0660 + 48)!) : Character($0) })
    if let m = latin.wholeMatch(of: /\s*([0-9]+)\s*[:.]\s*([0-9]+)\s*/), let s = Int(m.1), let a = Int(m.2) {
        return (1...surahs.count).contains(s) && (1...surahs[s - 1].ayahs.count).contains(a) ? [AyahRef(surah: s, ayah: a)] : []
    }
    let k = searchKey(q)
    guard k.unicodeScalars.count >= 2, k.unicodeScalars.contains(where: { (0x0600...0x06FF).contains($0.value) }) else { return [] }
    var out: [AyahRef] = []
    for (i, ayahs) in QuranText.searchKeys.enumerated() {
        for (j, text) in ayahs.enumerated() where text.contains(k) {
            out.append(AyahRef(surah: i + 1, ayah: j + 1))
            if out.count == limit { return out }
        }
    }
    return out
}

/// The Uthmani text bundled as quran.json (generated by scripts/fetch-assets.sh).
enum QuranText {
    private final class Anchor {}
    static let surahs: [Surah] = {
        let url = Bundle(for: Anchor.self).url(forResource: "quran", withExtension: "json")!
        return try! JSONDecoder().decode([Surah].self, from: Data(contentsOf: url))
    }()
    static let searchKeys: [[String]] = surahs.map { $0.ayahs.map(searchKey) }
}
