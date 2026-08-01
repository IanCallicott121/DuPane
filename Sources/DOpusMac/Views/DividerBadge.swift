import SwiftUI
import AppKit

struct DividerBadge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
            Circle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(Circle().strokeBorder(Color.orange, lineWidth: 1.5))
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                )
        }
        .frame(width: 24)
    }
}
