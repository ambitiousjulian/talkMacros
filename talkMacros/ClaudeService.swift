import Foundation

// Replace with your key, or set it in the Settings screen.
let ANTHROPIC_API_KEY = "YOUR_API_KEY_HERE"

struct MealCard: Equatable {
    let name: String
    let calories: Int
    let protein: Int
    let dailyCalories: Int
    let dailyProtein: Int
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var mealCard: MealCard? = nil

    init(content: String, isUser: Bool, timestamp: Date = Date()) {
        self.content = content
        self.isUser = isUser
        self.timestamp = timestamp
    }
}

struct ClaudeAPIResponse {
    let reply: String
    let mealName: String?
    let calories: Int?
    let protein: Int?
    let dailyTotalCalories: Int?
    let dailyTotalProtein: Int?
    let remainingCalories: Int?
    let remainingProtein: Int?
}

enum ClaudeError: LocalizedError {
    case noApiKey
    case networkError
    case apiError(Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noApiKey:         return "No API key set. Add it in Settings."
        case .networkError:     return "Network error. Check your connection."
        case .apiError(let c):  return "API error (HTTP \(c)). Check your API key in Settings."
        case .parseError:       return "Couldn't parse Claude's response."
        }
    }
}

final class ClaudeService {
    static let shared = ClaudeService()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-5"

    private init() {}

    func sendMessage(
        userMessage: String,
        conversationHistory: [ChatMessage],
        dailyCalories: Int,
        dailyProtein: Int,
        calorieGoal: Int,
        proteinGoal: Int
    ) async throws -> ClaudeAPIResponse {
        let key = ANTHROPIC_API_KEY

        guard key != "YOUR_API_KEY_HERE", !key.isEmpty else {
            throw ClaudeError.noApiKey
        }

        let remaining = (calorieGoal - dailyCalories, proteinGoal - dailyProtein)

        let systemPrompt = """
        You are a friendly nutrition tracking assistant. Help users log meals and track macros through natural conversation.

        Current daily totals: \(dailyCalories) cal | \(dailyProtein)g protein
        Daily goals: \(calorieGoal) cal | \(proteinGoal)g protein
        Remaining: \(remaining.0) cal | \(remaining.1)g protein

        RULES:
        - When the user describes eating something, ALWAYS respond with this exact JSON:
          {
            "reply": "short casual response (1-2 sentences)",
            "meal_name": "short meal name",
            "calories": <integer>,
            "protein": <integer>,
            "daily_total_calories": <new running total>,
            "daily_total_protein": <new running total>,
            "remaining_calories": <goal minus new total>,
            "remaining_protein": <goal minus new total>
          }
        - When just chatting, answering questions, or giving suggestions (NOT logging food), respond with ONLY:
          {"reply": "your response here"}
        - Estimates are fine — be reasonable but don't overthink nutrition numbers.
        - Keep replies short and casual. Be encouraging.
        - Always return valid JSON only. No text outside the JSON object.
        """

        let messages: [[String: String]] = conversationHistory.map {
            ["role": $0.isUser ? "user" : "assistant", "content": $0.content]
        } + [["role": "user", "content": userMessage]]

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "system": systemPrompt,
            "messages": messages
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeError.networkError
        }

        guard let http = response as? HTTPURLResponse else { throw ClaudeError.networkError }
        guard http.statusCode == 200 else { throw ClaudeError.apiError(http.statusCode) }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]],
            let text = content.first?["text"] as? String
        else { throw ClaudeError.parseError }

        return try parseResponse(text)
    }

    private func parseResponse(_ text: String) throws -> ClaudeAPIResponse {
        // Tolerate any surrounding whitespace or text
        let jsonText: String
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            jsonText = String(text[start...end])
        } else {
            jsonText = text
        }

        guard
            let data = jsonText.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw ClaudeError.parseError }

        return ClaudeAPIResponse(
            reply:               json["reply"] as? String ?? "Got it!",
            mealName:            json["meal_name"] as? String,
            calories:            json["calories"] as? Int,
            protein:             json["protein"] as? Int,
            dailyTotalCalories:  json["daily_total_calories"] as? Int,
            dailyTotalProtein:   json["daily_total_protein"] as? Int,
            remainingCalories:   json["remaining_calories"] as? Int,
            remainingProtein:    json["remaining_protein"] as? Int
        )
    }
}
