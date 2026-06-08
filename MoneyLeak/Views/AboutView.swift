import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            Text("Money Leak Monitor")
                .font(.title2)
                .fontWeight(.semibold)

            AboutTaglineText()

            Text("Version \(AppAboutInfo.versionString)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text("Created by \(AppAboutInfo.creatorName)")
                .font(.subheadline)

            Link(AppAboutInfo.socialHandle, destination: AppAboutInfo.socialURL)
                .font(.subheadline)

            Button("OK") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .padding(28)
        .frame(width: 320)
    }
}
