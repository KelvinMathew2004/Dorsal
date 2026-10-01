import Combine
import Foundation
import RevenueCat

@MainActor
final class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()
    static let entitlementID = "dreamer_forever"
    #if DEBUG
    private static let apiKey = "test_BDvSLhzJgxcspWTyQOyaJMYTVNT"
    #else
    private static let apiKey = "appl_KPYrALxAGFnMIXIiqHFewgOQZzD"
    #endif

    @Published private(set) var isPremium = false
    @Published private(set) var entitlementStatusKnown = false
    @Published private(set) var isRestoring = false
    @Published private(set) var message: String?

    private var customerInfoUpdatesTask: Task<Void, Never>?

    private init() {}

    static func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .info
        #endif
        Purchases.configure(withAPIKey: apiKey)

        Task { @MainActor in
            shared.startObservingCustomerInfo()
        }
    }

    func refresh() async {
        do {
            updateEntitlement(from: try await Purchases.shared.customerInfo())
        } catch {
            entitlementStatusKnown = false
        }
    }

    func canUseImageStyle(_ style: String) -> Bool {
        Self.canUseImageStyle(style, entitlementStatusKnown: entitlementStatusKnown, isPremium: isPremium)
    }

    func canUseTheme(_ themeID: String) -> Bool {
        Self.canUseTheme(themeID, entitlementStatusKnown: entitlementStatusKnown, isPremium: isPremium)
    }

    nonisolated static func isFreeImageStyle(_ style: String) -> Bool {
        style == "warm"
    }

    nonisolated static func isFreeTheme(_ themeID: String) -> Bool {
        themeID == "gold"
    }

    nonisolated static func canUseImageStyle(
        _ style: String,
        entitlementStatusKnown: Bool,
        isPremium: Bool
    ) -> Bool {
        isFreeImageStyle(style) || (entitlementStatusKnown && isPremium)
    }

    nonisolated static func canUseTheme(
        _ themeID: String,
        entitlementStatusKnown: Bool,
        isPremium: Bool
    ) -> Bool {
        isFreeTheme(themeID) || (entitlementStatusKnown && isPremium)
    }

    func restorePurchases() async -> Bool {
        guard !isRestoring else { return false }
        isRestoring = true
        message = nil
        defer { isRestoring = false }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateEntitlement(from: customerInfo)
            if !isPremium {
                message = "No active customization purchase was found for this Apple Account."
            }
            return isPremium
        } catch {
            message = "Purchases couldn’t be restored. Please try again."
            return false
        }
    }

    func updateEntitlement(from customerInfo: CustomerInfo) {
        isPremium = customerInfo.entitlements.all[Self.entitlementID]?.isActive == true
        entitlementStatusKnown = true
        reconcileCustomizationIfNeeded()
    }

    private func startObservingCustomerInfo() {
        guard customerInfoUpdatesTask == nil else { return }
        customerInfoUpdatesTask = Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                guard let self, !Task.isCancelled else { return }
                self.updateEntitlement(from: customerInfo)
            }
        }
    }

    private func reconcileCustomizationIfNeeded() {
        guard entitlementStatusKnown, !isPremium else { return }

        let selectedStyle = UserDefaults.standard.string(forKey: "imageGenerationStyle") ?? "warm"
        if !Self.isFreeImageStyle(selectedStyle) {
            UserDefaults.standard.set("warm", forKey: "imageGenerationStyle")
            NSUbiquitousKeyValueStore.default.set("warm", forKey: "imageGenerationStyle")
        }

        let selectedTheme = NSUbiquitousKeyValueStore.default.string(forKey: "themeID")
            ?? UserDefaults.standard.string(forKey: "themeID") ?? "gold"
        if !Self.isFreeTheme(selectedTheme) {
            UserDefaults.standard.set("gold", forKey: "themeID")
            NSUbiquitousKeyValueStore.default.set("gold", forKey: "themeID")
        }
    }
}
