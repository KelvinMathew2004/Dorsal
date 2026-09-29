import RevenueCat
import RevenueCatUI
import SwiftUI

struct CustomizationPaywallView: View {
    @ObservedObject var manager: RevenueCatManager
    let onUnlock: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var offering: Offering?
    @State private var loadError: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let offering {
                PaywallView(offering: offering, displayCloseButton: true)
                    .onPurchaseCompleted { customerInfo in
                        manager.updateEntitlement(from: customerInfo)
                        if manager.isPremium { onUnlock() }
                    }
                    .onRestoreCompleted { customerInfo in
                        manager.updateEntitlement(from: customerInfo)
                        if manager.isPremium { onUnlock() }
                    }
            } else if isLoading {
                ProgressView("Loading subscription options…")
                    .tint(.white)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.ignoresSafeArea())
            } else {
                ContentUnavailableView {
                    Label("Paywall Unavailable", systemImage: "creditcard.trianglebadge.exclamationmark")
                } description: {
                    Text(loadError ?? "The subscription paywall could not be loaded. Please try again.")
                } actions: {
                    Button("Try Again") {
                        Task { await loadOffering() }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Close", role: .cancel) { dismiss() }
                        .buttonStyle(.bordered)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.ignoresSafeArea())
            }
        }
        .task { await loadOffering() }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func loadOffering() async {
        isLoading = true
        loadError = nil
        offering = nil
        defer { isLoading = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else {
                loadError = "RevenueCat did not return a current subscription offering. Check the current offering for this app in RevenueCat."
                return
            }
            guard current.hasPaywall else {
                loadError = "The current offering has no published custom paywall for this app configuration. Check that the paywall is attached to the current offering and available to this SDK key."
                return
            }
            offering = current
        } catch {
            loadError = "Could not fetch subscription options. Check your connection and try again."
        }
    }
}
