import SwiftUI

struct SuccessView: View {
    @Environment(\.colorScheme) private var scheme
    let receipt: Receipt
    let copy: DemoCopy
    let restart: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image("Mark")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(alignment: .bottomTrailing) { badge }
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text(title).font(.title.weight(.semibold)).multilineTextAlignment(.center)
                    Text(copy.reply).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                summary
                Button(copy.newInquiry, action: restart)
                    .buttonStyle(BrandButtonStyle(color: Brand.primary(scheme)))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 48)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Brand.background(scheme))
    }

    private var title: String {
        let first = receipt.name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? copy.thanksAnonymous : copy.thanks.replacingOccurrences(of: "{name}", with: first)
    }

    private var badge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color.green))
            .overlay(Circle().strokeBorder(Brand.background(scheme), lineWidth: 3))
            .offset(x: 8, y: 8)
    }

    private var summary: some View {
        VStack(spacing: 0) {
            row(copy.project, receipt.project)
            Divider()
            row(copy.replyTo, receipt.email)
        }
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary.opacity(0.5)))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value).fontWeight(.medium).multilineTextAlignment(.trailing)
        }
        .font(.body)
        .padding(.vertical, 14)
    }
}

private struct BrandButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .contentShape(Rectangle())
    }
}
