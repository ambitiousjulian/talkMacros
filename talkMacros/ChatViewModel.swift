import Foundation
import SwiftData

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var todayCalories: Int = 0
    @Published var todayProtein: Int = 0

    // Day-boundary prompt (midnight – 3 AM)
    @Published var showDayPrompt = false
    @Published var yesterdayInfo: DayInfo? = nil

    struct DayInfo {
        let date: Date
        let calories: Int
        let protein: Int
    }

    private var modelContext: ModelContext?
    private var activeLog: DailyLog?          // whichever day the user chose
    private var yesterdayLog: DailyLog? = nil
    private var pendingMessage: String? = nil
    private var dayBoundaryHandled = false

    // MARK: - Setup

    func setup(context: ModelContext) {
        guard modelContext == nil else { return }
        self.modelContext = context
        loadOrCreateTodayLog()
        loadYesterdayLogIfNeeded()
        if messages.isEmpty {
            messages.append(ChatMessage(
                content: "Hey! Tell me what you've eaten and I'll track your calories and protein. You can also ask for food suggestions anytime.",
                isUser: false
            ))
        }
    }

    private func loadOrCreateTodayLog() {
        guard let context = modelContext else { return }
        let today = DateFormatter.dayFormatter.string(from: Date())
        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.dateString == today })
        if let existing = try? context.fetch(descriptor).first {
            activeLog = existing
        } else {
            let log = DailyLog(date: Date())
            context.insert(log)
            try? context.save()
            activeLog = log
        }
        syncTotals()
    }

    private func loadYesterdayLogIfNeeded() {
        guard let context = modelContext else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour < 3 else { return }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let yStr = DateFormatter.dayFormatter.string(from: yesterday)
        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.dateString == yStr })
        if let yLog = try? context.fetch(descriptor).first, !yLog.meals.isEmpty {
            yesterdayLog = yLog
            yesterdayInfo = DayInfo(date: yLog.date, calories: yLog.totalCalories, protein: yLog.totalProtein)
        }
    }

    private func syncTotals() {
        todayCalories = activeLog?.totalCalories ?? 0
        todayProtein  = activeLog?.totalProtein  ?? 0
    }

    // MARK: - Send

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Show day-boundary prompt once if applicable
        if !dayBoundaryHandled, yesterdayLog != nil {
            pendingMessage = trimmed
            showDayPrompt = true
            return
        }

        executeSend(trimmed)
    }

    /// Called from the day-picker sheet
    func confirmDay(useToday: Bool) {
        dayBoundaryHandled = true
        showDayPrompt = false

        if !useToday, let yLog = yesterdayLog {
            activeLog = yLog
            syncTotals()
        }

        if let msg = pendingMessage {
            pendingMessage = nil
            executeSend(msg)
        }
    }

    private func executeSend(_ trimmed: String) {
        messages.append(ChatMessage(content: trimmed, isUser: true))
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let settings = SettingsManager.shared
                let history = Array(messages.dropLast().suffix(10))

                let response = try await ClaudeService.shared.sendMessage(
                    userMessage: trimmed,
                    conversationHistory: history,
                    dailyCalories: todayCalories,
                    dailyProtein: todayProtein,
                    calorieGoal: settings.calorieGoal,
                    proteinGoal: settings.proteinGoal
                )

                var assistantMsg = ChatMessage(content: response.reply, isUser: false)

                if let cal = response.calories, let prot = response.protein {
                    let newDailyCal  = response.dailyTotalCalories ?? (todayCalories + cal)
                    let newDailyProt = response.dailyTotalProtein  ?? (todayProtein  + prot)
                    assistantMsg.mealCard = MealCard(
                        name: response.mealName ?? "Meal",
                        calories: cal,
                        protein: prot,
                        dailyCalories: newDailyCal,
                        dailyProtein: newDailyProt
                    )
                    messages.append(assistantMsg)
                    persistMeal(
                        description: trimmed,
                        name: response.mealName ?? trimmed,
                        calories: cal,
                        protein: prot,
                        newDailyCalories: response.dailyTotalCalories,
                        newDailyProtein: response.dailyTotalProtein
                    )
                } else {
                    messages.append(assistantMsg)
                }
            } catch {
                errorMessage = error.localizedDescription
                messages.append(ChatMessage(
                    content: "Something went wrong: \(error.localizedDescription)",
                    isUser: false
                ))
            }
            isLoading = false
        }
    }

    private func persistMeal(
        description: String,
        name: String,
        calories: Int,
        protein: Int,
        newDailyCalories: Int?,
        newDailyProtein: Int?
    ) {
        guard let context = modelContext, let log = activeLog else { return }
        let entry = MealEntry(
            mealDescription: description,
            mealName: name,
            estimatedCalories: calories,
            estimatedProtein: protein
        )
        context.insert(entry)
        log.meals.append(entry)
        log.totalCalories = newDailyCalories ?? (log.totalCalories + calories)
        log.totalProtein  = newDailyProtein  ?? (log.totalProtein  + protein)
        try? context.save()
        syncTotals()
    }

    func dismissError() { errorMessage = nil }
}
