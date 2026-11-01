// A one-screen demo. In Xcode: File > New > Project > iOS App (SwiftUI), add this package (File > Add Package Dependencies > Add Local, choose the
// ios folder), replace the generated App file with this one, and add NSCameraUsageDescription to Info.plist. Run on a real device or a simulator.
import SwiftUI
import XtlLiveness

@main
struct DemoApp: App {
    var body: some Scene { WindowGroup { DemoView() } }
}

struct DemoView: View {
    @State private var checkURL = ""
    @State private var token = ""
    @State private var running = false
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste the checkUrl and sdkToken your server got from POST /v1/sessions. In a real app they come from your own server.").font(.footnote)
            TextField("checkUrl (https://.../check/<id>)", text: $checkURL).textFieldStyle(.roundedBorder).autocapitalization(.none).disableAutocorrection(true)
            TextField("sdkToken", text: $token).textFieldStyle(.roundedBorder).autocapitalization(.none).disableAutocorrection(true)
            Button("Start check") { running = true }
            Text(message)
            Spacer()
        }
        .padding()
        .fullScreenCover(isPresented: $running) {
            XtlCheck(checkURL: checkURL.trimmingCharacters(in: .whitespaces), sdkToken: token.trimmingCharacters(in: .whitespaces), allowInsecureHTTP: true) { result in
                running = false
                switch result {
                case .completed(let id): message = "Completed. Now ask YOUR server for the verdict of session \(id)."
                case .cancelled: message = "Cancelled."
                case .error(let code): message = "Error: \(code)"
                }
            }
        }
    }
}
