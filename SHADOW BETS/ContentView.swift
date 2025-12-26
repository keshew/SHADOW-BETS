import SwiftUI

import SwiftUI

// MARK: - Models
struct GameRecord: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let gameMode: GameMode
    let betAmount: Double
    let potWon: Double
    let result: GameResult
}

struct AppState: Codable {
    var balance: Double = 1000
    var gameHistory: [GameRecord] = []
    var selectedBot: String = "Alex_777"
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
}

enum GameMode: String, CaseIterable, Codable {
    case dice = "Shadow Dice"
    case roulette = "Shadow Roulette"
    case cards = "Shadow Cards"
    case coins = "Shadow Coins"
    case race = "Shadow Race"
}

enum GameResult: String, Codable {
    case win = "You Win!"
    case loss = "Bot Wins!"
    case draw = "Draw"
}

// MARK: - Storage
class AppStorage: ObservableObject {
    @Published var appState: AppState {
        didSet { save() }
    }
    
    init() {
        if let data = UserDefaults.standard.data(forKey: "ShadowBetsAppState"),
           let decoded = try? JSONDecoder().decode(AppState.self, from: data) {
            appState = decoded
        } else {
            appState = AppState()
        }
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(appState) {
            UserDefaults.standard.set(data, forKey: "ShadowBetsAppState")
        }
    }
    
    func addGameRecord(_ record: GameRecord) {
        appState.gameHistory.insert(record, at: 0)
        appState.gameHistory = Array(appState.gameHistory.prefix(50)) // Keep last 50
    }
}

// Добавь ЭТОТ КОД в конец твоего файла (после GameDetailView)

import AVFoundation // для звуков

// MARK: - 🎲 SHADOW DICE GAME MODELS
struct DiceSession {
    var currentPot: Double = 0
    var yourRoll: Int = 0
    var botRoll: Int = 0
    var yourGuess: DiceGuess = .even
    var botGuess: DiceGuess = .even
    var gameResult: DiceGameResult = .none
}

enum DiceGuess: String, CaseIterable {
    case even = "Even"
    case odd = "Odd"
}

enum DiceGameResult: String, Codable {
    case none = "None"
    case youWin = "You Win!"
    case botWin = "Bot Wins!"
}

// MARK: - 🎲 Dice ViewModel
@MainActor
class DiceViewModel: ObservableObject {
    @Published var session = DiceSession()
    @Published var isTyping = false
    @Published var botMessage = ""
    @Published var isAnimating = false
    @Published var showResult = false
    @Published var balance: Double
    
    private let storage: AppStorage
    private let botNames = ["Alex_777", "CryptoCat", "NeonGhost"]
    
    init(storage: AppStorage) {
        self.storage = storage
        self.balance = storage.appState.balance
    }
    
    func placeBet() {
        guard balance >= 25 else { return }
        
        balance -= 25
        session.currentPot += 25
        storage.appState.balance = balance
        
        simulateBotTyping()
    }
    
    func makeGuess(_ guess: DiceGuess) {
        session.yourGuess = guess
        
        withAnimation(.spring()) {
            isAnimating = true
        }
        
        rollYourDice()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.checkWinner()
            self.saveToHistory()
            self.showResult = true
        }
    }
    
    func newGame() {
        session = DiceSession()
        showResult = false
        isAnimating = false
    }
    
    private func simulateBotTyping() {
        isTyping = true
        botMessage = "\(pickRandomBot()) is typing..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.isTyping = false
            self.session.botGuess = Bool.random() ? .even : .odd
            self.botMessage = "\(self.pickRandomBot()) bets on \(self.session.botGuess.rawValue)! 💪"
        }
    }
    
    private func rollYourDice() {
        let die1 = Int.random(in: 1...6)
        let die2 = Int.random(in: 1...6)
        session.yourRoll = die1 + die2
    }
    
    private func checkWinner() {
        let isEven = session.yourRoll.isMultiple(of: 2)
        let youWin = (session.yourGuess == .even && isEven) ||
                     (session.yourGuess == .odd && !isEven)
        
        if youWin {
            session.gameResult = .youWin
            balance += session.currentPot * 10
        } else {
            session.gameResult = .botWin
        }
        
        storage.appState.balance = balance
    }
    
    private func saveToHistory() {
        let record = GameRecord(
            date: Date(),
            gameMode: .dice,
            betAmount: 25,
            potWon: session.gameResult == .youWin ? session.currentPot * 10 : 0,
            result: session.gameResult == .youWin ? .win : .loss
        )
        storage.addGameRecord(record)
    }
    
    private func pickRandomBot() -> String {
        botNames.randomElement() ?? "Alex_777"
    }
}

// MARK: - 🎲 Dice Components
struct DiceFace: View {
    let number: Int
    let isAnimating: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 65, height: 65)
                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 2))
            
            ForEach(diceDots(for: number), id: \.self) { pos in
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .offset(x: pos.x, y: pos.y)
            }
        }
        .scaleEffect(isAnimating ? 1.1 : 1.0)
        .rotationEffect(isAnimating ? .degrees(360) : .degrees(0))
        .animation(.spring(duration: 0.6).repeatCount(2), value: isAnimating)
    }
    
    private func diceDots(for number: Int) -> [CGPoint] {
        switch number {
        case 1: return [CGPoint(x: 0, y: 0)]
        case 2: return [CGPoint(x: -16, y: -16), CGPoint(x: 16, y: 16)]
        case 3: return [CGPoint(x: -16, y: -16), CGPoint(x: 0, y: 0), CGPoint(x: 16, y: 16)]
        case 4: return [CGPoint(x: -16, y: -16), CGPoint(x: 16, y: -16),
                       CGPoint(x: -16, y: 16), CGPoint(x: 16, y: 16)]
        case 5: return [CGPoint(x: -16, y: -16), CGPoint(x: 16, y: -16),
                       CGPoint(x: 0, y: 0), CGPoint(x: -16, y: 16), CGPoint(x: 16, y: 16)]
        case 6: return [CGPoint(x: -16, y: -24), CGPoint(x: 16, y: -24),
                       CGPoint(x: -16, y: 0), CGPoint(x: 16, y: 0),
                       CGPoint(x: -16, y: 24), CGPoint(x: 16, y: 24)]
        default: return []
        }
    }
}

