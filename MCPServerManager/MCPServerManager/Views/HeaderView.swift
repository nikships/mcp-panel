import SwiftUI

// MARK: - Claude Icon Shape

private struct ClaudeIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let xOffset = (rect.width - 24 * scale) / 2
        let yOffset = (rect.height - 24 * scale) / 2

        var path = Path()

        // Claude logo path - simplified version
        path.move(to: CGPoint(x: 4.709 * scale + xOffset, y: 15.955 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.429 * scale + xOffset, y: 13.308 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.509 * scale + xOffset, y: 13.078 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.429 * scale + xOffset, y: 12.95 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.2 * scale + xOffset, y: 12.95 * scale + yOffset))
        path.addLine(to: CGPoint(x: 8.41 * scale + xOffset, y: 12.902 * scale + yOffset))
        path.addLine(to: CGPoint(x: 5.712 * scale + xOffset, y: 12.829 * scale + yOffset))
        path.addLine(to: CGPoint(x: 3.373 * scale + xOffset, y: 12.732 * scale + yOffset))
        path.addLine(to: CGPoint(x: 1.107 * scale + xOffset, y: 12.61 * scale + yOffset))
        path.addLine(to: CGPoint(x: 0.536 * scale + xOffset, y: 12.489 * scale + yOffset))
        path.addLine(to: CGPoint(x: 0 * scale + xOffset, y: 11.784 * scale + yOffset))
        path.addLine(to: CGPoint(x: 0.055 * scale + xOffset, y: 11.432 * scale + yOffset))
        path.addLine(to: CGPoint(x: 0.535 * scale + xOffset, y: 11.111 * scale + yOffset))
        path.addLine(to: CGPoint(x: 1.221 * scale + xOffset, y: 11.171 * scale + yOffset))
        path.addLine(to: CGPoint(x: 2.741 * scale + xOffset, y: 11.274 * scale + yOffset))
        path.addLine(to: CGPoint(x: 5.019 * scale + xOffset, y: 11.432 * scale + yOffset))
        path.addLine(to: CGPoint(x: 6.671 * scale + xOffset, y: 11.529 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.12 * scale + xOffset, y: 11.784 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.509 * scale + xOffset, y: 11.784 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.564 * scale + xOffset, y: 11.627 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.43 * scale + xOffset, y: 11.529 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.327 * scale + xOffset, y: 11.432 * scale + yOffset))
        path.addLine(to: CGPoint(x: 6.969 * scale + xOffset, y: 9.836 * scale + yOffset))
        path.addLine(to: CGPoint(x: 4.417 * scale + xOffset, y: 8.148 * scale + yOffset))
        path.addLine(to: CGPoint(x: 3.081 * scale + xOffset, y: 7.176 * scale + yOffset))
        path.addLine(to: CGPoint(x: 2.357 * scale + xOffset, y: 6.685 * scale + yOffset))
        path.addLine(to: CGPoint(x: 1.993 * scale + xOffset, y: 6.223 * scale + yOffset))
        path.addLine(to: CGPoint(x: 1.835 * scale + xOffset, y: 5.215 * scale + yOffset))
        path.addLine(to: CGPoint(x: 2.491 * scale + xOffset, y: 4.493 * scale + yOffset))
        path.addLine(to: CGPoint(x: 3.372 * scale + xOffset, y: 4.553 * scale + yOffset))
        path.addLine(to: CGPoint(x: 3.597 * scale + xOffset, y: 4.614 * scale + yOffset))
        path.addLine(to: CGPoint(x: 4.49 * scale + xOffset, y: 5.3 * scale + yOffset))
        path.addLine(to: CGPoint(x: 6.398 * scale + xOffset, y: 6.776 * scale + yOffset))
        path.addLine(to: CGPoint(x: 8.889 * scale + xOffset, y: 8.609 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.254 * scale + xOffset, y: 8.913 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.399 * scale + xOffset, y: 8.81 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.418 * scale + xOffset, y: 8.737 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.254 * scale + xOffset, y: 8.463 * scale + yOffset))
        path.addLine(to: CGPoint(x: 7.899 * scale + xOffset, y: 6.017 * scale + yOffset))
        path.addLine(to: CGPoint(x: 6.453 * scale + xOffset, y: 3.527 * scale + yOffset))
        path.addLine(to: CGPoint(x: 5.809 * scale + xOffset, y: 2.495 * scale + yOffset))
        path.addLine(to: CGPoint(x: 5.639 * scale + xOffset, y: 1.876 * scale + yOffset))
        path.addLine(to: CGPoint(x: 5.535 * scale + xOffset, y: 1.147 * scale + yOffset))
        path.addLine(to: CGPoint(x: 6.283 * scale + xOffset, y: 0.134 * scale + yOffset))
        path.addLine(to: CGPoint(x: 6.696 * scale + xOffset, y: 0 * scale + yOffset))
        path.addLine(to: CGPoint(x: 7.692 * scale + xOffset, y: 0.134 * scale + yOffset))
        path.addLine(to: CGPoint(x: 8.112 * scale + xOffset, y: 0.498 * scale + yOffset))
        path.addLine(to: CGPoint(x: 8.732 * scale + xOffset, y: 1.912 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.734 * scale + xOffset, y: 4.141 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.289 * scale + xOffset, y: 7.171 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.745 * scale + xOffset, y: 8.069 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.988 * scale + xOffset, y: 8.901 * scale + yOffset))
        path.addLine(to: CGPoint(x: 12.079 * scale + xOffset, y: 9.156 * scale + yOffset))
        path.addLine(to: CGPoint(x: 12.237 * scale + xOffset, y: 9.156 * scale + yOffset))
        path.addLine(to: CGPoint(x: 12.237 * scale + xOffset, y: 9.01 * scale + yOffset))
        path.addLine(to: CGPoint(x: 12.365 * scale + xOffset, y: 7.304 * scale + yOffset))
        path.addLine(to: CGPoint(x: 12.602 * scale + xOffset, y: 5.209 * scale + yOffset))
        path.addLine(to: CGPoint(x: 12.832 * scale + xOffset, y: 2.514 * scale + yOffset))
        path.addLine(to: CGPoint(x: 12.912 * scale + xOffset, y: 1.754 * scale + yOffset))
        path.addLine(to: CGPoint(x: 13.288 * scale + xOffset, y: 0.844 * scale + yOffset))
        path.addLine(to: CGPoint(x: 14.035 * scale + xOffset, y: 0.352 * scale + yOffset))
        path.addLine(to: CGPoint(x: 14.619 * scale + xOffset, y: 0.632 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.099 * scale + xOffset, y: 1.317 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.032 * scale + xOffset, y: 1.761 * scale + yOffset))
        path.addLine(to: CGPoint(x: 14.746 * scale + xOffset, y: 3.612 * scale + yOffset))
        path.addLine(to: CGPoint(x: 14.187 * scale + xOffset, y: 6.515 * scale + yOffset))
        path.addLine(to: CGPoint(x: 13.823 * scale + xOffset, y: 8.457 * scale + yOffset))
        path.addLine(to: CGPoint(x: 14.035 * scale + xOffset, y: 8.457 * scale + yOffset))
        path.addLine(to: CGPoint(x: 14.278 * scale + xOffset, y: 8.215 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.263 * scale + xOffset, y: 6.909 * scale + yOffset))
        path.addLine(to: CGPoint(x: 16.915 * scale + xOffset, y: 4.845 * scale + yOffset))
        path.addLine(to: CGPoint(x: 17.645 * scale + xOffset, y: 4.025 * scale + yOffset))
        path.addLine(to: CGPoint(x: 18.495 * scale + xOffset, y: 3.121 * scale + yOffset))
        path.addLine(to: CGPoint(x: 19.042 * scale + xOffset, y: 2.69 * scale + yOffset))
        path.addLine(to: CGPoint(x: 20.075 * scale + xOffset, y: 2.69 * scale + yOffset))
        path.addLine(to: CGPoint(x: 20.835 * scale + xOffset, y: 3.819 * scale + yOffset))
        path.addLine(to: CGPoint(x: 20.495 * scale + xOffset, y: 4.985 * scale + yOffset))
        path.addLine(to: CGPoint(x: 19.431 * scale + xOffset, y: 6.332 * scale + yOffset))
        path.addLine(to: CGPoint(x: 18.55 * scale + xOffset, y: 7.474 * scale + yOffset))
        path.addLine(to: CGPoint(x: 17.286 * scale + xOffset, y: 9.174 * scale + yOffset))
        path.addLine(to: CGPoint(x: 16.496 * scale + xOffset, y: 10.534 * scale + yOffset))
        path.addLine(to: CGPoint(x: 16.569 * scale + xOffset, y: 10.644 * scale + yOffset))
        path.addLine(to: CGPoint(x: 16.757 * scale + xOffset, y: 10.624 * scale + yOffset))
        path.addLine(to: CGPoint(x: 19.613 * scale + xOffset, y: 10.018 * scale + yOffset))
        path.addLine(to: CGPoint(x: 21.156 * scale + xOffset, y: 9.738 * scale + yOffset))
        path.addLine(to: CGPoint(x: 22.997 * scale + xOffset, y: 9.423 * scale + yOffset))
        path.addLine(to: CGPoint(x: 23.83 * scale + xOffset, y: 9.811 * scale + yOffset))
        path.addLine(to: CGPoint(x: 23.921 * scale + xOffset, y: 10.206 * scale + yOffset))
        path.addLine(to: CGPoint(x: 23.593 * scale + xOffset, y: 11.013 * scale + yOffset))
        path.addLine(to: CGPoint(x: 21.624 * scale + xOffset, y: 11.499 * scale + yOffset))
        path.addLine(to: CGPoint(x: 19.315 * scale + xOffset, y: 11.961 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.876 * scale + xOffset, y: 12.774 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.834 * scale + xOffset, y: 12.804 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.883 * scale + xOffset, y: 12.865 * scale + yOffset))
        path.addLine(to: CGPoint(x: 17.432 * scale + xOffset, y: 13.011 * scale + yOffset))
        path.addLine(to: CGPoint(x: 18.094 * scale + xOffset, y: 13.047 * scale + yOffset))
        path.addLine(to: CGPoint(x: 19.716 * scale + xOffset, y: 13.047 * scale + yOffset))
        path.addLine(to: CGPoint(x: 22.736 * scale + xOffset, y: 13.272 * scale + yOffset))
        path.addLine(to: CGPoint(x: 23.526 * scale + xOffset, y: 13.794 * scale + yOffset))
        path.addLine(to: CGPoint(x: 24 * scale + xOffset, y: 14.432 * scale + yOffset))
        path.addLine(to: CGPoint(x: 23.921 * scale + xOffset, y: 14.917 * scale + yOffset))
        path.addLine(to: CGPoint(x: 22.706 * scale + xOffset, y: 15.537 * scale + yOffset))
        path.addLine(to: CGPoint(x: 21.066 * scale + xOffset, y: 15.148 * scale + yOffset))
        path.addLine(to: CGPoint(x: 17.237 * scale + xOffset, y: 14.238 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.925 * scale + xOffset, y: 13.909 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.743 * scale + xOffset, y: 13.909 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.743 * scale + xOffset, y: 14.019 * scale + yOffset))
        path.addLine(to: CGPoint(x: 16.187 * scale + xOffset, y: 14.668 * scale + yOffset))
        path.addLine(to: CGPoint(x: 18.532 * scale + xOffset, y: 18.189 * scale + yOffset))
        path.addLine(to: CGPoint(x: 18.654 * scale + xOffset, y: 19.269 * scale + yOffset))
        path.addLine(to: CGPoint(x: 18.484 * scale + xOffset, y: 19.622 * scale + yOffset))
        path.addLine(to: CGPoint(x: 17.876 * scale + xOffset, y: 19.835 * scale + yOffset))
        path.addLine(to: CGPoint(x: 17.208 * scale + xOffset, y: 19.713 * scale + yOffset))
        path.addLine(to: CGPoint(x: 15.834 * scale + xOffset, y: 17.788 * scale + yOffset))
        path.addLine(to: CGPoint(x: 14.419 * scale + xOffset, y: 15.621 * scale + yOffset))
        path.addLine(to: CGPoint(x: 13.276 * scale + xOffset, y: 13.678 * scale + yOffset))
        path.addLine(to: CGPoint(x: 13.136 * scale + xOffset, y: 13.758 * scale + yOffset))
        path.addLine(to: CGPoint(x: 12.462 * scale + xOffset, y: 21.012 * scale + yOffset))
        path.addLine(to: CGPoint(x: 12.146 * scale + xOffset, y: 21.382 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.417 * scale + xOffset, y: 21.662 * scale + yOffset))
        path.addLine(to: CGPoint(x: 10.81 * scale + xOffset, y: 21.201 * scale + yOffset))
        path.addLine(to: CGPoint(x: 10.488 * scale + xOffset, y: 20.454 * scale + yOffset))
        path.addLine(to: CGPoint(x: 10.81 * scale + xOffset, y: 18.978 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.199 * scale + xOffset, y: 17.054 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.514 * scale + xOffset, y: 15.524 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.8 * scale + xOffset, y: 13.624 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.97 * scale + xOffset, y: 12.992 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.958 * scale + xOffset, y: 12.95 * scale + yOffset))
        path.addLine(to: CGPoint(x: 11.818 * scale + xOffset, y: 12.968 * scale + yOffset))
        path.addLine(to: CGPoint(x: 10.384 * scale + xOffset, y: 14.935 * scale + yOffset))
        path.addLine(to: CGPoint(x: 8.204 * scale + xOffset, y: 17.88 * scale + yOffset))
        path.addLine(to: CGPoint(x: 6.478 * scale + xOffset, y: 19.725 * scale + yOffset))
        path.addLine(to: CGPoint(x: 6.064 * scale + xOffset, y: 19.889 * scale + yOffset))
        path.addLine(to: CGPoint(x: 5.347 * scale + xOffset, y: 19.519 * scale + yOffset))
        path.addLine(to: CGPoint(x: 5.414 * scale + xOffset, y: 18.857 * scale + yOffset))
        path.addLine(to: CGPoint(x: 5.815 * scale + xOffset, y: 18.268 * scale + yOffset))
        path.addLine(to: CGPoint(x: 8.203 * scale + xOffset, y: 15.232 * scale + yOffset))
        path.addLine(to: CGPoint(x: 9.643 * scale + xOffset, y: 13.35 * scale + yOffset))
        path.addLine(to: CGPoint(x: 10.573 * scale + xOffset, y: 12.264 * scale + yOffset))
        path.addLine(to: CGPoint(x: 10.567 * scale + xOffset, y: 12.106 * scale + yOffset))
        path.addLine(to: CGPoint(x: 10.512 * scale + xOffset, y: 12.106 * scale + yOffset))
        path.addLine(to: CGPoint(x: 4.132 * scale + xOffset, y: 18.56 * scale + yOffset))
        path.addLine(to: CGPoint(x: 3.002 * scale + xOffset, y: 18.706 * scale + yOffset))
        path.addLine(to: CGPoint(x: 2.515 * scale + xOffset, y: 18.25 * scale + yOffset))
        path.addLine(to: CGPoint(x: 2.576 * scale + xOffset, y: 17.504 * scale + yOffset))
        path.addLine(to: CGPoint(x: 2.807 * scale + xOffset, y: 17.261 * scale + yOffset))
        path.addLine(to: CGPoint(x: 4.715 * scale + xOffset, y: 15.949 * scale + yOffset))
        path.closeSubpath()

        return path
    }
}

