import SwiftUI

struct DayPickerSheet: View {
    let yesterdayInfo: ChatViewModel.DayInfo
    let onPick: (Bool) -> Void

    private var timeString: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: Date())
    }
    private var yesterdayLabel: String { DateFormatter.displayDate.string(from: yesterdayInfo.date) }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 56, height: 56)
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                }
                .padding(.bottom, 4)

                Text("It's \(timeString)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("Which day is this for?")
                    .font(.title2.bold())
            }
            .padding(.top, 30)
            .padding(.bottom, 24)

            // Options
            VStack(spacing: 12) {
                dayOption(
                    icon: "clock.arrow.circlepath",
                    iconColor: .blue,
                    title: yesterdayLabel,
                    subtitle: "\(yesterdayInfo.calories) cal  ·  \(yesterdayInfo.protein)g protein already logged",
                    badge: "Continue",
                    badgeColor: .blue,
                    useToday: false
                )
                dayOption(
                    icon: "sunrise.fill",
                    iconColor: .green,
                    title: "New Day",
                    subtitle: "Start a fresh log for today",
                    badge: "Fresh start",
                    badgeColor: .green,
                    useToday: true
                )
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .background {
            ZStack {
                Color(.systemBackground)
                RadialGradient(colors: [Color.orange.opacity(0.06), .clear],
                               center: UnitPoint(x: 0.5, y: 0), startRadius: 5, endRadius: 250)
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func dayOption(
        icon: String, iconColor: Color,
        title: String, subtitle: String,
        badge: String, badgeColor: Color,
        useToday: Bool
    ) -> some View {
        Button { onPick(useToday) } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                .shadow(color: iconColor.opacity(0.25), radius: 6, y: 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(badgeColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(badgeColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(iconColor.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(iconColor.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