// MARK: - 🎡 SHADOW ROULETTE GAME MODELS
struct RouletteSession {
    var currentPot: Double = 0
    var yourResult: Int = 0  // 0=Green, 1-18=Red, 19-36=Black
    var botResult: Int = 0
    var yourGuess: RouletteGuess = .red
    var botGuess: RouletteGuess = .red
    var gameResult: DiceGameResult = .none  // Переиспользуем
}

enum RouletteGuess: String, CaseIterable {
    case red = "Red x2"
    case black = "Black x2"
    case green = "Green x14"
}

// MARK: - 🎡 Roulette ViewModel
@MainActor
class RouletteViewModel: ObservableObject {
    @Published var session = RouletteSession()
    @Published var isTyping = false
    @Published var botMessage = ""
    @Published var isAnimating = false
    @Published var showResult = false
    @Published var balance: Double
    @Published var wheelAngle: Angle = .degrees(0)
    
    private let storage: AppStorage
    private let botNames = ["Alex_777", "CryptoCat", "NeonGhost"]
    
    init(storage: AppStorage) {
        self.storage = storage
        self.balance = storage.appState.balance
    }
    
    func placeBet() {
        guard balance >= 25 else { return }
        
        balance -= 25
        session.currentPot += 25
        storage.appState.balance = balance
        
        simulateBotTyping()
    }
    
    func makeGuess(_ guess: RouletteGuess) {
        session.yourGuess = guess
        
        withAnimation(.spring()) {
            isAnimating = true
        }
        
        rollYourRoulette()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.checkWinner()
            self.saveToHistory()
            self.showResult = true
        }
    }
    
    func newGame() {
        session = RouletteSession()
        showResult = false
        isAnimating = false
        wheelAngle = .degrees(0)
    }
    
    private func simulateBotTyping() {
        isTyping = true
        botMessage = "\(pickRandomBot()) is typing..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.isTyping = false
            self.session.botGuess = RouletteGuess.allCases.randomElement()!
            self.botMessage = "\(self.pickRandomBot()) bets on \(self.session.botGuess.rawValue)! 🎡"
        }
    }
    
    private func rollYourRoulette() {
        session.yourResult = Int.random(in: 0...36)
        
        // Анимация рулетки
        let spins = 5 + Double.random(in: 2...4)
        let targetAngle = Angle(degrees: Double(session.yourResult) * 10 + spins * 360)
        
        withAnimation(.easeInOut(duration: 2.5)) {
            wheelAngle = targetAngle
        }
    }
    
    private func checkWinner() {
        let color = getColor(for: session.yourResult)
        let youWin = (session.yourGuess.rawValue.contains(color.capitalized) ||
                      (session.yourGuess == .green && session.yourResult == 0))
        
        if youWin {
            session.gameResult = .youWin
            balance += session.currentPot * 10
        } else {
            session.gameResult = .botWin
        }
        
        storage.appState.balance = balance
    }
    
    private func getColor(for number: Int) -> String {
        if number == 0 { return "Green" }
        return (number % 2 == 1) ? "Red" : "Black"
    }
    
    private func saveToHistory() {
        let record = GameRecord(
            date: Date(),
            gameMode: .roulette,
            betAmount: 25,
            potWon: session.gameResult == .youWin ? session.currentPot * 10 : 0,
            result: session.gameResult == .youWin ? .win : .loss
        )
        storage.addGameRecord(record)
    }
    
    private func pickRandomBot() -> String {
        botNames.randomElement() ?? "Alex_777"
    }
}

// MARK: - 🎡 Roulette Wheel Component
struct RouletteWheel: View {
    let result: Int
    let isAnimating: Bool
    @Binding var wheelAngle: Angle
    
    var body: some View {
        ZStack {
            // Внешний круг
            Circle()
                .fill(LinearGradient(colors: [.red, .black, .red, .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 200, height: 200)
                .rotationEffect(wheelAngle)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 4)
                )
            
            // Центральная стрелка
            Triangle()
                .fill(Color.yellow)
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(90))
                .offset(y: -100)
        }
        .scaleEffect(isAnimating ? 1.05 : 1.0)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 🎡 Shadow Roulette View
struct ShadowRouletteGameView: View {
    @StateObject private var viewModel: RouletteViewModel
    let storage: AppStorage
    @Environment(\.dismiss) private var dismiss
    
