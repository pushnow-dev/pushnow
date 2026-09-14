import SwiftUI

struct AuthRequiredStateView: View {
    let action: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Sign in to your inbox", systemImage: "person.crop.circle.badge.checkmark")
        } description: {
            Text("Sign in to connect your sources, devices, and notifications to your account.")
        } actions: {
            Button("Sign in with email", action: action)
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    AuthRequiredStateView(action: {})
}
