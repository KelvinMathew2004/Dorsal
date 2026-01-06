import SwiftUI
import AVFoundation
import Speech
import PhotosUI

// MARK: - Main Onboarding Container

enum OnboardingStep {
    case welcome     // New: Just the logo and welcome text
    case profile     // Name and Photo
    case permissions
    case notifications
    case allSet
}

struct OnboardingView: View {
    @ObservedObject var store: DreamStore
    @State private var currentStep: OnboardingStep = .welcome
    
    var body: some View {
        ZStack {
            // 1. Base Layer: Deep Black
            Color.black.ignoresSafeArea()
            
            // 2. Star Field: Explicitly ensuring opacity is high enough and it's visible
            // Note: Assuming WarpStarField is defined elsewhere in your project
            WarpStarField(starCount: 300, speed: 0.2)
                .opacity(1.0)
                .ignoresSafeArea()
            
            // 3. Gradient Overlay: Lighter to ensure stars show through
            LinearGradient(
                colors: [
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Tracker (Hidden on Welcome and All Set)
                if currentStep != .welcome && currentStep != .allSet {
                    OnboardingProgressView(currentStep: currentStep)
                        .zIndex(10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Content Switcher
                Group {
                    switch currentStep {
                    case .welcome:
                        WelcomeIntroView(currentStep: $currentStep)
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .leading).combined(with: .opacity)))
                    case .profile:
                        ProfileSetupView(store: store, currentStep: $currentStep)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading).combined(with: .opacity)))
                    case .permissions:
                        PermissionsView(store: store, currentStep: $currentStep)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading).combined(with: .opacity)))
                    case .notifications:
                        NotificationOnboardingView(store: store, currentStep: $currentStep)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading).combined(with: .opacity)))
                    case .allSet:
                        AllSetView(store: store)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)
    }
}

// MARK: - Step 1: Welcome Intro (Logo Only)

