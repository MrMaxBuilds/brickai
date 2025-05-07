// MARK: NEW FILE - Views/PaymentsView.swift
// File: BrickAI/Views/PaymentsView.swift
// A new view to display payment information. For now, it's a placeholder.

import SwiftUI

struct PaymentsView: View {
    var body: some View {
        VStack {
            Text("Payments")
                .font(.largeTitle) // Make it prominent
                .fontWeight(.bold)
                .padding(.top, 50) // Add some padding from the top
            Spacer() // Push content to the top
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill the screen
        .background(Color(.systemGroupedBackground).ignoresSafeArea()) // A neutral background
        .navigationTitle("Payments") // Set navigation title for the bar
        .navigationBarTitleDisplayMode(.inline) // Or .large, depending on desired style
    }
}

struct PaymentsView_Previews: PreviewProvider {
    static var previews: some View {
        // Embed in NavigationView for previewing navigation bar elements
        NavigationView {
            PaymentsView()
        }
    }
}
// MARK: END NEW FILE - Views/PaymentsView.swift