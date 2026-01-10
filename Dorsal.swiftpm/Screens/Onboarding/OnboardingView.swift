import SwiftUI
import AVFoundation
import Speech
import PhotosUI
import UserNotifications

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
    
    // Warp Drive State
    @State private var warpSpeed: Double = 0.05 // Normal cruising speed
    // Starting with a Deep Space Blue/Purple
    @State private var galaxyColor: Color = Color(red: 0.2, green: 0.1, blue: 0.5)
    
    var body: some View {
        ZStack {
            // 1. Warp Drive Background (Metal + Galaxy Gradients)
            WarpDriveView(targetSpeed: warpSpeed, targetColor: galaxyColor)
                .ignoresSafeArea()
            
            // 2. Content
            VStack(spacing: 0) {
                // Progress Tracker (Hidden on Welcome and All Set)
                if currentStep != .welcome && currentStep != .allSet {
                    OnboardingProgressView(currentStep: currentStep)
                        .zIndex(10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Content Switcher with Custom Transition
                Group {
                    switch currentStep {
                    case .welcome:
                        WelcomeIntroView(onNext: {
                            // Warp to Profile: Crimson Red (Distinct from Welcome Purple)
                            triggerWarp(to: .profile, color: Color(red: 0.8, green: 0.0, blue: 0.2))
                        })
                        .transition(.warpContent)
                    case .profile:
                        ProfileSetupView(store: store, onNext: {
                            // Warp to Permissions: Deep Blue
                            triggerWarp(to: .permissions, color: Color(red: 0.0, green: 0.4, blue: 1.0))
                        })
                        .transition(.warpContent)
                    case .permissions:
                        PermissionsView(store: store, onNext: {
                            // Warp to Notifications: Red-Orange
                            triggerWarp(to: .notifications, color: Color(red: 1.0, green: 0.3, blue: 0.0))
                        })
                        .transition(.warpContent)
                    case .notifications:
                        NotificationOnboardingView(store: store, onNext: {
                            // Warp to All Set: Emerald Green
                            triggerWarp(to: .allSet, color: Color(red: 0.0, green: 0.8, blue: 0.3))
                        })
                        .transition(.warpContent)
                    case .allSet:
                        AllSetView(store: store)
                            .transition(.warpContent)
                    }
                }
                .frame(maxWidth: 600, maxHeight: .infinity) // Limits width on iPad, fills width on iPhone
                // Use .id to force transition when step changes
                .id(currentStep)
            }
        }
    }
    
    // MARK: - WARP LOGIC
    private func triggerWarp(to nextStep: OnboardingStep, color: Color) {
        // Continuous flow: Accelerate -> Switch -> Decelerate
        
        // 1. Immediate acceleration
        withAnimation(.easeIn(duration: 0.5)) {
            warpSpeed = 6.0 // High streak speed
        }
        
        // 2. Switch View slightly before peak speed ends to hide the swap
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentStep = nextStep
                galaxyColor = color
            }
        }
        
        // 3. Decelerate immediately after switch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 1.0)) {
                warpSpeed = 0.05 // Return to cruise
            }
        }
    }
}

// MARK: - Custom Transition
extension AnyTransition {
    static var warpContent: AnyTransition {
        // New View: Scales up from small (0.5) to Normal (1.0), Fades In
        // Old View: Scales up from Normal (1.0) to Huge (2.0), Fades Out
        .asymmetric(
            insertion: .scale(scale: 0.5).combined(with: .opacity).animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)),
            removal: .scale(scale: 3.0).combined(with: .opacity).animation(.easeIn(duration: 0.4))
        )
    }
}

// MARK: - Step 1: Welcome Intro (Logo Only)

struct WelcomeIntroView: View {
    var onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo
            if let uiImage = UIImage(named: "logo") {
                LinearGradient(
                    colors: [
                        Color(red: 130/255, green: 100/255, blue: 25/255),  // falloff
                        Color(red: 212/255, green: 175/255, blue: 55/255), // highlight gold
                        Color(red: 150/255, green: 120/255, blue: 30/255), // base gold
                        Color(red: 92/255, green: 72/255, blue: 18/255)    // deep shadow gold
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .mask(
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                )
                .frame(width: 150, height: 150)
            } else {
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
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            OnboardingActionButton(title: "Get Started", action: onNext)
        }
    }
}

// MARK: - Step 2: Profile Setup

struct ProfileSetupView: View {
    @ObservedObject var store: DreamStore
    var onNext: () -> Void
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
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .frame(width: 120, height: 120)
                        .foregroundStyle(.white.opacity(0.5))
                        .glassEffect(.clear, in: Circle())
                }
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack(spacing: 4) {
                        Image(systemName: "camera.fill")
                        Text("Set Photo")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .glassEffect(.clear.interactive())
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
            OnboardingActionButton(
                title: "Continue",
                isDisabled: store.firstName.isEmpty || store.lastName.isEmpty,
                action: onNext
            )
        }
    }
}

