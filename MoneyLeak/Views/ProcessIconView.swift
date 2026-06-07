import AppKit
import SwiftUI

struct ProcessIconView: View {
    let icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                Image(systemName: "app")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }
}