private struct ClaudeIcon: View {
    var size: CGFloat = 24
    var color: Color = Color(red: 0.85, green: 0.47, blue: 0.34)

    var body: some View {
        ClaudeIconShape()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Gemini Icon Shape

private struct GeminiIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24.0
        let xOffset = (rect.width - 24 * scale) / 2
        let yOffset = (rect.height - 24 * scale) / 2

        var path = Path()

        // Gemini star logo path
        path.move(to: CGPoint(x: 20.616 * scale + xOffset, y: 10.835 * scale + yOffset))

        // Top-right curve going up
        path.addCurve(
            to: CGPoint(x: 16.166 * scale + xOffset, y: 7.834 * scale + yOffset),
            control1: CGPoint(x: 20.616 * scale + xOffset, y: 10.835 * scale + yOffset),
            control2: CGPoint(x: 18.5 * scale + xOffset, y: 9.5 * scale + yOffset)
        )
        path.addCurve(
            to: CGPoint(x: 12.488 * scale + xOffset, y: 1.382 * scale + yOffset),
            control1: CGPoint(x: 14.5 * scale + xOffset, y: 6.0 * scale + yOffset),
            control2: CGPoint(x: 13.0 * scale + xOffset, y: 3.5 * scale + yOffset)
        )

        // Top point
        path.addCurve(
            to: CGPoint(x: 11.513 * scale + xOffset, y: 1.382 * scale + yOffset),
            control1: CGPoint(x: 12.35 * scale + xOffset, y: 0.88 * scale + yOffset),
            control2: CGPoint(x: 11.65 * scale + xOffset, y: 0.88 * scale + yOffset)
        )

        // Top-left curve going down
        path.addCurve(
            to: CGPoint(x: 7.834 * scale + xOffset, y: 7.834 * scale + yOffset),
            control1: CGPoint(x: 11.0 * scale + xOffset, y: 3.5 * scale + yOffset),
            control2: CGPoint(x: 9.5 * scale + xOffset, y: 6.0 * scale + yOffset)
        )
        path.addCurve(
            to: CGPoint(x: 3.384 * scale + xOffset, y: 10.835 * scale + yOffset),
            control1: CGPoint(x: 5.5 * scale + xOffset, y: 9.5 * scale + yOffset),
            control2: CGPoint(x: 3.384 * scale + xOffset, y: 10.835 * scale + yOffset)
        )

        // Left point
        path.addCurve(
            to: CGPoint(x: 1.382 * scale + xOffset, y: 11.513 * scale + yOffset),
            control1: CGPoint(x: 2.734 * scale + xOffset, y: 11.115 * scale + yOffset),
            control2: CGPoint(x: 2.066 * scale + xOffset, y: 11.34 * scale + yOffset)
        )
        path.addCurve(
            to: CGPoint(x: 1.382 * scale + xOffset, y: 12.488 * scale + yOffset),
            control1: CGPoint(x: 0.88 * scale + xOffset, y: 11.65 * scale + yOffset),
            control2: CGPoint(x: 0.88 * scale + xOffset, y: 12.35 * scale + yOffset)
        )

        // Bottom-left curve going down
        path.addCurve(
            to: CGPoint(x: 3.384 * scale + xOffset, y: 13.165 * scale + yOffset),
            control1: CGPoint(x: 2.066 * scale + xOffset, y: 12.66 * scale + yOffset),
            control2: CGPoint(x: 2.734 * scale + xOffset, y: 12.885 * scale + yOffset)
        )
        path.addCurve(
            to: CGPoint(x: 7.834 * scale + xOffset, y: 16.166 * scale + yOffset),
            control1: CGPoint(x: 3.384 * scale + xOffset, y: 13.165 * scale + yOffset),
            control2: CGPoint(x: 5.5 * scale + xOffset, y: 14.5 * scale + yOffset)
        )
        path.addCurve(
            to: CGPoint(x: 11.513 * scale + xOffset, y: 22.619 * scale + yOffset),
            control1: CGPoint(x: 9.5 * scale + xOffset, y: 18.0 * scale + yOffset),
            control2: CGPoint(x: 11.0 * scale + xOffset, y: 20.5 * scale + yOffset)
        )

        // Bottom point
        path.addCurve(
            to: CGPoint(x: 12.488 * scale + xOffset, y: 22.619 * scale + yOffset),
            control1: CGPoint(x: 11.65 * scale + xOffset, y: 23.12 * scale + yOffset),
            control2: CGPoint(x: 12.35 * scale + xOffset, y: 23.12 * scale + yOffset)
        )

        // Bottom-right curve going up
        path.addCurve(
            to: CGPoint(x: 13.165 * scale + xOffset, y: 20.616 * scale + yOffset),
            control1: CGPoint(x: 12.66 * scale + xOffset, y: 21.934 * scale + yOffset),
            control2: CGPoint(x: 12.885 * scale + xOffset, y: 21.266 * scale + yOffset)
        )
        path.addCurve(
            to: CGPoint(x: 16.166 * scale + xOffset, y: 16.166 * scale + yOffset),
            control1: CGPoint(x: 13.8 * scale + xOffset, y: 19.2 * scale + yOffset),
            control2: CGPoint(x: 14.8 * scale + xOffset, y: 17.6 * scale + yOffset)
        )
        path.addCurve(
            to: CGPoint(x: 22.619 * scale + xOffset, y: 12.488 * scale + yOffset),
            control1: CGPoint(x: 18.5 * scale + xOffset, y: 14.5 * scale + yOffset),
            control2: CGPoint(x: 20.5 * scale + xOffset, y: 13.0 * scale + yOffset)
        )

        // Right point
        path.addCurve(
            to: CGPoint(x: 22.619 * scale + xOffset, y: 11.513 * scale + yOffset),
            control1: CGPoint(x: 23.12 * scale + xOffset, y: 12.35 * scale + yOffset),
            control2: CGPoint(x: 23.12 * scale + xOffset, y: 11.65 * scale + yOffset)
        )

        // Back to start
        path.addCurve(
            to: CGPoint(x: 20.616 * scale + xOffset, y: 10.835 * scale + yOffset),
            control1: CGPoint(x: 21.934 * scale + xOffset, y: 11.34 * scale + yOffset),
            control2: CGPoint(x: 21.266 * scale + xOffset, y: 11.115 * scale + yOffset)
        )

        path.closeSubpath()

        return path
    }
}

