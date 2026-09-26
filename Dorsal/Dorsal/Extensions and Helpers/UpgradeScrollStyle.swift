import SwiftUI

extension View {
    @ViewBuilder
    func upgradeScrollEdgeEffect() -> some View {
        if #available(iOS 27, *) {
            scrollEdgeEffectStyle(.soft, for: .vertical)
        } else {
            self
        }
    }
}