    init(storage: AppStorage) {
        self.storage = storage
        _viewModel = StateObject(wrappedValue: RouletteViewModel(storage: storage))
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    HStack {
                        Spacer()
                        Text("🎡 SHADOW ROULETTE")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundColor(.white)
                    }
                    
                    // Balance & Pot
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BALANCE").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.balance).formatted())").font(.title2.weight(.semibold)).foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("POT").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.session.currentPot).formatted())").font(.title2.weight(.semibold)).foregroundColor(.yellow)
                        }
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    
                    // Game Area
                    VStack(spacing: 20) {
                        // Roulette Wheel
                        VStack {
                            Text("YOUR SPIN").font(.headline).foregroundColor(.white)
                            
                            RouletteWheel(result: viewModel.session.yourResult,
                                        isAnimating: viewModel.isAnimating,
                                        wheelAngle: $viewModel.wheelAngle)
                            
                            if viewModel.session.yourResult > 0 {
                                Text("\(viewModel.session.yourResult)")
                                    .font(.title2.weight(.heavy))
                                    .foregroundColor(
                                        viewModel.session.yourResult == 0 ? .green :
                                        viewModel.session.yourResult % 2 == 1 ? .red : .black
                                    )
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(20)
                        
                        // Bot Guess
                        VStack {
                            Text("BOT GUESSES").font(.headline).foregroundColor(.orange)
                            Text(viewModel.session.botGuess.rawValue)
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(.yellow)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(20)
                    }
                    
                    // ✅ Guess Buttons - ТОЛЬКО после ставки!
                    if !viewModel.showResult {
                        if viewModel.session.currentPot > 0 {
                            // ✅ Кнопки активны после PLAY $25
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                                ForEach(RouletteGuess.allCases, id: \.self) { guess in
                                    Button(action: {
                                        viewModel.makeGuess(guess)
                                    }) {
                                        VStack(spacing: 8) {
                                            Circle()
                                                .fill(guess == .red ? .red :
                                                      guess == .black ? .black : .green)
                                                .frame(width: 40, height: 40)
                                                .overlay(
                                                    Text(guess == .red ? "🔴" :
                                                         guess == .black ? "⚫" : "🟢")
                                                        .font(.title2)
                                                )
                                            Text(guess.rawValue)
                                                .font(.headline.weight(.semibold))
                                                .foregroundColor(.white)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(20)
                                        .background(
                                            guess == viewModel.session.yourGuess ?
                                            Color.yellow.opacity(0.3) :
                                            Color.gray.opacity(0.3)
                                        )
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    guess == viewModel.session.yourGuess ? Color.yellow : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                }
                            }
                        } else {
                            // ✅ Сообщение до ставки
                            VStack(spacing: 15) {
                                Text("Place bet first!")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 100)
                                    .cornerRadius(20)
                            }
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        if viewModel.showResult {
                            Text(viewModel.session.gameResult.rawValue)
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundColor(viewModel.session.gameResult == .youWin ? .green : .red)
                                .scaleEffect(1.1)
                                .animation(.easeInOut(duration: 0.4).repeatCount(3), value: viewModel.session.gameResult)
                            
                            Button("NEW GAME") {
                                viewModel.newGame()
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Color.green)
                            .cornerRadius(25)
                            .shadow(color: .green.opacity(0.4), radius: 10)
                        } else {
                            Button("PLAY $25 →") {
                                viewModel.placeBet()
                            }
                            .font(.title2.weight(.bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(25)
                            .shadow(color: .yellow.opacity(0.5), radius: 15)
                            .disabled(viewModel.balance < 25 || viewModel.session.currentPot > 0 || viewModel.showResult)
                        }
                    }
                    
                    // Bot Messages
                    Group {
                        if viewModel.isTyping {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle().fill(.gray.opacity(0.7))
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(0.6 + Double(i) * 0.25)
                                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: UUID())
                                }
                            }
                        } else {
                            Text(viewModel.botMessage)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(height: 40)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}


// MARK: - 🃏 SHADOW CARDS GAME MODELS
struct CardsSession {
    var currentPot: Double = 0
    var yourCard: Int = 0  // 0=Hearts, 1=Spades, 2=Diamonds, 3=Clubs
    var botCard: Int = 0
    var yourGuess: CardSuit = .hearts
    var botGuess: CardSuit = .hearts
    var gameResult: DiceGameResult = .none
}

enum CardSuit: String, CaseIterable {
    case hearts = "♥️ Hearts x4"
    case spades = "♠️ Spades x4"
    case diamonds = "♦️ Diamonds x4"
    case clubs = "♣️ Clubs x4"
}

// MARK: - 🃏 Cards ViewModel
@MainActor
class CardsViewModel: ObservableObject {
    @Published var session = CardsSession()
    @Published var isTyping = false
    @Published var botMessage = ""
    @Published var isAnimating = false
    @Published var showResult = false
    @Published var balance: Double
    @Published var flipAngle: Angle = .degrees(0)
    
    private let storage: AppStorage
    private let botNames = ["Alex_777", "CryptoCat", "NeonGhost"]
    
    init(storage: AppStorage) {
        self.storage = storage
        self.balance = storage.appState.balance
    }
    
    func placeBet() {
        guard balance >= 25 else { return }
        
        balance -= 25
        session.currentPot += 25
        storage.appState.balance = balance
        
        simulateBotTyping()
    }
    
    func makeGuess(_ guess: CardSuit) {
        session.yourGuess = guess
        
        withAnimation(.spring()) {
            isAnimating = true
        }
        
        rollYourCard()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.checkWinner()
            self.saveToHistory()
            self.showResult = true
        }
    }
    
    func newGame() {
        session = CardsSession()
        showResult = false
        isAnimating = false
        flipAngle = .degrees(0)
    }
    
    private func simulateBotTyping() {
        isTyping = true
        botMessage = "\(pickRandomBot()) is typing..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.isTyping = false
            self.session.botGuess = CardSuit.allCases.randomElement()!
            self.botMessage = "\(self.pickRandomBot()) bets on \(self.session.botGuess.rawValue)! 🃏"
        }
    }
    
    private func rollYourCard() {
        session.yourCard = Int.random(in: 0...3)
        
        // Анимация переворота карты
        withAnimation(.easeInOut(duration: 1.2)) {
            flipAngle = .degrees(180)
        }
    }
    
    private func checkWinner() {
        let youWin = session.yourCard == CardSuit.allCases.firstIndex(of: session.yourGuess)
        
        if youWin {
            session.gameResult = .youWin
            balance += session.currentPot * 10
        } else {
            session.gameResult = .botWin
        }
        
        storage.appState.balance = balance
    }
    
    private func saveToHistory() {
        let record = GameRecord(
            date: Date(),
            gameMode: .cards,
            betAmount: 25,
            potWon: session.gameResult == .youWin ? session.currentPot * 10 : 0,
            result: session.gameResult == .youWin ? .win : .loss
        )
        storage.addGameRecord(record)
    }
    
    private func pickRandomBot() -> String {
        botNames.randomElement() ?? "Alex_777"
    }
}

// MARK: - 🃏 Card Component
struct PlayingCard: View {
    let suitIndex: Int
    let isAnimating: Bool
    let flipAngle: Angle
    
    private let suits = ["♥️", "♠️", "♦️", "♣️"]
    private let suitColors: [Color] = [.red, .black, .red, .black]
    
    var body: some View {
        ZStack {
            // Карта сзади
            RoundedRectangle(cornerRadius: 15)
                .fill(LinearGradient(colors: [.purple.opacity(0.8), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 100, height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )
                .opacity(flipAngle.degrees > 90 ? 0 : 1)
            
            // Карта спереди
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
                .frame(width: 100, height: 140)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.black, lineWidth: 2)
                )
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            Text(suits[suitIndex])
                                .font(.largeTitle)
                                .foregroundColor(suitColors[suitIndex])
                            Spacer()
                        }
                        Spacer()
                    }
                )
                .opacity(flipAngle.degrees > 90 ? 1 : 0)
        }
        .scaleEffect(isAnimating ? 1.1 : 1.0)
        .rotation3DEffect(flipAngle, axis: (x: 0, y: 1, z: 0))
        .animation(.spring(duration: 0.8), value: isAnimating)
    }
}

// MARK: - 🃏 Shadow Cards View
struct ShadowCardsGameView: View {
    @StateObject private var viewModel: CardsViewModel
    let storage: AppStorage
    @Environment(\.dismiss) private var dismiss
    