private struct GeminiIcon: View {
    var size: CGFloat = 24
    var color: Color = Color(red: 0.19, green: 0.53, blue: 1.0) // Gemini blue #3186FF

    var body: some View {
        GeminiIconShape()
            .fill(color)
            .frame(width: size, height: size)
    }
}

// MARK: - Header View

struct HeaderView: View {
    @ObservedObject var viewModel: ServerViewModel
    @Binding var showSettings: Bool
    @Binding var showAddServer: Bool
    @Binding var showQuickActions: Bool
    @Environment(\.themeColors) private var themeColors
    @State private var isSearchFocused = false

    var body: some View {
        HStack(spacing: 0) {
            // Left: Logo + Title (logo has integrated quick actions)
            HStack(spacing: 12) {
                AppLogoView(themeColors: themeColors, showQuickActions: $showQuickActions)

                VStack(alignment: .leading, spacing: 2) {
                    Text("MCP Panel")
                        .font(DesignTokens.Typography.title3)
                        .foregroundColor(themeColors.primaryText)
                        .lineLimit(1)

                    Text(viewModel.servers.count == 1 ? "1 server" : "\(viewModel.servers.count) servers")
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(themeColors.mutedText)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Spacer()

            // Center: Config Switcher (prominent)
            ConfigSwitcherPills(viewModel: viewModel)

            Spacer()

            // Right: Search + Settings
            HStack(spacing: 12) {
                SearchField(text: $viewModel.searchText, isFocused: $isSearchFocused)

                Divider()
                    .frame(height: 24)
                    .opacity(0.3)

                SettingsButton(showSettings: $showSettings, themeColors: themeColors)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .modifier(LiquidGlassModifier(shape: Rectangle(), fillColor: themeColors.sidebarBackground.opacity(0.8)))
    }
}

// MARK: - App Logo (with integrated Quick Actions)

private struct AppLogoView: View {
    let themeColors: ThemeColors
    @Binding var showQuickActions: Bool
    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                showQuickActions.toggle()
            }
        } label: {
            ZStack {
                // App icon (visible when not hovered and quick actions not open)
                Image(nsImage: AppIcon.image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(isHovered || showQuickActions ? 0 : 1)
                    .scaleEffect(isHovered || showQuickActions ? 0.5 : 1)

                // Plus/X icon background + icon (visible when hovered or quick actions open)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColors.accentGradient)
                        .frame(width: 36, height: 36)

                    Image(systemName: showQuickActions ? "xmark" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(themeColors.textOnAccent)
                        .rotationEffect(.degrees(showQuickActions ? 0 : -90))
                }
                .opacity(isHovered || showQuickActions ? 1 : 0)
                .scaleEffect(isHovered || showQuickActions ? 1 : 0.5)
            }
            .shadow(color: themeColors.primaryAccent.opacity(isHovered || showQuickActions ? 0.5 : 0.2), radius: isHovered ? 12 : 6, x: 0, y: 4)
            .scaleEffect(isHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        .help("Quick Actions")
    }
}

// MARK: - Search Field

private struct SearchField: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Environment(\.themeColors) private var themeColors
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isFocused ? themeColors.primaryAccent : themeColors.mutedText)

            TextField("Search...", text: $text)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.body)
                .focused($fieldFocused)
                .onChange(of: fieldFocused) { newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isFocused = newValue
                    }
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(themeColors.mutedText)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Text("⌘F")
                .font(DesignTokens.Typography.captionSmall)
                .foregroundColor(themeColors.mutedText)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(themeColors.glassBackground)
                )
                .opacity(text.isEmpty && !isFocused ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: isFocused ? 260 : 200)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(themeColors.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isFocused ? themeColors.primaryAccent.opacity(0.5) : themeColors.borderColor, lineWidth: 1)
                )
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }
}

