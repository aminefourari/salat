import SwiftUI

// Filled in by Task 8.
struct QuranView: View {
    let settings: AppSettings
    var body: some View { Text(t(.chooseSurah, settings.d.lang)).frame(maxWidth: .infinity, maxHeight: .infinity) }
}

struct QuranSettingsTab: View {
    let settings: AppSettings
    var body: some View { EmptyView() }
}
