import Foundation
import Combine

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var calorieGoal: Int {
        didSet { UserDefaults.standard.set(calorieGoal, forKey: "calorieGoal") }
    }

    @Published var proteinGoal: Int {
        didSet { UserDefaults.standard.set(proteinGoal, forKey: "proteinGoal") }
    }

    private init() {
        let savedCals = UserDefaults.standard.integer(forKey: "calorieGoal")
        self.calorieGoal = savedCals > 0 ? savedCals : 2200

        let savedProt = UserDefaults.standard.integer(forKey: "proteinGoal")
        self.proteinGoal = savedProt > 0 ? savedProt : 175
    }
}
