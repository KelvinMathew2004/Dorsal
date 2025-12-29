import SwiftUI
import PhotosUI

struct ProfileView: View {
    @ObservedObject var store: DreamStore
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedCategory: String = "People"
    
    let categories = ["People", "Places", "Symbols"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        
                        // MARK: - Header (Photo + Names)
                        // Centered Horizontally
                        HStack(spacing: 24) {
                            // Left: Profile Picture
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                if let data = store.profileImageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 90, height: 90)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 2))
                                        .shadow(color: .black.opacity(0.3), radius: 10)
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(.white.opacity(0.1))
                                            .frame(width: 90, height: 90)
                                            .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
                                        
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 35))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                            }
                            .onChange(of: selectedItem) {
                                Task {
                                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                                        withAnimation {
                                            store.profileImageData = data
                                        }
                                    }
                                }
                            }
                            
                            // Right: Split Name Fields (First Name on Top, Last Name Below)
                            // Plain text style, click to edit
                            VStack(alignment: .leading, spacing: 2) {
                                TextField("First Name", text: $store.firstName)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)
                                    .submitLabel(.next)
                                    .textInputAutocapitalization(.words)
                                
                                TextField("Last Name", text: $store.lastName)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .submitLabel(.done)
                                    .textInputAutocapitalization(.words)
                            }
                        }
                        .padding(.top, 40)
                        .frame(maxWidth: .infinity, alignment: .center)
                        
                        // MARK: - Single Line Stats Row
                        HStack(spacing: 2) {
                            // Block 1: Streak (Rounded Left)
                            ContinuousStatBlock(
                                title: "Streak",
                                value: "\(store.currentStreak)",
                                icon: "flame.fill",
                                color: .orange,
                                corners: [.topLeft, .bottomLeft]
                            )
                            
                            // Block 2: Dreams (No Rounding)
                            ContinuousStatBlock(
                                title: "Dreams",
                                value: "\(store.dreams.count)",
                                icon: "moon.fill",
                                color: .purple,
                                corners: []
                            )
                            
                            // Block 3: Places (No Rounding)
                            ContinuousStatBlock(
                                title: "Places",
                                value: "\(store.allPlaces.count)",
                                icon: "map.fill",
                                color: .green,
                                corners: []
                            )
                            
                            // Block 4: People (Rounded Right)
                            ContinuousStatBlock(
                                title: "People",
                                value: "\(store.allPeople.count)",
                                icon: "person.2.fill",
                                color: .blue,
                                corners: [.topRight, .bottomRight]
                            )
                        }
                        .padding(.horizontal)
                        
                        // MARK: - Category Filter
                        VStack(alignment: .leading, spacing: 16) {
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(categories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            
                            // List items based on category
                            LazyVStack(spacing: 12) {
                                ForEach(itemsForCategory, id: \.self) { item in
                                    Button {
                                        store.jumpToFilter(type: filterTypeForCategory, value: item)
                                    } label: {
                                        HStack {
                                            Image(systemName: iconForCategory)
                                                .foregroundStyle(.white.opacity(0.7))
                                                .frame(width: 30)
                                            
                                            Text(item.capitalized)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.white)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.white.opacity(0.3))
                                        }
                                        .padding()
                                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    var itemsForCategory: [String] {
        switch selectedCategory {
        case "People": return store.allPeople
        case "Places": return store.allPlaces
        case "Symbols": return store.allTags
        default: return []
        }
    }
    
    var filterTypeForCategory: String {
        switch selectedCategory {
        case "People": return "person"
        case "Places": return "place"
        case "Symbols": return "tag"
        default: return ""
        }
    }
    
    var iconForCategory: String {
        switch selectedCategory {
        case "People": return "person.fill"
        case "Places": return "map.fill"
        case "Symbols": return "star.fill"
        default: return "circle.fill"
        }
    }
}

// Custom Continuous Stat Block
struct ContinuousStatBlock: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let corners: UIRectCorner
    
    var body: some View {
        ZStack {
            // Background Layer: Glass Effect Base
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.7) // Slightly more translucent for glass look
                .clipShape(CustomCorner(corners: corners, radius: 20))
            
            // Icon Layer: Centered Background
            // We use a GeometryReader-like approach or simple Frame max
            ZStack {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundStyle(color.opacity(0.15))
                    // Ensure it stays centered in the block
            }
            .clipShape(CustomCorner(corners: corners, radius: 20))
            
            // Foreground Content: Centered Text
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8) // Allow shrinking if number is huge
                    .lineLimit(1)
                
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .tracking(0.5)
            }
            .padding(.vertical, 24)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }
}

// Helper for custom corners
struct CustomCorner: Shape {
    var corners: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
