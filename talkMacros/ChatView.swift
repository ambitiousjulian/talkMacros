import SwiftUI
import SwiftData

// MARK: - Shared Utility Views (available across module)

struct MiniBar: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.12))
                    .frame(width: geo.size.width, height: 4)
                if progress > 0 {
                    Capsule().fill(
                        LinearGradient(colors: [color.opacity(0.7), color],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(geo.size.width * CGFloat(min(progress, 1)), 6), height: 4)
                    .shadow(color: color.opacity(0.5), radius: 3)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7), value: progress)
                }
            }
        }
        .frame(height: 4)
    }
}

struct GoalBadge: View {
    let calProgress: Double
    let protProgress: Double

    private var overall: Double { min((calProgress + protProgress) / 2, 1.0) }
    private var pct: Int { Int(overall * 100) }
    private var color: Color { pct >= 90 ? .green : pct >= 50 ? .orange : Color(.tertiaryLabel) }

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 2.5)
                Circle().trim(from: 0, to: overall)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.9), value: overall)
            }
            .frame(width: 18, height: 18)
            Text("\(pct)%")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.1)))
    }
}

struct LargeRingView: View {
    let value: Int
    let goal: Int
    let color: Color
    let icon: String
    let label: String

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(value) / Double(goal), 1.0)
    }
    private var pct: Int { Int(progress * 100) }
    private var remaining: String {
        let r = max(0, goal - value)
        return r == 0 ? "Goal reached!" : "\(r) left"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(color.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.6), radius: 6)
                    .animation(.spring(response: 1.0, dampingFraction: 0.65), value: progress)
                VStack(spacing: 1) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(color)
                    Text("\(pct)%")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(color)
                }
            }
            .frame(width: 66, height: 66)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(2)
                Text("of \(goal)")
                    .font(.system(size: 11))
                    .foregroundColor(Color(.tertiaryLabel))
                MiniBar(progress: progress, color: color)
                    .frame(maxWidth: 110)
                    .padding(.top, 1)
                Text(remaining)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(progress >= 1 ? .black : color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(progress >= 1 ? color : color.opacity(0.15))
                    .clipShape(Capsule())
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - Chat View

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = ChatViewModel()
    @StateObject private var speech = SpeechRecognizer()
    @ObservedObject private var settings = SettingsManager.shared
    @Query private var allLogs: [DailyLog]

    @State private var inputText = ""
    @State private var showPermissionAlert = false

    private var todayLog: DailyLog? {
        let today = DateFormatter.dayFormatter.string(from: Date())
        return allLogs.first { $0.dateString == today }
    }
    private var liveCals: Int  { todayLog?.totalCalories ?? vm.todayCalories }
    private var liveProt: Int  { todayLog?.totalProtein  ?? vm.todayProtein  }

    private var calProgress: Double {
        guard settings.calorieGoal > 0 else { return 0 }
        return min(Double(liveCals) / Double(settings.calorieGoal), 1.0)
    }
    private var protProgress: Double {
        guard settings.proteinGoal > 0 else { return 0 }
        return min(Double(liveProt) / Double(settings.proteinGoal), 1.0)
    }
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty && !vm.isLoading
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                macrosHeader
                ZStack(alignment: .bottom) {
                    messageList
                    if speech.isRecording {
                        RecordingBanner(text: speech.transcribedText) { speech.stop() }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .zIndex(1)
                    }
                }
                .animation(.spring(duration: 0.3), value: speech.isRecording)
                inputBar
            }
            .navigationTitle("Talk Macros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.secondarySystemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { vm.setup(context: modelContext); speech.requestPermissions() }
            .onChange(of: speech.transcribedText) { _, t in inputText = t }
            .onChange(of: speech.isRecording) { _, recording in
                if !recording, !inputText.trimmingCharacters(in: .whitespaces).isEmpty { sendMessage() }
            }
            .onChange(of: speech.permissionDenied) { _, denied in showPermissionAlert = denied }
            .alert("Microphone Access Needed", isPresented: $showPermissionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable microphone and speech recognition in Settings to use voice input.")
            }
            .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
                Button("OK") { vm.dismissError() }
            } message: { Text(vm.errorMessage ?? "") }
            .sheet(isPresented: $vm.showDayPrompt) {
                if let info = vm.yesterdayInfo {
                    DayPickerSheet(yesterdayInfo: info) { vm.confirmDay(useToday: $0) }
                        .presentationDetents([.height(440)])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(28)
                }
            }
        }
    }

    // MARK: Macros Header

    private var macrosHeader: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(headerDay.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.8)
                        Text(headerDate)
                            .font(.subheadline.bold())
                    }
                    Spacer()
                    GoalBadge(calProgress: calProgress, protProgress: protProgress)
                }

                HStack(spacing: 0) {
                    LargeRingView(value: liveCals, goal: settings.calorieGoal,
                                  color: .orange, icon: "flame.fill", label: "Calories")
                        .frame(maxWidth: .infinity)

                    VStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { _ in
                            Circle().fill(Color(.separator)).frame(width: 3, height: 3)
                        }
                    }
                    .padding(.horizontal, 6)

                    LargeRingView(value: liveProt, goal: settings.proteinGoal,
                                  color: .green, icon: "bolt.fill", label: "Protein")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background {
                ZStack {
                    Color(.secondarySystemBackground)
                    RadialGradient(colors: [Color.orange.opacity(0.1), .clear],
                                   center: UnitPoint(x: 0.15, y: 0.5), startRadius: 5, endRadius: 160)
                    RadialGradient(colors: [Color.green.opacity(0.12), .clear],
                                   center: UnitPoint(x: 0.85, y: 0.5), startRadius: 5, endRadius: 160)
                }
            }
            Rectangle().fill(Color(.separator).opacity(0.4)).frame(height: 0.5)
        }
    }

    private var headerDay: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: Date())
    }
    private var headerDate: String {
        let f = DateFormatter(); f.dateFormat = "MMMM d"; return f.string(from: Date())
    }

    // MARK: Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg).id(msg.id)
                    }
                    if vm.isLoading { TypingIndicator() }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemBackground))
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: vm.isLoading) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    // MARK: Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Log a meal...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .lineLimit(1...5)

            Button { speech.toggle() } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 42, height: 42)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Circle())
            }

            Button { sendMessage() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canSend ? .black : .secondary)
                    .frame(width: 42, height: 42)
                    .background(canSend ? Color.green : Color(.tertiarySystemBackground))
                    .clipShape(Circle())
                    .shadow(color: canSend ? Color.green.opacity(0.4) : .clear, radius: 6, y: 2)
                    .animation(.spring(duration: 0.2), value: canSend)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        vm.send(text)
    }
}

