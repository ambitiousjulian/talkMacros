import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var allLogs: [DailyLog]
    @ObservedObject private var settings = SettingsManager.shared

    @State private var calorieText = ""
    @State private var proteinText = ""
    @State private var saved = false
    @FocusState private var focused: Field?

    enum Field { case calories, protein }

    private var todayLog: DailyLog? {
        let today = DateFormatter.dayFormatter.string(from: Date())
        return allLogs.first { $0.dateString == today }
    }
    private var todayCals: Int  { todayLog?.totalCalories ?? 0 }
    private var todayProt: Int  { todayLog?.totalProtein  ?? 0 }
    private var calProg: Double {
        guard settings.calorieGoal > 0 else { return 0 }
        return min(Double(todayCals) / Double(settings.calorieGoal), 1.0)
    }
    private var protProg: Double {
        guard settings.proteinGoal > 0 else { return 0 }
        return min(Double(todayProt) / Double(settings.proteinGoal), 1.0)
    }
    private var overallPct: Int { Int(min((calProg + protProg) / 2, 1.0) * 100) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    todayProgressCard
                    goalCard(title: "Calorie Goal", icon: "flame.fill", color: .orange,
                             unit: "cal", text: $calorieText, field: .calories,
                             step: 50, todayValue: todayCals, todayProg: calProg)
                    goalCard(title: "Protein Goal", icon: "bolt.fill", color: .green,
                             unit: "g", text: $proteinText, field: .protein,
                             step: 5, todayValue: todayProt, todayProg: protProg)
                    saveButton
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = nil }
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            .onAppear(perform: loadCurrentValues)
        }
    }

    // MARK: - Today's Progress Card

    private var todayProgressCard: some View {
        VStack(spacing: 14) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S PROGRESS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1.8)
                    Text(DateFormatter.displayDate.string(from: Date()))
                        .font(.headline.bold())
                }
                Spacer()
                // Overall badge
                HStack(spacing: 5) {
                    ZStack {
                        Circle().stroke(
                            (overallPct >= 90 ? Color.green : overallPct >= 50 ? Color.orange : Color(.tertiaryLabel))
                                .opacity(0.2), lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: Double(overallPct) / 100)
                            .stroke(
                                overallPct >= 90 ? Color.green : overallPct >= 50 ? Color.orange : Color(.tertiaryLabel),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 18, height: 18)
                    Text("\(overallPct)% done")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(overallPct >= 90 ? .green : overallPct >= 50 ? .orange : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
            }

            // Two stat blocks
            HStack(spacing: 0) {
                StatBlock(value: todayCals, goal: settings.calorieGoal, color: .orange,
                          icon: "flame.fill", label: "Calories", progress: calProg)
                Rectangle().fill(Color(.separator)).frame(width: 1, height: 70)
                StatBlock(value: todayProt, goal: settings.proteinGoal, color: .green,
                          icon: "bolt.fill", label: "Protein", progress: protProg)
            }
        }
        .padding(18)
        .background {
            ZStack {
                Color(.secondarySystemBackground)
                RadialGradient(colors: [Color.orange.opacity(0.08), .clear],
                               center: UnitPoint(x: 0.1, y: 0.5), startRadius: 5, endRadius: 160)
                RadialGradient(colors: [Color.green.opacity(0.1), .clear],
                               center: UnitPoint(x: 0.9, y: 0.5), startRadius: 5, endRadius: 160)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Goal Card

    @ViewBuilder
    private func goalCard(
        title: String, icon: String, color: Color, unit: String,
        text: Binding<String>, field: Field, step: Int,
        todayValue: Int, todayProg: Double
    ) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                    .foregroundColor(color)
                Spacer()
                // Live progress ring
                ZStack {
                    Circle().stroke(color.opacity(0.12), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: todayProg)
                        .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(0.4), radius: 3)
                        .animation(.spring(response: 0.9), value: todayProg)
                    Text("\(Int(todayProg * 100))%")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(color)
                }
                .frame(width: 34, height: 34)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Today stat strip
            HStack(spacing: 6) {
                Text("today: \(todayValue) \(unit)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(color.opacity(0.85))
                Spacer()
                Text("goal:")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("\(Int(text.wrappedValue) ?? 0) \(unit)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 18)

            MiniBar(progress: todayProg, color: color)
                .padding(.horizontal, 18)
                .padding(.top, 8)

            Divider().padding(.horizontal, 18).padding(.top, 12)

            // Stepper row
            HStack(alignment: .center, spacing: 0) {
                stepButton(icon: "minus", color: color) { adjust(text: text, by: -step) }
                Spacer()
                VStack(spacing: 2) {
                    TextField("0", text: text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($focused, equals: field)
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(minWidth: 120)
                    Text(unit.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(2)
                }
                Spacer()
                stepButton(icon: "plus", color: color) { adjust(text: text, by: step) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture { focused = field }
    }

    @ViewBuilder
    private func stepButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(color)
                .frame(width: 46, height: 46)
                .background(color.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                if saved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.bold())
                        .transition(.scale.combined(with: .opacity))
                }
                Text(saved ? "Changes Saved!" : "Save Goals")
                    .font(.body.bold())
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(
                    colors: saved
                        ? [Color(red: 0.05, green: 0.85, blue: 0.35), Color(red: 0.0, green: 0.7, blue: 0.25)]
                        : [Color.green, Color(red: 0.0, green: 0.75, blue: 0.2)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.green.opacity(0.35), radius: 10, y: 4)
            .animation(.spring(duration: 0.3), value: saved)
        }
    }

    // MARK: - Helpers

    private func adjust(text: Binding<String>, by delta: Int) {
        let next = max(0, (Int(text.wrappedValue) ?? 0) + delta)
        text.wrappedValue = "\(next)"
    }

    private func loadCurrentValues() {
        calorieText = "\(settings.calorieGoal)"
        proteinText = "\(settings.proteinGoal)"
    }

    private func save() {
        focused = nil
        if let cals = Int(calorieText), cals > 0 { settings.calorieGoal = cals }
        if let prot = Int(proteinText), prot > 0 { settings.proteinGoal = prot }
        withAnimation(.spring(duration: 0.3)) { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { saved = false }
        }
    }
}

// MARK: - Stat Block

struct StatBlock: View {
    let value: Int
    let goal: Int
    let color: Color
    let icon: String
    let label: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label.uppercased(), systemImage: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .tracking(0.8)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                Text("/ \(goal)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            MiniBar(progress: progress, color: color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}