// MARK: - Step 3: Permissions

struct PermissionsView: View {
    @ObservedObject var store: DreamStore
    var onNext: () -> Void
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color.blue)
                .symbolColorRenderingMode(.gradient)
                .symbolEffect(.drawOn.individually, options: .repeating, isActive: !animate)
            
            VStack(spacing: 16) {
                Text("Enable Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Access is needed to analyze dreams.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            VStack(spacing: 24) {
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
                    OnboardingActionButton(title: "Continue", action: onNext)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                     Text("Please enable permissions to continue")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .padding(.bottom, 40) // Standardized bottom padding
                }
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
    var onNext: () -> Void
    @State private var selectedTime: Date = {
        let calendar = Calendar.current
        // Default to 8:00 AM
        return calendar.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var animate = false
    @Namespace private var namespace
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: "bell.badge.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, Color(red: 1.0, green: 0.3, blue: 0.0))
                .symbolColorRenderingMode(.gradient)
                .symbolEffect(.drawOn.wholeSymbol, options: .nonRepeating, isActive: !animate)
            
            // Text
            VStack(spacing: 12) {
                Text("Daily Reminder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Set a time to record your dreams right after you wake up.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundStyle(.gray)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
            
            // Bottom Controls Group
            VStack(spacing: 24) {
                GlassEffectContainer {
                    if store.hasNotificationAccess {
                        // Time Picker
                        VStack(spacing: 8) {
                            Text("Reminder Time")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                            
                            DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(maxHeight: 100)
                                .clipped()
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 16)
                        .glassEffect(.clear.tint(Color.orange.opacity(0.1)), in: RoundedRectangle(cornerRadius: 24))
                        .glassEffectID("picker", in: namespace)
                    } else {
                        // Permission Row (wrapped as requested)
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
                        .glassEffectID("permission", in: namespace)
                    }
                }
                .padding(.horizontal, 24)
    
                OnboardingActionButton(
                    title: store.hasNotificationAccess ? "Continue" : "Skip for Now",
                    action: {
                        store.reminderTime = selectedTime.timeIntervalSince1970
                        if store.hasNotificationAccess {
                            store.scheduleDailyReminder()
                        }
                        onNext()
                    }
                )
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                animate = true
            }
        }
        // Ensure smooth transition when swapping layouts
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: store.hasNotificationAccess)
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

            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
                .symbolColorRenderingMode(.gradient)
                .symbolEffect(.drawOn.individually, options: .nonRepeating, isActive: !iconAppear)
            
            VStack(spacing: 16) {
                Text("You're All Set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Text("Your dream journal is ready. Sleep well!")
                    .font(.body)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            OnboardingActionButton(title: "Start Dreaming", action: {
                store.completeOnboarding()
            })
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

struct OnboardingActionButton: View {
    let title: String
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glass)
        .colorScheme(.dark)
        .disabled(isDisabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.gray))
            .padding()
            .foregroundStyle(.white)
            .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 16))
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
                    .font(.system(size: 20, weight: .bold))
                    .padding(3)
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
        .glassEffect(.clear.tint(isGranted ? Color.mint.opacity(0.2) : Color.clear), in: RoundedRectangle(cornerRadius: 16))
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
            .zIndex(1)
            
            Connector(isActive: currentStep == .permissions || currentStep == .notifications || currentStep == .allSet)
                .zIndex(0)
            
            // Step 2: Permissions
            StepIcon(
                icon: "mic.fill",
                isActive: currentStep == .permissions,
                isCompleted: currentStep == .notifications || currentStep == .allSet
            )
            .zIndex(1)
            
            Connector(isActive: currentStep == .notifications || currentStep == .allSet)
                .zIndex(0)
            
            // Step 3: Notifications
            StepIcon(
                icon: "bell.fill",
                isActive: currentStep == .notifications,
                isCompleted: currentStep == .allSet
            )
            .zIndex(1)
        }
        .padding(.top, 60)
        .padding(.bottom, 20)
    }
}

struct Connector: View {
    let isActive: Bool
    var body: some View {
        Rectangle()
            .frame(height: 2)
            .frame(maxWidth: 40)
            .glassEffect(.clear.tint(isActive ? Color.white.opacity(0.5) : Color.clear))
    }
}

struct StepIcon: View {
    let icon: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            Image(systemName: isCompleted ? "checkmark" : icon)
                .font(.system(size: 18, weight: .bold))
                .padding()
                .foregroundStyle(isActive || isCompleted ? .black : .white.opacity(0.5))
                .contentTransition(.symbolEffect(.replace))
        }
        .glassEffect(.clear.tint(isActive || isCompleted ? Color.white.opacity(0.5) : Color.clear), in: Circle())
        .scaleEffect(isActive ? 1.1 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isActive)
    }
}
