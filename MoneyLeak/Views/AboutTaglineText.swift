import SwiftUI

struct AboutTaglineText: View {
    @State private var tagline = AppAboutInfo.randomTagline()

    var body: some View {
        Text(tagline)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                tagline = AppAboutInfo.randomTagline()
            }
    }
}