// MARK: - Recording Banner

struct RecordingBanner: View {
    let text: String
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            WaveformBars()
            Text(text.isEmpty ? "Listening..." : text)
                .font(.subheadline)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.red.opacity(0.92))
                .shadow(color: Color.red.opacity(0.4), radius: 14, y: 4)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}

struct WaveformBars: View {
    @State private var animating = false
    private let heights: [CGFloat] = [0.45, 1.0, 0.65, 0.85, 0.5]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2).fill(Color.white)
                    .frame(width: 3, height: animating ? 20 * heights[i] : 5)
                    .animation(
                        .easeInOut(duration: 0.4 + Double(i) * 0.05)
                            .repeatForever(autoreverses: true).delay(Double(i) * 0.08),
                        value: animating
                    )
            }
        }
        .frame(width: 28, height: 22)
        .onAppear { animating = true }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.isUser { userBubble } else { claudeBubble }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(alignment: .bottom) {
                Spacer(minLength: 60)
                Text(message.content)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.05, green: 0.85, blue: 0.35),
                                     Color(red: 0.0, green: 0.7, blue: 0.25)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.green.opacity(0.35), radius: 8, y: 3)
                    .textSelection(.enabled)
            }
            Text(message.timestamp, format: .dateTime.hour().minute())
                .font(.caption2)
                .foregroundColor(Color(.quaternaryLabel))
                .padding(.trailing, 4)
        }
    }

    private var claudeBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 9) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.08)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 30, height: 30)
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(message.content)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                        .background(Color(.tertiarySystemBackground))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
                        )
                        .textSelection(.enabled)
                    if let card = message.mealCard {
                        MealLogCard(card: card)
                    }
                }
                Spacer(minLength: 44)
            }
            Text(message.timestamp, format: .dateTime.hour().minute())
                .font(.caption2)
                .foregroundColor(Color(.quaternaryLabel))
                .padding(.leading, 39)
        }
    }
}

// MARK: - Meal Log Card

struct MacroPill: View {
    let value: Int
    let unit: String
    let contribution: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Text(unit)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }
            Text("+\(contribution)% of daily goal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct MealLogCard: View {
    let card: MealCard
    @ObservedObject private var settings = SettingsManager.shared

    private var calContrib: Int {
        guard settings.calorieGoal > 0 else { return 0 }
        return max(1, Int(Double(card.calories) / Double(settings.calorieGoal) * 100))
    }
    private var protContrib: Int {
        guard settings.proteinGoal > 0 else { return 0 }
        return max(1, Int(Double(card.protein) / Double(settings.proteinGoal) * 100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Green header
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    Text("Added to today's log")
                        .font(.caption2.bold())
                        .opacity(0.8)
                }
                Spacer()
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(colors: [Color(red: 0.05, green: 0.85, blue: 0.35),
                                        Color(red: 0.0, green: 0.7, blue: 0.25)],
                               startPoint: .leading, endPoint: .trailing)
            )

            // Body
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    MacroPill(value: card.calories, unit: "cal",
                               contribution: calContrib, color: .orange)
                    MacroPill(value: card.protein, unit: "g prot",
                               contribution: protContrib, color: .green)
                }

                Divider().opacity(0.4)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Running total today")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        Label("\(card.dailyCalories)", systemImage: "flame.fill").foregroundColor(.orange)
                        Label("\(card.dailyProtein)g", systemImage: "bolt.fill").foregroundColor(.green)
                    }
                    .font(.caption.bold())
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.green.opacity(0.22), radius: 10, y: 4)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.green.opacity(0.2), Color.green.opacity(0.08)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
            }
            .padding(.top, 2)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color(.tertiaryLabel))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1.2 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(.separator).opacity(0.4), lineWidth: 0.5)
            )

            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
    }
}
