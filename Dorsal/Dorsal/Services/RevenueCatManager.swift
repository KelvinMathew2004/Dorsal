import Foundation
import Combine
import RevenueCat

@MainActor
final class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()
    static let entitlementID = "dreamer_forever"
    static let offeringID = "lifetime"
    static let publicAPIKey = "appl_KPYrALxAGFnMIXIiqHFewgOQZzD"

    @Published private(set) var isPremium = false
    @Published private(set) var entitlementStatusKnown = false
    @Published private(set) var lifetimePackage: Package?
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var message: String?

    private init() {}

    static func configure() {
        Purchases.configure(withAPIKey: publicAPIKey)
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        message = nil
        defer { isLoading = false }

        async let customerInfoRequest = Purchases.shared.customerInfo()
        async let offeringsRequest = Purchases.shared.offerings()

        do {
            let customerInfo = try await customerInfoRequest
            updateEntitlement(from: customerInfo)
        } catch {
            // Do not lock existing customization when entitlement status cannot be checked.
            entitlementStatusKnown = false
        }

        do {
            let offerings = try await offeringsRequest
            let selectedOffering = offerings.all[Self.offeringID]
                ?? (offerings.current?.identifier == Self.offeringID ? offerings.current : nil)
            lifetimePackage = selectedOffering?.availablePackages.first { $0.packageType == .lifetime }
            if lifetimePackage == nil {
                message = "The lifetime purchase is not available yet. You can keep using the available image styles."
            }
        } catch {
            lifetimePackage = nil
            message = "Purchases are temporarily unavailable. You can keep using the available image styles."
        }
        reconcileCustomizationIfNeeded()
    }

    func canUseImageStyle(_ style: String) -> Bool {
        Self.canUseImageStyle(style, entitlementStatusKnown: entitlementStatusKnown,
                              isPremium: isPremium, hasLifetimePackage: lifetimePackage != nil)
    }

    func canUseTheme(_ themeID: String) -> Bool {
        Self.canUseTheme(themeID, entitlementStatusKnown: entitlementStatusKnown,
                         isPremium: isPremium, hasLifetimePackage: lifetimePackage != nil)
    }

    nonisolated static func isFreeImageStyle(_ style: String) -> Bool {
        style == "pixar"
    }

    nonisolated static func isFreeTheme(_ themeID: String) -> Bool {
        themeID == "gold"
    }

    nonisolated static func canUseImageStyle(_ style: String, entitlementStatusKnown: Bool,
                                             isPremium: Bool, hasLifetimePackage: Bool) -> Bool {
        isFreeImageStyle(style) || !entitlementStatusKnown || isPremium || !hasLifetimePackage
    }

    nonisolated static func canUseTheme(_ themeID: String, entitlementStatusKnown: Bool,
                                        isPremium: Bool, hasLifetimePackage: Bool) -> Bool {
        isFreeTheme(themeID) || !entitlementStatusKnown || isPremium || !hasLifetimePackage
    }

    func purchaseCustomization() async -> Bool {
        guard !isPurchasing, let lifetimePackage else { return false }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: lifetimePackage)
            guard !result.userCancelled else { return false }
            updateEntitlement(from: result.customerInfo)
            reconcileCustomizationIfNeeded()
            return isPremium
        } catch {
            message = "The purchase couldn’t be completed. Please try again."
            return false
        }
    }

    func restorePurchases() async -> Bool {
        guard !isPurchasing else { return false }
        isPurchasing = true
        message = nil
        defer { isPurchasing = false }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            updateEntitlement(from: customerInfo)
            reconcileCustomizationIfNeeded()
            if !isPremium { message = "No active customization purchase was found for this Apple Account." }
            return isPremium
        } catch {
            message = "Purchases couldn’t be restored. Please try again."
            return false
        }
    }

    private func updateEntitlement(from customerInfo: CustomerInfo) {
        isPremium = customerInfo.entitlements.all[Self.entitlementID]?.isActive == true
        entitlementStatusKnown = true
    }

    private func reconcileCustomizationIfNeeded() {
        guard entitlementStatusKnown, !isPremium, lifetimePackage != nil else { return }
        let selectedStyle = UserDefaults.standard.string(forKey: "imageGenerationStyle") ?? "pixar"
        if !Self.isFreeImageStyle(selectedStyle) {
            UserDefaults.standard.set("pixar", forKey: "imageGenerationStyle")
        }
        let selectedTheme = NSUbiquitousKeyValueStore.default.string(forKey: "themeID")
            ?? UserDefaults.standard.string(forKey: "themeID") ?? "gold"
        if !Self.isFreeTheme(selectedTheme) {
            UserDefaults.standard.set("gold", forKey: "themeID")
            NSUbiquitousKeyValueStore.default.set("gold", forKey: "themeID")
        }
    }
}