// MARK: - Config Switcher Pills

private struct ConfigSwitcherPills: View {
    @ObservedObject var viewModel: ServerViewModel
    @Environment(\.themeColors) private var themeColors
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<2, id: \.self) { index in
                ConfigPill(
                    path: index == 0 ? viewModel.settings.config1Path : viewModel.settings.config2Path,
                    icon: index == 0 ? "terminal" : "sparkles",
                    isClaudeConfig: index == 0,
                    isActive: viewModel.settings.activeConfigIndex == index,
                    namespace: namespace
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        viewModel.switchActiveConfig(to: index)
                    }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(themeColors.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(themeColors.borderColor, lineWidth: 1)
                )
        )
    }
}

private struct ConfigPill: View {
    let path: String
    let icon: String
    let isClaudeConfig: Bool
    let isActive: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                // Use custom icons for Claude and Gemini configs
                if isClaudeConfig {
                    ClaudeIcon(
                        size: 14,
                        color: isActive ? themeColors.textOnAccent : themeColors.secondaryText
                    )
                } else {
                    GeminiIcon(
                        size: 14,
                        color: isActive ? themeColors.textOnAccent : themeColors.secondaryText
                    )
                }

                Text(path.shortPath())
                    .font(DesignTokens.Typography.label)
                    .lineLimit(1)
            }
            .foregroundColor(isActive ? themeColors.textOnAccent : themeColors.secondaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColors.accentGradient)
                        .shadow(color: themeColors.primaryAccent.opacity(0.4), radius: 8, x: 0, y: 2)
                        .matchedGeometryEffect(id: "configPill", in: namespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings Button

private struct SettingsButton: View {
    @Binding var showSettings: Bool
    let themeColors: ThemeColors
    @State private var isHovered = false

    var body: some View {
        Button { showSettings = true } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isHovered ? themeColors.primaryAccent : themeColors.secondaryText)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(themeColors.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isHovered ? themeColors.primaryAccent.opacity(0.4) : themeColors.borderColor, lineWidth: 1)
                        )
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help("Settings")
    }
}
