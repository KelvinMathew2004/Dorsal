import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var store: DreamStore
    @Binding var showOnboarding: Bool
    @Environment(\.dismiss) var dismiss
    
    // Alert State for Permissions
    @State private var showSettingsAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        appearanceSection
                        notificationsSection
                        dataSection
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
            .alert("Notifications Disabled", isPresented: $showSettingsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Please enable notifications in Settings to set a daily reminder.")
            }
        }
    }
    
    // MARK: - COMPONENT SECTIONS
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                if let icon = UIImage(named: "Icon") {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 160, height: 160)
                        .shadow(color: .purple.opacity(0.7), radius: 15)
                } else {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(LinearGradient(
                            colors: [Theme.accent, Theme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 160, height: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: .purple.opacity(0.7), radius: 15)
                    
                    Image(systemName: "waveform.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 40)
            
            VStack(spacing: 4) {
                Text("Dorsal")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("v1.0.0 (Beta)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Appearance", systemImage: "paintpalette.fill")
                .font(.headline)
                .foregroundStyle(Theme.secondary)
            
            // Replaced the variable with this extracted View
            ThemeWheelSelector(currentThemeID: $store.currentThemeID)
        }
    }
    
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Notifications", systemImage: "bell.badge.fill")
                .font(.headline)
                .foregroundStyle(Theme.secondary)
        
            VStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { store.isReminderEnabled },
                    set: { newValue in checkPermissionAndToggle(newValue) }
                )) {
                    Text("Daily Reminder")
                        .foregroundStyle(.white)
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                
                if store.isReminderEnabled {
                    HStack {
                        Text("Time")
                            .foregroundStyle(.white)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { Date(timeIntervalSince1970: store.reminderTime) },
                            set: {
                                store.reminderTime = $0.timeIntervalSince1970
                                store.scheduleDailyReminder()
                            }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                    }
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
    
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Data & Storage", systemImage: "internaldrive.fill")
                .font(.headline)
                .foregroundStyle(Theme.secondary)
            
            HStack {
                Text("Space Used")
                    .foregroundStyle(.white)
                Spacer()
                Text(store.storageUsageString)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding()
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            
            Button {
                dismiss()
                store.resetOnboarding()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showOnboarding = true
                }
            } label: {
                HStack {
                    Text("Revisit Onboarding")
                    Spacer()
                    Image(systemName: "rectangle.and.hand.point.up.left.filled")
                }
                .foregroundStyle(.white)
            }
            .padding()
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - LOGIC
    
    private func checkPermissionAndToggle(_ newValue: Bool) {
        if !newValue {
            store.toggleReminder(enabled: false)
        } else {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let status = settings.authorizationStatus
                DispatchQueue.main.async {
                    switch status {
                    case .authorized, .provisional:
                        store.toggleReminder(enabled: true)
                    case .denied:
                        showSettingsAlert = true
                    case .notDetermined:
                        store.requestNotificationAccess()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            if store.hasNotificationAccess {
                                store.toggleReminder(enabled: true)
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
}

// MARK: - ISOLATED THEME SELECTOR
struct ThemeWheelSelector: View {
    @Binding var currentThemeID: String
    
    // Local State (Updates fast, doesn't redraw screen)
    @State private var scrollPosition: String?
    
    // Joystick State
    @State private var dragDirection: Int = 0
    @State private var timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            let itemWidth: CGFloat = 60
            let spacing: CGFloat = 0
            let margin = (geo.size.width - itemWidth) / 2
            
            ZStack(alignment: .center) {
                // ScrollView Content
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: spacing) {
                            ForEach(0..<20, id: \.self) { loopIndex in
                                ForEach(Theme.availableThemes) { option in
                                    themeItem(option: option, loopIndex: loopIndex, proxy: proxy)
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollPosition(id: $scrollPosition, anchor: .center)
                    .scrollTargetBehavior(.viewAligned)
                    .contentMargins(.horizontal, margin, for: .scrollContent)
                    
                    // 1. Handle NORMAL swipes (Snap updates when idle)
                    .onScrollPhaseChange { oldPhase, newPhase in
                        if newPhase == .idle, let position = scrollPosition {
                            updateStore(with: position)
                        }
                    }
                }
                .frame(height: 80)
                .mask {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                        RoundedRectangle(cornerRadius: 12)
                            .frame(width: 60, height: 80)
                    }
                    .compositingGroup()
                }
                
                // Glass Joystick Overlay
                RoundedRectangle(cornerRadius: 12)
                    .frame(width: 63, height: 83)
                    .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 4)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                let threshold: CGFloat = 40
                                if value.translation.width > threshold {
                                    if dragDirection != 1 {
                                        dragDirection = 1
                                        startTimer()
                                    }
                                } else if value.translation.width < -threshold {
                                    if dragDirection != -1 {
                                        dragDirection = -1
                                        startTimer()
                                    }
                                } else {
                                    if dragDirection != 0 {
                                        dragDirection = 0
                                        stopTimer() // <--- Updates Store
                                    }
                                }
                            }
                            .onEnded { _ in
                                dragDirection = 0
                                stopTimer() // <--- Updates Store
                            }
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: 120)
        
        // Timer Receiver
        .onReceive(timer) { _ in
            guard dragDirection != 0 else { return }
            // This just updates local 'scrollPosition'
            // It does NOT touch 'currentThemeID' yet!
            if dragDirection == 1 {
                scrollToPrevious(isAuto: true)
            } else {
                scrollToNext(isAuto: true)
            }
        }
        
        .onAppear {
            self.timer.upstream.connect().cancel()
            if scrollPosition == nil {
                scrollPosition = "10-\(currentThemeID)"
            }
        }
    }
    
    // MARK: - Logic
    
    private func updateStore(with positionID: String) {
        let components = positionID.split(separator: "-")
        if components.count == 2 {
            let themeID = String(components[1])
            // Only update the heavy binding if it's different
            if currentThemeID != themeID {
                currentThemeID = themeID
            }
        }
    }
    
    private func startTimer() {
        self.timer.upstream.connect().cancel()
        self.timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
        
        // Fire once immediately
        if dragDirection == 1 { scrollToPrevious(isAuto: true) }
        else if dragDirection == -1 { scrollToNext(isAuto: true) }
    }
    
    private func stopTimer() {
        self.timer.upstream.connect().cancel()
        
        // 2. CRITICAL FIX: Only update the store when the user LETS GO
        if let pos = scrollPosition {
            updateStore(with: pos)
        }
    }
    
    private func scrollToNext(isAuto: Bool = false) {
        guard let currentID = scrollPosition else { return }
        moveSelection(currentID: currentID, direction: 1, isAuto: isAuto)
    }
    
    private func scrollToPrevious(isAuto: Bool = false) {
        guard let currentID = scrollPosition else { return }
        moveSelection(currentID: currentID, direction: -1, isAuto: isAuto)
    }
    
    private func moveSelection(currentID: String, direction: Int, isAuto: Bool) {
        let components = currentID.split(separator: "-")
        guard components.count == 2, let loopIndex = Int(components[0]) else { return }
        
        let themeID = String(components[1])
        guard let themeIndex = Theme.availableThemes.firstIndex(where: { $0.id == themeID }) else { return }
        
        let themeCount = Theme.availableThemes.count
        var newThemeIndex = themeIndex + direction
        var newLoopIndex = loopIndex
        
        if newThemeIndex >= themeCount {
            newThemeIndex = 0
            newLoopIndex += 1
        } else if newThemeIndex < 0 {
            newThemeIndex = themeCount - 1
            newLoopIndex -= 1
        }
        
        let nextTheme = Theme.availableThemes[newThemeIndex]
        let nextID = "\(newLoopIndex)-\(nextTheme.id)"
        
        let animation: Animation = isAuto ? .linear(duration: 0.3) : .spring(response: 0.4, dampingFraction: 0.7)
        
        withAnimation(animation) {
            scrollPosition = nextID
        }
    }

    @ViewBuilder
    private func themeItem(option: ThemeOption, loopIndex: Int, proxy: ScrollViewProxy) -> some View {
        let viewID = "\(loopIndex)-\(option.id)"
        ThemeOptionRectangle(option: option)
            .id(viewID)
            .onTapGesture {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    scrollPosition = viewID
                    proxy.scrollTo(viewID, anchor: .center)
                }
            }
    }
}
// THEME RECTANGLE COMPONENT
struct ThemeOptionRectangle: View {
    let option: ThemeOption
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(option.accent)
        }
        .frame(width: 60, height: 80)
    }
}
