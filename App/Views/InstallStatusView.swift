import SwiftUI

struct InstallStatusView: View {
    @ObservedObject var signing: SigningService
    @ObservedObject var installController: InstallController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                // Prefer signing.phase unless it's .idle — show installController.installStatus otherwise
                switch signing.phase {
                case .idle:
                    if !installController.installStatus.isEmpty {
                        Text(installController.installStatus).font(.headline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Idle").font(.headline)
                            .foregroundColor(.secondary)
                    }
                case .downloading:
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.4)
                            .padding(.bottom, 8)
                        Text("Downloading...")
                            .font(.body)
                    }
                case .signing:
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.6)
                            .padding(.bottom, 8)
                        Text("Signing in progress...")
                            .font(.body)
                    }
                case .done(let msg):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Done")
                        .font(.title2)
                    Text(msg).font(.caption).multilineTextAlignment(.center)
                        .padding(.top, 6)
                case .failed(let msg):
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.red)
                    Text("Failed")
                        .font(.title2)
                    Text(msg).font(.caption).multilineTextAlignment(.center)
                        .padding(.top, 6)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Install Status")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
