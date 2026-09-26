import SwiftUI
import RevenueCat

struct CustomizationPaywallView: View {
    @ObservedObject var manager: RevenueCatManager
    let onUnlock: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.gradientBackground().ignoresSafeArea()
                VStack(spacing: 22) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(Theme.accent)
                    Text("Make each dream image your own")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text("Unlock every illustration style and color theme. Animation and the Gold theme stay free, along with your journal and recording features.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    if manager.isLoading {
                        ProgressView().tint(.white)
                    } else if let package = manager.lifetimePackage {
                        Button {
                            Task {
                                if await manager.purchaseCustomization() { onUnlock() }
                            }
                        } label: {
                            HStack {
                                if manager.isPurchasing { ProgressView().tint(.white) }
                                Text("Unlock all customizations · \(package.storeProduct.localizedPriceString)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.accent, in: Capsule())
                            .foregroundStyle(.black)
                        }
                        .disabled(manager.isPurchasing)
                        Text("One-time purchase. No recurring charge.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(manager.message ?? "Purchases are not available right now. You can continue using Dorsal.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }

                    Button("Restore Purchases") {
                        Task {
                            if await manager.restorePurchases() { onUnlock() }
                        }
                    }
                    .disabled(manager.isPurchasing)

                    if let message = manager.message, manager.lifetimePackage != nil {
                        Text(message)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(28)
                .frame(maxWidth: 480)
            }
            .navigationTitle("Image Customization")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { await manager.refresh() }
        }
        .preferredColorScheme(.dark)
    }
}
