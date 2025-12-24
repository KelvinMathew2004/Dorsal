import SwiftUI

struct DreamDetailView: View {
    let dream: SavedDream
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(dream.title)
                    .font(.largeTitle)
                    .bold()
                
                HStack {
                    Text(dream.sentiment)
                        .padding(8)
                        .background(.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text(dream.date, style: .date)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                Text("Interpretation")
                    .font(.headline)
                
                Text(dream.interpretation)
                    .font(.body)
                
                Divider()
                
                Text("Themes")
                    .font(.headline)
                
                // Using TagLayout to avoid 'FlowLayout' redeclaration conflict
                TagLayout(items: dream.themes) { theme in
                    Text(theme)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.purple.opacity(0.1))
                        .cornerRadius(20)
                }
                
                Divider()
                
                Text("Original Recording")
                    .font(.headline)
                
                Text(dream.rawText)
                    .font(.body)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Renamed to TagLayout to fix "Invalid redeclaration of FlowLayout"
struct TagLayout<Content: View>: View {
    let items: [String]
    let content: (String) -> Content
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}