    init(storage: AppStorage) {
        self.storage = storage
        _viewModel = StateObject(wrappedValue: CardsViewModel(storage: storage))
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    HStack {
                        Spacer()
                        Text("🃏 SHADOW CARDS")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundColor(.white)
                    }
                    
                    // Balance & Pot
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BALANCE").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.balance).formatted())").font(.title2.weight(.semibold)).foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("POT").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.session.currentPot).formatted())").font(.title2.weight(.semibold)).foregroundColor(.yellow)
                        }
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    
                    // Game Area
                    VStack(spacing: 20) {
                        // Your Card
                        VStack {
                            Text("YOUR CARD").font(.headline).foregroundColor(.white)
                            
                            PlayingCard(suitIndex: viewModel.session.yourCard,
                                      isAnimating: viewModel.isAnimating,
                                      flipAngle: viewModel.flipAngle)
                            
                            if viewModel.session.yourCard >= 0 {
                                Text(viewModel.session.yourGuess.rawValue.contains("♥️") ? "♥️" :
                                     viewModel.session.yourGuess.rawValue.contains("♠️") ? "♠️" :
                                     viewModel.session.yourGuess.rawValue.contains("♦️") ? "♦️" : "♣️")
                                    .font(.title2.weight(.heavy))
                                    .foregroundColor(viewModel.session.gameResult == .youWin ? .green : .red)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(20)
                        
                        // Bot Guess
                        VStack {
                            Text("BOT GUESSES").font(.headline).foregroundColor(.orange)
                            Text(viewModel.session.botGuess.rawValue)
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(.yellow)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(20)
                    }
                    
                    // ✅ Guess Buttons - ТОЛЬКО после ставки!
                    if !viewModel.showResult {
                        if viewModel.session.currentPot > 0 {
                            // ✅ Кнопки активны после PLAY $25
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 2)) {
                                ForEach(CardSuit.allCases, id: \.self) { suit in
                                    Button(action: {
                                        viewModel.makeGuess(suit)
                                    }) {
                                        HStack(spacing: 12) {
                                            Text(String(suit.rawValue.prefix(2)))
                                                .font(.title2)
                                                .foregroundColor(suit == .hearts || suit == .diamonds ? .red : .black)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(String(suit.rawValue.dropFirst(2).prefix(6)))
                                                    .font(.headline.weight(.semibold))
                                                    .foregroundColor(.white)
                                                Text("x10")
                                                    .font(.caption)
                                                    .foregroundColor(.yellow)
                                            }
                                            
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(20)
                                        .background(
                                            suit == viewModel.session.yourGuess ?
                                            Color.yellow.opacity(0.3) :
                                            Color.gray.opacity(0.3)
                                        )
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    suit == viewModel.session.yourGuess ? Color.yellow : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                }
                            }
                        } else {
                            // ✅ Сообщение до ставки
                            VStack(spacing: 15) {
                                Text("Place bet first!")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 120)
                                    .cornerRadius(20)
                            }
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        if viewModel.showResult {
                            Text(viewModel.session.gameResult.rawValue)
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundColor(viewModel.session.gameResult == .youWin ? .green : .red)
                                .scaleEffect(1.1)
                                .animation(.easeInOut(duration: 0.4).repeatCount(3), value: viewModel.session.gameResult)
                            
                            Button("NEW GAME") {
                                viewModel.newGame()
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Color.green)
                            .cornerRadius(25)
                            .shadow(color: .green.opacity(0.4), radius: 10)
                        } else {
                            Button("PLAY $25 →") {
                                viewModel.placeBet()
                            }
                            .font(.title2.weight(.bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(25)
                            .shadow(color: .yellow.opacity(0.5), radius: 15)
                            .disabled(viewModel.balance < 25 || viewModel.session.currentPot > 0 || viewModel.showResult)
                        }
                    }
                    
                    // Bot Messages
                    Group {
                        if viewModel.isTyping {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle().fill(.gray.opacity(0.7))
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(0.6 + Double(i) * 0.25)
                                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: UUID())
                                }
                            }
                        } else {
                            Text(viewModel.botMessage)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(height: 40)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}


// MARK: - 🪙 SHADOW COINS GAME MODELS
struct CoinsSession {
    var currentPot: Double = 0
    var yourResult: Int = 0  // 0=Heads, 1=Tails
    var botResult: Int = 0
    var yourGuess: CoinSide = .heads
    var botGuess: CoinSide = .heads
    var gameResult: DiceGameResult = .none
}

enum CoinSide: String, CaseIterable {
    case heads = "👑 Heads x2"
    case tails = "📈 Tails x2"
}

// MARK: - 🪙 Coins ViewModel
@MainActor
class CoinsViewModel: ObservableObject {
    @Published var session = CoinsSession()
    @Published var isTyping = false
    @Published var botMessage = ""
    @Published var isAnimating = false
    @Published var showResult = false
    @Published var balance: Double
    @Published var flipAngle: Angle = .degrees(0)
    
    private let storage: AppStorage
    private let botNames = ["Alex_777", "CryptoCat", "NeonGhost"]
    
    init(storage: AppStorage) {
        self.storage = storage
        self.balance = storage.appState.balance
    }
    
    func placeBet() {
        guard balance >= 25 else { return }
        
        balance -= 25
        session.currentPot += 25
        storage.appState.balance = balance
        
        simulateBotTyping()
    }
    
    func makeGuess(_ guess: CoinSide) {
        session.yourGuess = guess
        
        withAnimation(.spring()) {
            isAnimating = true
        }
        
        flipCoin()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.checkWinner()
            self.saveToHistory()
            self.showResult = true
        }
    }
    
    func newGame() {
        session = CoinsSession()
        showResult = false
        isAnimating = false
        flipAngle = .degrees(0)
    }
    
    private func simulateBotTyping() {
        isTyping = true
        botMessage = "\(pickRandomBot()) is typing..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.isTyping = false
            self.session.botGuess = Bool.random() ? .heads : .tails
            self.botMessage = "\(self.pickRandomBot()) bets on \(self.session.botGuess.rawValue)! 🪙"
        }
    }
    
    private func flipCoin() {
        session.yourResult = Int.random(in: 0...1)
        
        // Анимация подбрасывания монеты
        withAnimation(.easeInOut(duration: 1.0)) {
            flipAngle = .degrees(720 + Double(session.yourResult) * 180)
        }
    }
    
    private func checkWinner() {
        let youWin = session.yourResult == (session.yourGuess == .heads ? 0 : 1)
        
        if youWin {
            session.gameResult = .youWin
            balance += session.currentPot * 10
        } else {
            session.gameResult = .botWin
        }
        
        storage.appState.balance = balance
    }
    
    private func saveToHistory() {
        let record = GameRecord(
            date: Date(),
            gameMode: .coins,
            betAmount: 25,
            potWon: session.gameResult == .youWin ? session.currentPot * 10 : 0,
            result: session.gameResult == .youWin ? .win : .loss
        )
        storage.addGameRecord(record)
    }
    
    private func pickRandomBot() -> String {
        botNames.randomElement() ?? "Alex_777"
    }
}

