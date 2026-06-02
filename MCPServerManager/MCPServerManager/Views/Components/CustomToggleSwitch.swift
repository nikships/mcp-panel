import SwiftUI

struct CustomToggleSwitch: View {
    @Binding var isOn: Bool
    var label: String = ""

    var body: some View {
        Button(action: { withAnimation(.spring(response: 0.3)) { isOn.toggle() } }, label: {
            HStack(spacing: 12) {
                if !label.isEmpty {
                    Text(label)
                        .font(DesignTokens.Typography.label)
                        .foregroundColor(.primary)
                }

                ZStack {
                    // Background track
                    Capsule()
                        .fill(isOn ? AnyShapeStyle(toggleGradient) : AnyShapeStyle(Color.gray.opacity(0.3)))
                        .frame(width: 44, height: 24)

                    // Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: isOn ? 10 : -10)
                }
            }
        })
        .buttonStyle(.plain)
    }

    private var toggleGradient: LinearGradient {
        LinearGradient(
            colors: [.green, .cyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

struct CheckboxToggle: View {
    @Binding var isOn: Bool
    var label: String

    var body: some View {
        Button(action: { isOn.toggle() }, label: {
            HStack(spacing: 8) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(isOn ? .blue : .gray)
                    .font(DesignTokens.Typography.title3)

                Text(label)
                    .font(DesignTokens.Typography.label)
                    .foregroundColor(.primary)
            }
        })
        .buttonStyle(.plain)
    }
}
