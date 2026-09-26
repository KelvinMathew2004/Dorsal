import SwiftUI

nonisolated enum DreamDateLabel {
    static func string(_ date: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? -1
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        if (0..<7).contains(days) { formatter.setLocalizedDateFormatFromTemplate("EEEE") }
        else { formatter.dateStyle = .medium; formatter.timeStyle = .none }
        return formatter.string(from: date)
    }
}

struct DreamJournalTile: View {
    let store: DreamStore
    let dream: Dream

    var body: some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: dream) {
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(Theme.gradientBackground(.accent))
                    if let data = dream.generatedImageData, let image = UIImage(data: data) {
                        GeometryReader { geometry in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                                .clipped()
                        }
                    }
                    LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.clear)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 24))
                    VStack(alignment: .leading, spacing: 8) {
                        Text(DreamDateLabel.string(dream.date))
                            .font(.caption.weight(.semibold))
                        Text(dream.core?.title ?? "Saved Dream")
                            .font(.title3.weight(.semibold))
                            .lineLimit(3)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                    .padding(20)
                    .padding(.trailing, 36)
                }
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)
            Button {
                store.toggleBookmark(id: dream.id)
            } label: {
                Image(systemName: dream.isBookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .clipShape(Circle())
            .padding(12)
            .accessibilityLabel(dream.isBookmarked ? "Remove Bookmark" : "Bookmark Dream")
        }
    }
}