// MARK: - 🪙 Coin Component
struct CoinView: View {
    let result: Int  // 0=Heads, 1=Tails
    let isAnimating: Bool
    let flipAngle: Angle
    
    var body: some View {
        ZStack {
            // Монета сзади (Tails)
            Circle()
                .fill(LinearGradient(colors: [.gray.opacity(0.8), .black], startPoint: .top, endPoint: .bottom))
                .frame(width: 90, height: 90)
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 3))
                .overlay(
                    Image(systemName: "arrow.triangle.swap.2")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                )
                .rotationEffect(.degrees(180))
                .opacity(flipAngle.degrees.truncatingRemainder(dividingBy: 360) > 180 ? 0 : 1)
            
            // Монета спереди (Heads)
            Circle()
                .fill(LinearGradient(colors: [.yellow.opacity(0.9), .orange], startPoint: .top, endPoint: .bottom))
                .frame(width: 90, height: 90)
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 3))
                .overlay(
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.black)
                )
                .opacity(flipAngle.degrees.truncatingRemainder(dividingBy: 360) > 180 ? 1 : 0)
        }
        .scaleEffect(isAnimating ? 1.15 : 1.0)
        .rotationEffect(flipAngle)
        .animation(.spring(duration: 0.6), value: isAnimating)
        .shadow(color: .yellow.opacity(0.4), radius: 10)
    }
}

// MARK: - 🪙 Shadow Coins View
struct ShadowCoinsGameView: View {
    @StateObject private var viewModel: CoinsViewModel
    let storage: AppStorage
    @Environment(\.dismiss) private var dismiss
    
    init(storage: AppStorage) {
        self.storage = storage
        _viewModel = StateObject(wrappedValue: CoinsViewModel(storage: storage))
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    HStack {
                        Spacer()
                        Text("🪙 SHADOW COINS")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundColor(.white)
                    }
                    
                    // Balance & Pot
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BALANCE").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.balance).formatted())").font(.title2.weight(.semibold)).foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("POT").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.session.currentPot).formatted())").font(.title2.weight(.semibold)).foregroundColor(.yellow)
                        }
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    
                    // Game Area
                    VStack(spacing: 20) {
                        // Your Coin
                        VStack {
                            Text("YOUR FLIP").font(.headline).foregroundColor(.white)
                            
                            CoinView(result: viewModel.session.yourResult,
                                   isAnimating: viewModel.isAnimating,
                                   flipAngle: viewModel.flipAngle)
                            
                            if viewModel.session.yourResult >= 0 {
                                Text(viewModel.session.yourResult == 0 ? "👑 HEADS" : "📈 TAILS")
                                    .font(.title2.weight(.heavy))
                                    .foregroundColor(viewModel.session.gameResult == .youWin ? .green : .red)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(20)
                        
                        // Bot Guess
                        VStack {
                            Text("BOT GUESSES").font(.headline).foregroundColor(.orange)
                            Text(viewModel.session.botGuess.rawValue)
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(.yellow)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(20)
                    }
                    
                    // ✅ Guess Buttons - ТОЛЬКО после ставки!
                    if !viewModel.showResult {
                        if viewModel.session.currentPot > 0 {
                            // ✅ Кнопки активны после PLAY $25
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                                ForEach(CoinSide.allCases, id: \.self) { side in
                                    Button(action: {
                                        viewModel.makeGuess(side)
                                    }) {
                                        VStack(spacing: 12) {
                                            Image(systemName: side == .heads ? "crown.fill" : "arrow.triangle.swap.2")
                                                .font(.system(size: 40))
                                                .foregroundColor(side == .heads ? .yellow : .gray)
                                            
                                            Text(side.rawValue)
                                                .font(.headline.weight(.semibold))
                                                .foregroundColor(.white)
                                            
                                            Text("x10")
                                                .font(.title3.weight(.heavy))
                                                .foregroundColor(.yellow)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(25)
                                        .background(
                                            side == viewModel.session.yourGuess ?
                                            Color.yellow.opacity(0.3) :
                                            Color.gray.opacity(0.3)
                                        )
                                        .cornerRadius(25)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 25)
                                                .stroke(
                                                    side == viewModel.session.yourGuess ? Color.yellow : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                }
                            }
                        } else {
                            // ✅ Сообщение до ставки
                            VStack(spacing: 15) {
                                Text("Place bet first!")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 120)
                                    .cornerRadius(25)
                            }
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(25)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        if viewModel.showResult {
                            Text(viewModel.session.gameResult.rawValue)
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundColor(viewModel.session.gameResult == .youWin ? .green : .red)
                                .scaleEffect(1.1)
                                .animation(.easeInOut(duration: 0.4).repeatCount(3), value: viewModel.session.gameResult)
                            
                            Button("NEW GAME") {
                                viewModel.newGame()
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Color.green)
                            .cornerRadius(25)
                            .shadow(color: .green.opacity(0.4), radius: 10)
                        } else {
                            Button("PLAY $25 →") {
                                viewModel.placeBet()
                            }
                            .font(.title2.weight(.bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(25)
                            .shadow(color: .yellow.opacity(0.5), radius: 15)
                            .disabled(viewModel.balance < 25 || viewModel.session.currentPot > 0 || viewModel.showResult)
                        }
                    }
                    
                    // Bot Messages
                    Group {
                        if viewModel.isTyping {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle().fill(.gray.opacity(0.7))
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(0.6 + Double(i) * 0.25)
                                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: UUID())
                                }
                            }
                        } else {
                            Text(viewModel.botMessage)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(height: 40)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}


// MARK: - 🏁 SHADOW RACE GAME MODELS
struct RaceSession {
    var currentPot: Double = 0
    var yourResult: Int = 0  // 1,2,3 - победившая лошадь
    var botResult: Int = 0
    var yourGuess: Horse = .horse1
    var botGuess: Horse = .horse1
    var gameResult: DiceGameResult = .none
}

enum Horse: String, CaseIterable {
    case horse1 = "🐎 #1 x4"
    case horse2 = "🐎 #2 x4"
    case horse3 = "🐎 #3 x4"
}

// MARK: - 🏁 Race ViewModel
@MainActor
class RaceViewModel: ObservableObject {
    @Published var session = RaceSession()
    @Published var isTyping = false
    @Published var botMessage = ""
    @Published var isAnimating = false
    @Published var showResult = false
    @Published var balance: Double
    @Published var horsePositions: [CGFloat] = [0, 0, 0]  // Прогресс лошадей
    
    private let storage: AppStorage
    private let botNames = ["Alex_777", "CryptoCat", "NeonGhost"]
    
    init(storage: AppStorage) {
        self.storage = storage
        self.balance = storage.appState.balance
    }
    
    func placeBet() {
        guard balance >= 25 else { return }
        
        balance -= 25
        session.currentPot += 25
        storage.appState.balance = balance
        
        simulateBotTyping()
    }
    
    func makeGuess(_ horse: Horse) {
        session.yourGuess = horse
        
        withAnimation(.spring()) {
            isAnimating = true
        }
        
        startRace()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.finishRace()
            self.checkWinner()
            self.saveToHistory()
            self.showResult = true
        }
    }
    
    func newGame() {
        session = RaceSession()
        horsePositions = [0, 0, 0]
        showResult = false
        isAnimating = false
    }
    
    private func simulateBotTyping() {
        isTyping = true
        botMessage = "\(pickRandomBot()) is typing..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            self.isTyping = false
            self.session.botGuess = Horse.allCases.randomElement()!
            self.botMessage = "\(self.pickRandomBot()) bets on \(self.session.botGuess.rawValue)! 🏁"
        }
    }
    
    private func startRace() {
        session.yourResult = Int.random(in: 1...3)
        
        // Анимация гонки (30 сек в миниатюре = 3 сек)
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            for i in 0..<3 {
                let speed = 2.0 + Double.random(in: 0...1.5)
                self.horsePositions[i] = min(self.horsePositions[i] + CGFloat(speed), 300)
            }
            
            if self.horsePositions.contains(where: { $0 >= 300 }) {
                timer.invalidate()
            }
        }
    }
    
    private func finishRace() {
        // Финализируем позиции по результату
        horsePositions = [0, 0, 0]
        horsePositions[session.yourResult - 1] = 320
    }
    
    private func checkWinner() {
        let youWin = session.yourResult == Horse.allCases.firstIndex(of: session.yourGuess)! + 1
        
        if youWin {
            session.gameResult = .youWin
            balance += session.currentPot * 10
        } else {
            session.gameResult = .botWin
        }
        
        storage.appState.balance = balance
    }
    
    private func saveToHistory() {
        let record = GameRecord(
            date: Date(),
            gameMode: .race,
            betAmount: 25,
            potWon: session.gameResult == .youWin ? session.currentPot * 10 : 0,
            result: session.gameResult == .youWin ? .win : .loss
        )
        storage.addGameRecord(record)
    }
    
    private func pickRandomBot() -> String {
        botNames.randomElement() ?? "Alex_777"
    }
}

// MARK: - 🏁 Horse Component
struct HorseView: View {
    let horseNumber: Int
    let position: CGFloat
    let isAnimating: Bool
    let isWinner: Bool
    
    private let horseColors: [Color] = [.blue, .green, .orange]
    
    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(horseColors[horseNumber])
                .frame(width: 45, height: 45)
                .overlay(
                    Text("🐎\(horseNumber + 1)")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                )
                .scaleEffect(isWinner ? 1.2 : 1.0)
                .shadow(color: isWinner ? .green.opacity(0.8) : .clear, radius: 15)
            
            Text("#\(horseNumber + 1)")
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
        }
        .offset(x: position - 150, y: 0)
        .animation(.easeInOut(duration: 0.3), value: position)
    }
}

