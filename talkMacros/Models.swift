import SwiftData
import Foundation

@Model
final class DailyLog {
    @Attribute(.unique) var dateString: String
    var date: Date
    @Relationship(deleteRule: .cascade) var meals: [MealEntry] = []
    var totalCalories: Int = 0
    var totalProtein: Int = 0

    init(date: Date) {
        self.date = Calendar.current.startOfDay(for: date)
        self.dateString = DateFormatter.dayFormatter.string(from: date)
    }
}

@Model
final class MealEntry {
    var timestamp: Date
    var mealDescription: String
    var mealName: String
    var estimatedCalories: Int
    var estimatedProtein: Int

    init(
        timestamp: Date = Date(),
        mealDescription: String,
        mealName: String,
        estimatedCalories: Int,
        estimatedProtein: Int
    ) {
        self.timestamp = timestamp
        self.mealDescription = mealDescription
        self.mealName = mealName
        self.estimatedCalories = estimatedCalories
        self.estimatedProtein = estimatedProtein
    }
}

extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let displayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    static let displayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}
