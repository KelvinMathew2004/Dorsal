import SwiftUI
import UIKit

extension View {
    /// Sets the navigation bar title color specifically for this view.
    /// This avoids global state glitches by applying it to the specific navigation item.
    func navigationBarTitleColor(_ color: Color) -> some View {
        self.background(NavigationItemAppearance(color: UIColor(color)))
    }
}

private struct NavigationItemAppearance: UIViewControllerRepresentable {
    var color: UIColor
    
    func makeUIViewController(context: Context) -> NavigationAppearanceProxy {
        return NavigationAppearanceProxy()
    }
    
    func updateUIViewController(_ uiViewController: NavigationAppearanceProxy, context: Context) {
        uiViewController.targetColor = color
        uiViewController.updateAppearance()
    }
}

// A simplified generic controller to handle the appearance update safely
private class NavigationAppearanceProxy: UIViewController {
    var targetColor: UIColor?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAppearance()
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        updateAppearance()
    }
    
    func updateAppearance() {
        // We need the parent (UIHostingController) because that's what sits on the stack
        guard let parent = self.parent, let color = targetColor else { return }
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground() // Preserves the blur/material
        
        // 1. Set Title Color
        appearance.titleTextAttributes = [.foregroundColor: color]
        
        // 2. Set Large Title Color
        appearance.largeTitleTextAttributes = [.foregroundColor: color]
        
        // 3. Apply to the specific item (not globally)
        // This ensures the OS handles the transition smoothly between screens
        parent.navigationItem.standardAppearance = appearance
        parent.navigationItem.scrollEdgeAppearance = appearance
        parent.navigationItem.compactAppearance = appearance
    }
}