// MARK: - 🏁 Shadow Race View
struct ShadowRaceGameView: View {
    @StateObject private var viewModel: RaceViewModel
    let storage: AppStorage
    @Environment(\.dismiss) private var dismiss
    
    init(storage: AppStorage) {
        self.storage = storage
        _viewModel = StateObject(wrappedValue: RaceViewModel(storage: storage))
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    HStack {
                        Spacer()
                        Text("🏁 SHADOW RACE")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundColor(.white)
                    }
                    
                    // Balance & Pot
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BALANCE").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.balance).formatted())").font(.title2.weight(.semibold)).foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("POT").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.session.currentPot).formatted())").font(.title2.weight(.semibold)).foregroundColor(.yellow)
                        }
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    
                    // Race Track
                    VStack(spacing: 20) {
                        Text("RACE 30s").font(.headline).foregroundColor(.white)
                        
                        // Трек гонки
                        ZStack {
                            // Дорожка
                            Rectangle()
                                .fill(LinearGradient(colors: [.gray.opacity(0.3), .black], startPoint: .leading, endPoint: .trailing))
                                .frame(height: 120)
                                .cornerRadius(20)
                                .overlay(
                                    HStack {
                                        Text("START").foregroundColor(.white.opacity(0.6))
                                        Spacer()
                                        Text("FINISH").foregroundColor(.green)
                                    }
                                    .padding(.horizontal)
                                )
                            
                            // Лошади
                            HStack(spacing: 0) {
                                ForEach(0..<3, id: \.self) { i in
                                    HorseView(
                                        horseNumber: i,
                                        position: viewModel.horsePositions[i],
                                        isAnimating: viewModel.isAnimating,
                                        isWinner: viewModel.session.yourResult == i + 1
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(20)
                        
                        if viewModel.session.yourResult > 0 {
                            Text("🐎 #\(viewModel.session.yourResult) WINS!")
                                .font(.title2.weight(.heavy))
                                .foregroundColor(viewModel.session.gameResult == .youWin ? .green : .orange)
                        }
                    }
                    
                    // Bot Guess
                    VStack {
                        Text("BOT GUESSES").font(.headline).foregroundColor(.orange)
                        Text(viewModel.session.botGuess.rawValue)
                            .font(.title2.weight(.heavy))
                            .foregroundStyle(.yellow)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                    }
                    .padding()
                    .background(Color.gray.opacity(0.25))
                    .cornerRadius(20)
                    
                    // ✅ Guess Buttons - ТОЛЬКО после ставки!
                    if !viewModel.showResult {
                        if viewModel.session.currentPot > 0 {
                            // ✅ Кнопки активны после RACE $25
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                                ForEach(Horse.allCases, id: \.self) { horse in
                                    Button(action: {
                                        viewModel.makeGuess(horse)
                                    }) {
                                        VStack(spacing: 10) {
                                            Circle()
                                                .fill(horse == .horse1 ? .blue :
                                                      horse == .horse2 ? .green : .orange)
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Text(horse.rawValue.prefix(3))
                                                        .font(.title2.weight(.bold))
                                                        .foregroundColor(.white)
                                                )
                                            
                                            Text(horse.rawValue)
                                                .font(.headline.weight(.semibold))
                                                .foregroundColor(.white)
                                            
                                            Text("x10")
                                                .font(.title3.weight(.heavy))
                                                .foregroundColor(.yellow)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(20)
                                        .background(
                                            horse == viewModel.session.yourGuess ?
                                            Color.yellow.opacity(0.3) :
                                            Color.gray.opacity(0.3)
                                        )
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    horse == viewModel.session.yourGuess ? Color.yellow : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                }
                            }
                        } else {
                            // ✅ Сообщение до ставки
                            VStack(spacing: 15) {
                                Text("Place bet first!")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 100)
                                    .cornerRadius(20)
                            }
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        if viewModel.showResult {
                            Text(viewModel.session.gameResult.rawValue)
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundColor(viewModel.session.gameResult == .youWin ? .green : .red)
                                .scaleEffect(1.1)
                                .animation(.easeInOut(duration: 0.4).repeatCount(3), value: viewModel.session.gameResult)
                            
                            Button("NEW RACE") {
                                viewModel.newGame()
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Color.green)
                            .cornerRadius(25)
                            .shadow(color: .green.opacity(0.4), radius: 10)
                        } else {
                            Button("RACE $25 →") {
                                viewModel.placeBet()
                            }
                            .font(.title2.weight(.bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(25)
                            .shadow(color: .yellow.opacity(0.5), radius: 15)
                            .disabled(viewModel.balance < 25 || viewModel.session.currentPot > 0 || viewModel.showResult)
                        }
                    }
                    
                    // Bot Messages
                    Group {
                        if viewModel.isTyping {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle().fill(.gray.opacity(0.7))
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(0.6 + Double(i) * 0.25)
                                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: UUID())
                                }
                            }
                        } else {
                            Text(viewModel.botMessage)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(height: 40)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}


struct ShadowDiceGameView: View {
    @StateObject private var viewModel: DiceViewModel
    let storage: AppStorage
    @Environment(\.dismiss) private var dismiss
    
    init(storage: AppStorage) {
        self.storage = storage
        _viewModel = StateObject(wrappedValue: DiceViewModel(storage: storage))
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .purple.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // Header
                    HStack {
                        Spacer()
                        Text("🎲 SHADOW DICE")
                            .font(.largeTitle.weight(.heavy))
                            .foregroundColor(.white)
                    }
                    
                    // Balance & Pot
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("BALANCE").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.balance).formatted())").font(.title2.weight(.semibold)).foregroundColor(.green)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("POT").font(.caption).foregroundColor(.white.opacity(0.6))
                            Text("$\(Int(viewModel.session.currentPot).formatted())").font(.title2.weight(.semibold)).foregroundColor(.yellow)
                        }
                    }
                    .padding(20)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(20)
                    
                    // Game Area
                    VStack(spacing: 20) {
                        // Your Roll
                        VStack {
                            Text("YOUR ROLL").font(.headline).foregroundColor(.white)
                            
                            if viewModel.session.yourRoll > 0 {
                                let die1 = viewModel.session.yourRoll / 2 + (viewModel.session.yourRoll % 2)
                                let die2 = viewModel.session.yourRoll / 2
                                
                                HStack(spacing: 15) {
                                    DiceFace(number: die1, isAnimating: viewModel.isAnimating)
                                    DiceFace(number: die2, isAnimating: viewModel.isAnimating)
                                }
                                Text("\(viewModel.session.yourRoll)")
                                    .font(.title2.weight(.heavy))
                                    .foregroundColor(viewModel.session.gameResult == .youWin ? .green : .red)
                            } else {
                                HStack(spacing: 15) {
                                    DiceFace(number: 0, isAnimating: false)
                                    DiceFace(number: 0, isAnimating: false)
                                }.opacity(0.3)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(20)
                        
                        // Bot Guess
                        VStack {
                            Text("BOT GUESSES").font(.headline).foregroundColor(.orange)
                            Text(viewModel.session.botGuess.rawValue)
                                .font(.title2.weight(.heavy))
                                .foregroundStyle(.yellow)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 24)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(20)
                    }
                    
                    // ✅ Guess Buttons - ТОЛЬКО после ставки!
                    if !viewModel.showResult {
                        if viewModel.session.currentPot > 0 {
                            // ✅ Кнопки активны после PLAY $25
                            HStack(spacing: 20) {
                                ForEach(DiceGuess.allCases, id: \.self) { guess in
                                    Button(action: {
                                        viewModel.makeGuess(guess)
                                    }) {
                                        VStack(spacing: 8) {
                                            Text(guess.rawValue).font(.headline.weight(.semibold)).foregroundColor(.white)
                                            Text("x10").font(.title3.weight(.heavy)).foregroundColor(.yellow)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(20)
                                        .background(
                                            guess == viewModel.session.yourGuess ?
                                            Color.yellow.opacity(0.3) :
                                                Color.gray.opacity(0.3)
                                        )
                                        .cornerRadius(20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(
                                                    guess == viewModel.session.yourGuess ? Color.yellow : Color.clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                }
                            }
                        } else {
                            // ✅ Сообщение до ставки
                            VStack(spacing: 15) {
                                Text("Place bet first!")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 60)
                                    .cornerRadius(20)
                            }
                            .frame(height: 100)
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 15) {
                        if viewModel.showResult {
                            Text(viewModel.session.gameResult.rawValue)
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundColor(viewModel.session.gameResult == .youWin ? .green : .red)
                                .scaleEffect(1.1)
                                .animation(.easeInOut(duration: 0.4).repeatCount(3), value: viewModel.session.gameResult)
                            
                            Button("NEW GAME") {
                                viewModel.newGame()
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Color.green)
                            .cornerRadius(25)
                            .shadow(color: .green.opacity(0.4), radius: 10)
                        } else {
                            Button("PLAY $25 →") {
                                viewModel.placeBet()
                            }
                            .font(.title2.weight(.bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(25)
                            .shadow(color: .yellow.opacity(0.5), radius: 15)
                            .disabled(viewModel.balance < 25 || viewModel.session.currentPot > 0 || viewModel.showResult)
                        }
                    }
                    
                    // Bot Messages
                    Group {
                        if viewModel.isTyping {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle().fill(.gray.opacity(0.7))
                                        .frame(width: 8, height: 8)
                                        .scaleEffect(0.6 + Double(i) * 0.25)
                                        .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: UUID())
                                }
                            }
                        } else {
                            Text(viewModel.botMessage)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .frame(height: 40)
                    
                    Spacer()
                }
                .padding()
            }
        }
    }
}


struct GameDetailView: View {
    let mode: GameMode
    let storage: AppStorage
    
    var body: some View {
        Group {
            switch mode {
            case .dice:
                ShadowDiceGameView(storage: storage)
            case .roulette:
                ShadowRouletteGameView(storage: storage)
            case .cards:
                ShadowCardsGameView(storage: storage)
            case .coins:
                ShadowCoinsGameView(storage: storage)
            case .race:
                ShadowRaceGameView(storage: storage)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ContentView: View {
    @StateObject private var storage = AppStorage()
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.gray.opacity(0.7),
                        Color.purple.opacity(0.5)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        balanceHeader
                        gamesGrid
                        statsFooter
                    }
                    .padding()
                }
            }
            .navigationViewStyle(.stack)
        }
    }
    
    // ✅ Balance Header
    private var balanceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("BALANCE")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text("$\(Int(storage.appState.balance).formatted())")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.green)
                    .shadow(color: .green.opacity(0.5), radius: 10)
            }
            
            Spacer()
            
            NavigationLink(destination: HistoryView(storage: storage)) {
                Image(systemName: "clock.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }
            
            NavigationLink(destination: SettingsView(storage: storage)) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal)
    }
    
    // ✅ Games Grid - ТЕПЕРЬ РАБОТАЕТ!
    private var gamesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 2), spacing: 20) {
            ForEach(GameMode.allCases, id: \.self) { mode in
                NavigationLink(destination: GameDetailView(mode: mode, storage: storage)) {
                    GameCard(mode: mode)
                }
            }
        }
    }
    
    // ✅ Stats Footer
    private var statsFooter: some View {
        HStack {
            VStack {
                Text("\(storage.appState.gameHistory.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("GAMES")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            VStack {
                Text("\(winRate, specifier: "%.0f")%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                Text("WINRATE")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(Color.black.opacity(0.4))
        .cornerRadius(20)
    }
    
    private var winRate: Double {
        let wins = storage.appState.gameHistory.filter { $0.result == .win }.count
        return storage.appState.gameHistory.isEmpty ? 0 : Double(wins) / Double(storage.appState.gameHistory.count) * 100
    }
}

// MARK: - Game Card Component
struct GameCard: View {
    let mode: GameMode
    
    var body: some View {
        VStack(spacing: 15) {
            // Icon
            gameIcon
                .font(.system(size: 50))
                .frame(width: 80, height: 80)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: .white.opacity(0.2), radius: 20)
            
            // Title
            Text(mode.rawValue)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Multiplier
            Text("x10")
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(.yellow)
                .shadow(color: .yellow.opacity(0.5), radius: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: 200)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 25)
                        .stroke(LinearGradient(colors: [.clear, .yellow.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                )
                .shadow(color: .purple.opacity(0.4), radius: 15, x: 0, y: 10)
        )
        .scaleEffect(0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: mode)
    }
    
    @ViewBuilder
    private var gameIcon: some View {
        switch mode {
        case .dice: Image(systemName: "dice")
        case .roulette: Image(systemName: "circle.grid.cross.fill")
        case .cards: Image(systemName: "rectangle.portrait.fill")
        case .coins: Image(systemName: "circle")
        case .race: Image(systemName: "flag.checkered")
        }
    }
}

struct HistoryView: View {
    let storage: AppStorage
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            NavigationLink("", destination: ContentView())
                .navigationTitle("Game History")
                .navigationBarTitleDisplayMode(.inline)
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(storage.appState.gameHistory) { record in
                        HistoryRow(record: record)
                    }
                    
                    if storage.appState.gameHistory.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("No games yet")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .padding()
            }
        }
        .foregroundColor(.white)
    }
}