struct WelcomeIntroView: View {
    @Binding var currentStep: OnboardingStep
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo
            if let uiImage = UIImage(named: "logo") {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .cornerRadius(30)
                    .shadow(color: .white.opacity(0.2), radius: 20, x: 0, y: 0)
            } else {
                // Fallback if "logo" isn't found
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            
            VStack(spacing: 12) {
                Text("Welcome to Dorsal")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                
                Text("Your personal dream journal and analyzer.")
                    .font(.title3)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation { currentStep = .profile }
            }) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Step 2: Profile Setup

struct ProfileSetupView: View {
    @ObservedObject var store: DreamStore
    @Binding var currentStep: OnboardingStep
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("Let's get to know you.")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            // Profile Image Picker
            VStack {
                if let data = store.profileImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.white.opacity(0.5))
                        )
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                }
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("Set Photo")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .glassEffect(.regular)
                }
                .padding(.top, -20)
            }
            .onChange(of: selectedItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run { store.profileImageData = data }
                    }
                }
            }
            
            // Name Fields
            VStack(spacing: 16) {
                CustomTextField(placeholder: "First Name", text: $store.firstName)
                CustomTextField(placeholder: "Last Name", text: $store.lastName)
            }
            .padding(.horizontal, 32)
            
            Spacer()
            
            // Continue Button
            Button(action: {
                withAnimation { currentStep = .permissions }
            }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .disabled(store.firstName.isEmpty || store.lastName.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 3: Permissions

struct PermissionsView: View {
    @ObservedObject var store: DreamStore
    @Binding var currentStep: OnboardingStep
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                    .scaleEffect(animate ? 1.2 : 0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animate)
                
                // Icon
                Image(systemName: "waveform.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .cyan)
                    .symbolColorRenderingMode(.gradient)
                    .symbolEffect(.drawOn.individually, options: .repeating, isActive: !animate)
            }
            
            VStack(spacing: 16) {
                Text("Enable Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("To analyze your dreams, we need access to your microphone and speech recognition.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Permission Buttons
            VStack(spacing: 16) {
                PermissionRow(
                    title: "Microphone Access",
                    icon: "mic.fill",
                    isGranted: store.hasMicAccess,
                    action: {
                        Task {
                            if await AVAudioApplication.requestRecordPermission() {
                                await MainActor.run {
                                    store.requestMicrophoneAccess()
                                }
                            } else {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    await UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                )
                
                PermissionRow(
                    title: "Speech Recognition",
                    icon: "text.bubble.fill",
                    isGranted: store.hasSpeechAccess,
                    action: {
                        SFSpeechRecognizer.requestAuthorization { authStatus in
                            Task {
                                await MainActor.run {
                                    switch authStatus {
                                    case .authorized:
                                        store.requestSpeechAccess()
                                    case .denied, .restricted, .notDetermined:
                                        if let url = URL(string: UIApplication.openSettingsURLString) {
                                            UIApplication.shared.open(url)
                                        }
                                    @unknown default:
                                        break
                                    }
                                }
                            }
                        }
                    }
                )
            }
            .padding(.horizontal, 24)
            
            // Continue Button
            if store.hasMicAccess && store.hasSpeechAccess {
                Button(action: {
                    withAnimation {
                        currentStep = .notifications
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                 Text("Please enable permissions to continue")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.5))
                    .padding(.bottom, 40)
            }
        }
        .padding(.vertical)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                animate = true
            }
        }
    }
}

// MARK: - Step 4: Notifications

struct NotificationOnboardingView: View {
    @ObservedObject var store: DreamStore
    @Binding var currentStep: OnboardingStep
    @State private var selectedTime: Date = {
        let calendar = Calendar.current
        // Default to 8:00 AM
        return calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var animate = false
    @State private var showTimePicker = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                    .scaleEffect(animate ? 1.2 : 0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animate)
                
                Image(systemName: "bell.badge.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .orange)
                    .symbolColorRenderingMode(.gradient)
                    .symbolEffect(.drawOn.wholeSymbol, options: .nonRepeating, isActive: !animate)
            }
            
            // Text
            VStack(spacing: 12) {
                Text("Daily Reminder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Set a time to record your dreams right after you wake up.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 32)
            }
            
            // Time Picker Display (Tap to open)
            // Disabled if notifications are not yet enabled
            Button(action: {
                if store.hasNotificationAccess {
                    showTimePicker.toggle()
                }
            }) {
                HStack {
                    Text("Reminder Time")
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(selectedTime.formatted(date: .omitted, time: .shortened))
                        .fontWeight(.semibold)
                        .foregroundStyle(store.hasNotificationAccess ? .white : .gray)
                }
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!store.hasNotificationAccess)
            .padding(.horizontal, 24)
            .sheet(isPresented: $showTimePicker) {
                VStack {
                    DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .padding()
                    
                    Button("Done") {
                        showTimePicker = false
                    }
                    .buttonStyle(.glass)
                    .padding()
                }
                .presentationDetents([.height(300)])
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 16) {
                PermissionRow(
                    title: "Notifications",
                    icon: "bell.fill",
                    isGranted: store.hasNotificationAccess,
                    action: {
                        store.reminderTime = selectedTime.timeIntervalSince1970
                        let center = UNUserNotificationCenter.current()
                        
                        Task {
                            // Check existing settings
                            let settings = await center.notificationSettings()
                            let status = settings.authorizationStatus
                            
                            if status == .denied {
                                await MainActor.run {
                                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            } else if status == .notDetermined {
                                do {
                                    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                                    await MainActor.run {
                                        if granted {
                                            store.requestNotificationAccess()
                                        }
                                    }
                                } catch {
                                    print("Error requesting notification authorization: \(error)")
                                }
                            } else {
                                // Already authorized or provisional
                                await MainActor.run {
                                    store.requestNotificationAccess()
                                }
                            }
                        }
                    }
                )
    
                // Continue Button (Moves to All Set)
                Button(action: {
                    store.reminderTime = selectedTime.timeIntervalSince1970
                    if store.hasNotificationAccess {
                        store.scheduleDailyReminder()
                    }
                    withAnimation {
                        currentStep = .allSet
                    }
                }) {
                    Text(store.hasNotificationAccess ? "Continue" : "Skip for Now")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .disabled(!store.hasNotificationAccess)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                animate = true
            }
        }
    }
}

// MARK: - Step 5: All Set (Final)

struct AllSetView: View {
    @ObservedObject var store: DreamStore
    @State private var appear = false
    @State private var iconAppear = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            ZStack {
                // Glow effect
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                    .scaleEffect(iconAppear ? 1.2 : 0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: iconAppear)
                
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .green)
                    .symbolColorRenderingMode(.gradient)
                    .symbolEffect(.drawOn.individually, options: .nonRepeating, isActive: !iconAppear)
            }
            
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Your dream journal is ready. Sleep well!")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button(action: {
                store.completeOnboarding()
            }) {
                Text("Start Dreaming")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            appear = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                iconAppear = true
            }
        }
    }
}

// MARK: - Reusable Components

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.gray))
            .padding()
            .foregroundStyle(.white)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct PermissionRow: View {
    let title: String
    let icon: String
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(
                        isGranted
                        ? Color(red: 0.6, green: 0.85, blue: 0.6)
                        : .white
                    )
            
            Text(title)
                .foregroundStyle(.white)
                .fontWeight(.medium)
            
            Spacer()
            
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(red: 0.6, green: 0.85, blue: 0.6))
            } else {
                Button(action: action) {
                    Text("Enable")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.white)
            }
        }
        .padding()
        .glassEffect(.regular.tint(isGranted ? Color.mint.opacity(0.2) : Color.clear), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct OnboardingProgressView: View {
    let currentStep: OnboardingStep
    
    var body: some View {
        HStack(spacing: 0) {
            // Step 1: Profile
            StepIcon(
                icon: "person.fill",
                isActive: currentStep == .profile,
                isCompleted: currentStep == .permissions || currentStep == .notifications || currentStep == .allSet
            )
            
            Connector(isActive: currentStep == .permissions || currentStep == .notifications || currentStep == .allSet)
            
            // Step 2: Permissions
            StepIcon(
                icon: "mic.fill",
                isActive: currentStep == .permissions,
                isCompleted: currentStep == .notifications || currentStep == .allSet
            )
            
            Connector(isActive: currentStep == .notifications || currentStep == .allSet)
            
            // Step 3: Notifications
            StepIcon(
                icon: "bell.fill",
                isActive: currentStep == .notifications,
                isCompleted: currentStep == .allSet
            )
        }
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
}

struct Connector: View {
    let isActive: Bool
    var body: some View {
        Rectangle()
            .fill(isActive ? Color.white : Color.white.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: 40)
    }
}

struct StepIcon: View {
    let icon: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isActive || isCompleted ? Color.white : Color.white.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: isActive ? .white.opacity(0.5) : .clear, radius: 10)
            
            Image(systemName: isCompleted ? "checkmark" : icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isActive || isCompleted ? .black : .white.opacity(0.5))
                .contentTransition(.symbolEffect(.replace))
        }
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isActive)
    }
}
