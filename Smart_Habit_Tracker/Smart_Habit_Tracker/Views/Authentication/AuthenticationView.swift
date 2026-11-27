import SwiftUI
import LocalAuthentication
struct AuthenticationView: View {
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @State private var unlocked = false
    @State private var message: String?
    var body: some View {
        Group {
            if !biometricEnabled || unlocked { AppTabView() }
            else {
                VStack(spacing: 22) {
                    Image(systemName: "leaf.circle.fill").font(.system(size: 76)).foregroundStyle(.green)
                    Text("Smart Habit").font(.largeTitle.bold())
                    Text("Build a little consistency every day.").foregroundStyle(.secondary)
                    if let message { Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
                    Button("Unlock with biometrics or passcode") { authenticate() }.buttonStyle(.borderedProminent).tint(.green)
                }.padding().frame(maxWidth: .infinity, maxHeight: .infinity).background(.background).task { authenticate() }
            }
        }
    }
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { message = error?.localizedDescription ?? "Device authentication is unavailable."; return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your habit tracker") { success, authError in
            Task { @MainActor in if success { unlocked = true } else { message = authError?.localizedDescription ?? "Authentication failed." } }
        }
    }
}