struct HistoryRow: View {
    let record: GameRecord
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.gameMode.rawValue)
                    .font(.headline)
                Text(record.date, style: .time)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.result.rawValue)
                    .fontWeight(.semibold)
                    .foregroundColor(record.result == .win ? .green : .red)
                Text("$\(Int(record.potWon).formatted())")
                    .font(.headline)
                    .foregroundColor(.yellow)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(15)
    }
}

struct SettingsView: View {
    @ObservedObject var storage: AppStorage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.black, .gray.opacity(0.7), .purple.opacity(0.5)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Header
                HStack {
                    Spacer()
                    
                    Text("SETTINGS")
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 25) {
                    // Sound Toggle ✅ РАБОТАЕТ!
                    Toggle("Sound Effects", isOn: Binding(
                        get: { storage.appState.soundEnabled },
                        set: { storage.appState.soundEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .yellow))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                    
                    // Haptics Toggle ✅ РАБОТАЕТ!
                    Toggle("Haptic Feedback", isOn: Binding(
                        get: { storage.appState.hapticsEnabled },
                        set: { storage.appState.hapticsEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                    
                    // Reset Stats
                    Button("Reset Stats") {
                        storage.appState.balance = 1000
                        storage.appState.gameHistory = []
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(15)
                }
                .padding()
                .background(Color.black.opacity(0.4))
                .cornerRadius(25)
                .shadow(color: .purple.opacity(0.5), radius: 20)
                
                Spacer()
                
                // Stats Info
                VStack(spacing: 10) {
                    Text("Sound: \(storage.appState.soundEnabled ? "ON" : "OFF")")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text("Haptics: \(storage.appState.hapticsEnabled ? "ON" : "OFF")")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("Bot: \(storage.appState.selectedBot)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(15)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(15)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
