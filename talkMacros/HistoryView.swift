import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]

    private var todayLog: DailyLog? {
        let today = DateFormatter.dayFormatter.string(from: Date())
        return logs.first { $0.dateString == today }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let log = todayLog {
                    DayDetailView(log: log)
                } else {
                    emptyToday
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: HistoryListView()) {
                        Label("History", systemImage: "calendar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    private var emptyToday: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color(.secondarySystemBackground)).frame(width: 80, height: 80)
                Image(systemName: "fork.knife").font(.system(size: 32, weight: .semibold)).foregroundColor(.secondary)
            }
            VStack(spacing: 6) {
                Text("Nothing logged yet").font(.headline)
                Text("Head to the chat tab to log your first meal").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

// MARK: - History List

struct HistoryListView: View {
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            ForEach(logs) { log in
                NavigationLink(destination: DayDetailView(log: log)) {
                    DayCard(log: log)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                .listRowSeparator(.hidden)
            }
            .onDelete { offsets in
                for i in offsets { modelContext.delete(logs[i]) }
                try? modelContext.save()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .overlay {
            if logs.isEmpty {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Color(.secondarySystemBackground)).frame(width: 80, height: 80)
                        Image(systemName: "calendar").font(.system(size: 32, weight: .semibold)).foregroundColor(.secondary)
                    }
                    VStack(spacing: 6) {
                        Text("No History Yet").font(.headline)
                        Text("Your daily meal logs will appear here").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("History")
        .toolbar { EditButton().tint(.green) }
    }
}

// MARK: - Day Card

struct DayCard: View {
    let log: DailyLog
    @ObservedObject private var settings = SettingsManager.shared

    private var calProg: Double {
        guard settings.calorieGoal > 0 else { return 0 }
        return min(Double(log.totalCalories) / Double(settings.calorieGoal), 1.0)
    }
    private var protProg: Double {
        guard settings.proteinGoal > 0 else { return 0 }
        return min(Double(log.totalProtein) / Double(settings.proteinGoal), 1.0)
    }
    private var completionColor: Color {
        let avg = (calProg + protProg) / 2
        if avg >= 0.85 { return .green }
        if avg >= 0.4  { return .orange }
        return Color(.tertiaryLabel)
    }
    private var completionPct: Int { Int(min((calProg + protProg) / 2, 1.0) * 100) }

    private var dayNumber: String { "\(Calendar.current.component(.day, from: log.date))" }
    private var monthStr: String {
        let f = DateFormatter(); f.dateFormat = "MMM"; return f.string(from: log.date).uppercased()
    }
    private var relativeLabel: String {
        let c = Calendar.current
        if c.isDateInToday(log.date)     { return "Today" }
        if c.isDateInYesterday(log.date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: log.date)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Completion stripe
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [completionColor, completionColor.opacity(0.5)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
                .padding(.vertical, 10)
                .shadow(color: completionColor.opacity(0.6), radius: 4)

            HStack(spacing: 12) {
                // Date badge
                VStack(spacing: 1) {
                    Text(dayNumber)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Text(monthStr)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(1)
                }
                .frame(width: 36)

                Rectangle().fill(Color(.separator)).frame(width: 1, height: 48)

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center) {
                        Text(relativeLabel)
                            .font(.headline)
                        Spacer()
                        // Completion badge
                        Text("\(completionPct)%")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(completionColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(completionColor.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    // Macro mini bars
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.orange)
                                .frame(width: 10)
                            MiniBar(progress: calProg, color: .orange)
                            Text("\(log.totalCalories)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                                .frame(width: 38, alignment: .trailing)
                                .monospacedDigit()
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green)
                                .frame(width: 10)
                            MiniBar(progress: protProg, color: .green)
                            Text("\(log.totalProtein)g")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                                .frame(width: 38, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }

                    // Meal count pill
                    HStack(spacing: 4) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(log.meals.count) meal\(log.meals.count == 1 ? "" : "s")")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(.separator).opacity(0.25), lineWidth: 0.5)
        )
    }
}

// MARK: - Day Detail

struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var settings = SettingsManager.shared
    let log: DailyLog

    var sortedMeals: [MealEntry] { log.meals.sorted { $0.timestamp < $1.timestamp } }

    private var calProg: Double {
        guard settings.calorieGoal > 0 else { return 0 }
        return min(Double(log.totalCalories) / Double(settings.calorieGoal), 1.0)
    }
    private var protProg: Double {
        guard settings.proteinGoal > 0 else { return 0 }
        return min(Double(log.totalProtein) / Double(settings.proteinGoal), 1.0)
    }

    var body: some View {
        List {
            // Summary ring card
            Section {
                VStack(spacing: 14) {
                    HStack(spacing: 0) {
                        SummaryRingBlock(value: log.totalCalories, goal: settings.calorieGoal,
                                         color: .orange, icon: "flame.fill", label: "Calories")
                        Rectangle().fill(Color(.separator)).frame(width: 1, height: 80)
                        SummaryRingBlock(value: log.totalProtein, goal: settings.proteinGoal,
                                         color: .green, icon: "bolt.fill", label: "Protein")
                    }

                    // Combined progress bar
                    VStack(spacing: 6) {
                        HStack {
                            Text("Calories")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            Spacer()
                            Text("\(Int(calProg * 100))% of \(settings.calorieGoal) cal")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        MiniBar(progress: calProg, color: .orange)

                        HStack {
                            Text("Protein")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                            Spacer()
                            Text("\(Int(protProg * 100))% of \(settings.proteinGoal)g")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.green)
                        }
                        MiniBar(progress: protProg, color: .green)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.vertical, 8)
                .listRowBackground(Color(.secondarySystemBackground))
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            } header: {
                Text("SUMMARY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
            }

            // Meals
            Section {
                if sortedMeals.isEmpty {
                    Text("No meals logged")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(sortedMeals) { meal in HistoryMealRow(meal: meal) }
                    .onDelete { offsets in
                        let toDelete = offsets.map { sortedMeals[$0] }
                        for meal in toDelete {
                            log.meals.removeAll { $0.id == meal.id }
                            modelContext.delete(meal)
                        }
                        log.totalCalories = log.meals.reduce(0) { $0 + $1.estimatedCalories }
                        log.totalProtein  = log.meals.reduce(0) { $0 + $1.estimatedProtein }
                        try? modelContext.save()
                    }
                }
            } header: {
                Text("MEALS (\(log.meals.count))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
            }
        }
        .navigationTitle(DateFormatter.displayDate.string(from: log.date))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton().tint(.green) }
    }
}

// MARK: - Summary Ring Block

struct SummaryRingBlock: View {
    let value: Int
    let goal: Int
    let color: Color
    let icon: String
    let label: String

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1.0)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(color.opacity(0.1), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.5), radius: 4)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7), value: progress)
                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(color)
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(color)
                }
            }
            .frame(width: 54, height: 54)

            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(1.2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - History Meal Row

struct HistoryMealRow: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            VStack(spacing: 2) {
                Text(DateFormatter.displayTime.string(from: meal.timestamp))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                Circle().fill(Color(.separator)).frame(width: 4, height: 4)
            }
            .frame(width: 48)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                Text(meal.mealName)
                    .font(.headline)
                    .lineLimit(1)
                if meal.mealDescription != meal.mealName {
                    Text(meal.mealDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 10) {
                    Label("\(meal.estimatedCalories) cal", systemImage: "flame.fill")
                        .foregroundColor(.orange)
                    Label("\(meal.estimatedProtein)g protein", systemImage: "bolt.fill")
                        .foregroundColor(.green)
                }
                .font(.caption.bold())
            }
        }
        .padding(.vertical, 3)
    }
}

// Keep old MealRow name as alias for any remaining references
typealias MealRow = HistoryMealRow
