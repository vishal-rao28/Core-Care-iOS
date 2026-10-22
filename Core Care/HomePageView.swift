//
//  HomePageView.swift
//  Core Care
//
//  Enhanced Dashboard with Mood & Wellness Integration
//

import SwiftUI

// MARK: - Enums & Models

enum HomePageSection: CaseIterable {
    case home, userDetails, hrCheck, weight, bp, ai, history, moodWellness
}

// MARK: - Response Models

struct HeartRateResponse: Codable {
    let status: String
    let bpm: Int
    let timestamp: String?
}

struct WeightResponse: Codable {
    let status: String
    let message: String?
    let data: WeightData
}

struct WeightData: Codable {
    let user_id: Int
    let weight: Double
    let height: Double
    let bmi: Double
    let category: String
}

struct BloodPressureResponse: Codable {
    let status: String
    let message: String?
    let data: BPData
}

struct BPData: Codable {
    let user_id: Int
    let bpm: Int
    let systolic: Int
    let diastolic: Int
    let category: String
    let recorded_at: String
}

// MARK: - NEW: Mood & Wellness Response Models

struct MoodWellnessResponse: Codable {
    let status: String
    let mood: String?
    let symptoms: [String]
    let heart_rate: Int
    let context_note: String?
    let timestamp: String?
    let message: String?
}

// MARK: - Health Data Manager (stub — HealthKit removed for free-tier compatibility)

class HealthDataManager: ObservableObject {
    @Published var todayStepCount: Int = 0
    @Published var lastSleepHours: Double = 0

    func fetchTodaySteps() { /* HealthKit not available on free developer account */ }
    func fetchRecentSleep() { /* HealthKit not available on free developer account */ }
}

// MARK: - Main View

struct HomePageView: View {
    let userId: Int
    @EnvironmentObject var userManager: UserManager
    @State private var selectedTab: Int = 0
    @State private var selectedAvatar: String = ""
    @State private var currentPage: HomePageSection = .home

    init(userId: Int = 1) {
        self.userId = userId
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    @State private var latestBPM: String = "--"
    @State private var bpmCategory: String = "Rate: --"
    @State private var weight: String = "--"
    @State private var height: Double = 170.0 // Default height in cm
    @State private var bmiCategory: String = "BMI: --"
    @State private var systolic: String = "--"
    @State private var diastolic: String = "--"
    @State private var bpCategory: String = "BP: --"

    // UPDATED: Mood & Wellness State Variables
    @State private var currentMood: String = "😐 Neutral"
    @State private var moodWellnessStatus: String = "Status: --"
    @State private var lastMoodEntry: String = "No entries"
    @State private var moodEmoji: String = "😐"
    @State private var moodColor: Color = Color.blue

    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var fetchedUserName: String = ""
    @State private var scrollOffset: CGFloat = 0

    @StateObject private var healthManager = HealthDataManager()

    // Get user data from UserManager with proper validation
    private var currentUserId: Int {
        let managerId = userManager.currentUserId
        print("HomePageView - UserManager ID: \(managerId ?? -1), Passed ID: \(userId)")
        if let managerId = managerId, managerId > 0 {
            return managerId
        } else if userId > 0 {
            return userId
        } else {
            print("WARNING: No valid user ID available!")
            return 0
        }
    }

    private var userName: String {
        if !fetchedUserName.isEmpty {
            return fetchedUserName
        }
        return "User"
    }

    // MARK: - Adaptive colour tokens (auto light/dark via ThemeColors.swift)
    private let primaryColor    = Color.appBackground
    private let secondaryColor  = Color.appBackground2
    private let accentColor     = Color.appAccent
    private let surfaceColor    = Color.cardBackground
    private let textPrimary     = Color.textPrimary
    private let textSecondary   = Color.textSecondary
    private let heroGradient    = LinearGradient.appHero
    private let aiGradient      = LinearGradient.appAI

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if currentPage == .home {
                    TabView(selection: $selectedTab) {
                        ZStack {
                            Color.appBackground2
                                .ignoresSafeArea()

                            homeContentView(geo: geo)
                        }
                        .ignoresSafeArea()
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(0)

                        HistoryView()
                            .environmentObject(userManager)
                            .tabItem {
                                Label("History", systemImage: "clock.fill")
                            }
                            .tag(1)

                        UserDetailsView(userId: currentUserId)
                            .environmentObject(userManager)
                            .tabItem {
                                Label("Profile", systemImage: "person.fill")
                            }
                            .tag(2)
                    }
                    .tint(Color.appAccent)
                } else {
                    secondaryContentView(geo: geo)
                }

                if isLoading {
                    LoadingOverlay()
                }
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            validateUserSession()
            loadAllHealthMetrics()
            refreshUserName()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserAvatarChanged"))) { notification in
            if let avatar = notification.userInfo?["avatar"] as? String {
                self.selectedAvatar = avatar
                print("HomePageView: Avatar updated to \(avatar)")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MoodEntryAdded"))) { _ in
            loadLatestMoodEntry()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WeightUpdated"))) { _ in
            loadLatestWeight()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private func secondaryContentView(geo: GeometryProxy) -> some View {
        switch currentPage {
        case .home, .history, .userDetails:
            EmptyView()

        case .hrCheck:
            HRCheckView()
                .environmentObject(userManager)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )

        case .weight:
            WeightView(onDismiss: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentPage = .home
                }
            })
                .environmentObject(userManager)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )

        case .bp:
            BPView()
                .environmentObject(userManager)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )

        case .ai:
            AIView()
                .environmentObject(userManager)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )

        case .moodWellness:
            BloodSugarView()
                .environmentObject(userManager)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
        }
    }

    // MARK: - User Session Validation
    private func validateUserSession() {
        print("Validating user session...")
        print("UserManager isLoggedIn: \(userManager.isLoggedIn)")
        print("UserManager userData: \(userManager.userData?.user_id ?? -1)")
        print("Passed userId: \(userId)")
        print("Computed currentUserId: \(currentUserId)")

        if currentUserId == 0 {
            showError = true
            errorMessage = "Invalid user session. Please log in again."
        }
    }

    // MARK: - Enhanced Home Content View
    @ViewBuilder
    private func homeContentView(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            headerView(geo: geo)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        welcomeHeroSection(geo: geo)
                            .id("hero")
                        quickCheckSection(geo: geo)
                            .id("quickcheck")
                        healthMetricsGrid(geo: geo)
                            .id("metrics")
                        aiAssistantSection(geo: geo)
                            .id("ai")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 110 + geo.safeAreaInsets.bottom)
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geometry.frame(in: .named("scroll")).minY
                        )
                    }
                )
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
                .coordinateSpace(name: "scroll")
            }
        }
    }

    // MARK: - Enhanced Header with Dynamic Effects and Avatar Support
    private func headerView(geo: GeometryProxy) -> some View {
        let headerOpacity = min(1.0, max(0.3, 1.0 - (scrollOffset / -100)))
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(textSecondary)
                    .opacity(headerOpacity)
                Text(userName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textPrimary)
                    .scaleEffect(0.9 + (headerOpacity * 0.1), anchor: .leading)

            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    selectedTab = 2
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [accentColor, accentColor.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: accentColor.opacity(0.2), radius: 8, x: 0, y: 4)

                    // Display selected avatar or default icon
                    if !selectedAvatar.isEmpty {
                        Image(selectedAvatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 45, height: 45)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(headerOpacity)
            }
            .buttonStyle(BouncyButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, max(geo.safeAreaInsets.top, 44) + 8)
        .padding(.bottom, 20)
        .background(
            secondaryColor
                .opacity(scrollOffset < -50 ? 0.95 : 1.0)
                .blur(radius: scrollOffset < -50 ? 10 : 0)
        )
    }

    // MARK: - New Welcome Hero Section
    private func welcomeHeroSection(geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Health")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                    Text("Dashboard")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    Text("Track, monitor, and improve your wellbeing")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(24)
        .background(heroGradient)
        .cornerRadius(20)
        .shadow(color: accentColor.opacity(0.3), radius: 15, x: 0, y: 8)
    }

    // MARK: - Enhanced Quick Check Section
    private func quickCheckSection(geo: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quick Check")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(textPrimary)
                Spacer()
                Button("View All") {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        selectedTab = 1
                    }
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
            }

            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentPage = .hrCheck
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.red)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Measure Heart Rate")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(textPrimary)
                        Text("Get instant heart rate reading")
                            .font(.system(size: 14))
                            .foregroundColor(textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accentColor)
                }
                .padding(20)
                .adaptiveCard()
            }
            .buttonStyle(CardButtonStyle())
        }
    }

    // MARK: - Enhanced Health Metrics Grid
    private func healthMetricsGrid(geo: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Health Metrics")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(textPrimary)
                Spacer()
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible())
            ], spacing: 16) {
                enhancedHealthMetricCard(
                    title: "Heart Rate",
                    value: latestBPM,
                    subtitle: bpmCategory,
                    icon: "heart.fill",
                    color: Color.red,
                    gradient: LinearGradient(
                        gradient: Gradient(colors: [Color.red.opacity(0.8), Color.red]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentPage = .hrCheck
                        }
                    }
                )

                enhancedHealthMetricCard(
                    title: "Weight",
                    value: weight,
                    subtitle: bmiCategory,
                    icon: "scalemass.fill",
                    color: Color.orange,
                    gradient: LinearGradient(
                        gradient: Gradient(colors: [Color.orange.opacity(0.8), Color.orange]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentPage = .weight
                        }
                    }
                )

                enhancedHealthMetricCard(
                    title: "Blood Pressure",
                    value: "\(systolic)/\(diastolic)",
                    subtitle: bpCategory,
                    icon: "waveform.path.ecg",
                    color: Color.purple,
                    gradient: LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentPage = .bp
                        }
                    }
                )

                // UPDATED: Mood & Wellness Card with dynamic colors
                enhancedHealthMetricCard(
                    title: "Mood & Wellness",
                    value: currentMood,
                    subtitle: moodWellnessStatus,
                    icon: "brain.head.profile",
                    color: moodColor,
                    gradient: LinearGradient(
                        gradient: Gradient(colors: [moodColor.opacity(0.8), moodColor]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentPage = .moodWellness
                        }
                    }
                )
            }
        }
    }

    // MARK: - Enhanced Health Metric Card
    private func enhancedHealthMetricCard(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        color: Color,
        gradient: LinearGradient,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(color)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textSecondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: title == "Mood & Wellness" ? 16 : 20, weight: .bold))
                        .foregroundColor(textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textSecondary)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.1))
                        .cornerRadius(8)
                }
                Spacer()
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .glossyCard(cornerRadius: 18, borderTint: color.opacity(0.5))
        }
        .buttonStyle(CardButtonStyle())
    }




    // MARK: - Enhanced AI Assistant Section
    private func aiAssistantSection(geo: GeometryProxy) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("AI Assistant")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(textPrimary)
                Spacer()
            }

            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentPage = .ai
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 50, height: 50)
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Core Care Assistant")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Get personalized health insights")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(20)
                .background(aiGradient)
                .cornerRadius(18)
                .shadow(color: Color.statusSuccess.opacity(0.3), radius: 15, x: 0, y: 8)
            }
            .buttonStyle(CardButtonStyle())
        }
    }



    // MARK: - Refresh Functions
    func refreshUserName() {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/user.php?user_id=\(currentUserId)") else {
            print("Invalid userId or URL for refreshing user name")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print("Error refreshing user name: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                do {
                    let response = try JSONDecoder().decode(ServerUserResponse.self, from: data)
                    if response.status == "success", let user = response.data {
                        self.fetchedUserName = user.name ?? "User"
                        self.selectedAvatar = user.profile_picture ?? ""
                        print("User name refreshed: \(self.fetchedUserName)")
                        print("Avatar loaded: \(self.selectedAvatar)")
                    }
                } catch {
                    print("Error parsing user data for name refresh: \(error)")
                }
            }
        }.resume()
    }

    func loadAllHealthMetrics() {
        loadLatestHeartRate()
        loadLatestBloodPressure()
        loadLatestWeight()
        loadLatestMoodEntry() // UPDATED: Load mood data from API
    }

    // MARK: - Load Latest Heart Rate
    func loadLatestHeartRate() {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/heartbeat.php?user_id=\(currentUserId)&type=latest") else {
            print("Invalid userId or URL for heartbeat")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print("Error loading heartbeat: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                if let result = try? JSONDecoder().decode(HeartRateResponse.self, from: data),
                   result.status.lowercased() == "success" {
                    self.latestBPM = "\(result.bpm) BPM"

                    let category: String
                    if result.bpm < 60 {
                        category = "Low"
                    } else if result.bpm <= 100 {
                        category = "Normal"
                    } else {
                        category = "High"
                    }
                    self.bpmCategory = "Rate: \(category)"
                    print("Latest heart rate loaded: \(result.bpm) BPM")
                }
            }
        }.resume()
    }

    // MARK: - Load Latest Blood Pressure
    func loadLatestBloodPressure() {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/bp.php?user_id=\(currentUserId)&type=latest") else {
            print("Invalid userId or URL for blood pressure")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print("Error loading latest blood pressure: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String,
                   status.lowercased() == "success",
                   let bpData = json["data"] as? [String: Any],
                   let systolic = bpData["systolic"] as? Int,
                   let diastolic = bpData["diastolic"] as? Int,
                   let category = bpData["category"] as? String {
                    self.systolic = "\(systolic)"
                    self.diastolic = "\(diastolic)"
                    self.bpCategory = category
                    print("Latest BP loaded: \(systolic)/\(diastolic) - \(category)")
                } else {
                    print("No latest blood pressure data found or failed to parse")
                    self.systolic = "--"
                    self.diastolic = "--"
                    self.bpCategory = "BP: No Data"
                }
            }
        }.resume()
    }

    // MARK: - Load Latest Weight
    func loadLatestWeight() {
        if let savedWeight = UserDefaults.standard.string(forKey: "saved_weight_\(currentUserId)") ?? UserDefaults.standard.string(forKey: "saved_weight"), !savedWeight.isEmpty {
            if let wVal = Double(savedWeight) {
                self.weight = "\(Int(wVal)) KGS"
            } else {
                self.weight = "\(savedWeight) KGS"
            }
            if let savedCat = UserDefaults.standard.string(forKey: "saved_bmi_category_\(currentUserId)") ?? UserDefaults.standard.string(forKey: "saved_bmi_category") {
                self.bmiCategory = "BMI: \(savedCat)"
            }
        }
        
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/weight.php?user_id=\(currentUserId)") else {
            print("Invalid userId or URL for weight")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print("Error loading weight: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String,
                   status.lowercased() == "success",
                   let weightData = json["data"] as? [String: Any],
                   let weight = weightData["weight"] as? Double,
                   let bmiCategory = weightData["bmi_category"] as? String {
                    self.weight = "\(Int(weight)) KGS"
                    self.bmiCategory = "BMI: \(bmiCategory)"
                    print("Latest weight loaded: \(weight) kg - \(bmiCategory)")
                } else {
                    print("No weight data found or failed to parse")
                }
            }
        }.resume()
    }

    // MARK: - NEW: Load Latest Mood Entry from API
    func loadLatestMoodEntry() {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/mood_wellness.php?user_id=\(currentUserId)&type=latest") else {
            print("Invalid userId or URL for mood wellness")
            return
        }

        print("Loading latest mood entry for user \(currentUserId)")
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print("Error loading mood wellness: \(error?.localizedDescription ?? "Unknown")")
                    self.setDefaultMoodValues()
                    return
                }

                do {
                    let result = try JSONDecoder().decode(MoodWellnessResponse.self, from: data)
                    if result.status.lowercased() == "success" {
                        // Parse mood data from API response
                        let moodText = result.mood ?? "Neutral"
                        let symptoms = result.symptoms
                        _ = result.heart_rate
                        let timestamp = result.timestamp
                        
                        // Set mood emoji and color based on mood text
                        let (emoji, color) = self.getMoodEmojiAndColor(for: moodText)
                        self.moodEmoji = emoji
                        self.moodColor = color
                        self.currentMood = "\(emoji) \(moodText)"
                        
                        // Create status message based on symptoms
                        let symptomCount = symptoms.count
                        if symptomCount == 0 {
                            self.moodWellnessStatus = "No symptoms"
                        } else if symptomCount == 1 {
                            self.moodWellnessStatus = "1 symptom"
                        } else {
                            self.moodWellnessStatus = "\(symptomCount) symptoms"
                        }
                        
                        // Format last entry time
                        if let timestamp = timestamp {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                            if let date = formatter.date(from: timestamp) {
                                formatter.dateStyle = .short
                                formatter.timeStyle = .short
                                self.lastMoodEntry = "Last: \(formatter.string(from: date))"
                            } else {
                                self.lastMoodEntry = "Last: \(timestamp)"
                            }
                        } else {
                            self.lastMoodEntry = "Recent entry"
                        }
                        
                        print("Latest mood entry loaded: \(moodText) - \(symptomCount) symptoms")
                        
                    } else {
                        print("API returned error: \(result.message ?? "Unknown error")")
                        self.setDefaultMoodValues()
                    }
                } catch {
                    print("Error decoding mood wellness response: \(error)")
                    self.setDefaultMoodValues()
                }
            }
        }.resume()
    }
    
    // Helper function to set default mood values
    private func setDefaultMoodValues() {
        self.currentMood = "😐 Neutral"
        self.moodEmoji = "😐"
        self.moodColor = Color.blue
        self.moodWellnessStatus = "No entries yet"
        self.lastMoodEntry = "Start tracking!"
        print("Set default mood values for user \(self.currentUserId)")
    }
    
    // Helper function to get emoji and color for mood
    private func getMoodEmojiAndColor(for mood: String) -> (String, Color) {
        switch mood.lowercased() {
        case "very happy":
            return ("😄", Color.green)
        case "happy":
            return ("😊", Color.green.opacity(0.8))
        case "neutral":
            return ("😐", Color.blue)
        case "sad":
            return ("😔", Color.orange)
        case "very sad":
            return ("😢", Color.red.opacity(0.8))
        case "anxious":
            return ("😰", Color.yellow)
        case "stressed":
            return ("😤", Color.red)
        default:
            return ("😐", Color.blue)
        }
    }

    // MARK: - Send Data Functions (keeping all original functionality)
    func sendHeartbeat(bpm: Int) {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/heartbeat.php") else {
            print("Invalid user ID or URL for heartbeat")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_id": currentUserId, "bpm": bpm]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("Sending heartbeat data for user \(currentUserId): \(bpm) BPM")
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("Error sending heartbeat: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            if let result = try? JSONDecoder().decode(HeartRateResponse.self, from: data),
               result.status.lowercased() == "success" {
                DispatchQueue.main.async {
                    self.loadLatestHeartRate()
                    print("Heartbeat data saved successfully")
                }
            } else {
                print("Failed to save heartbeat data")
            }
        }.resume()
    }

    func sendWeight(weight: Double, height: Double) {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/weight.php") else {
            print("Invalid user ID or URL for weight")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_id": currentUserId,
            "weight": weight,
            "height": height
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("Sending weight data for user \(currentUserId): \(weight) kg, height: \(height) cm")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print("Error sending weight: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                if let result = try? JSONDecoder().decode(WeightResponse.self, from: data),
                   result.status.lowercased() == "success" {
                    self.loadLatestWeight()
                    self.height = result.data.height
                    print("Weight data saved successfully")
                } else {
                    print("Failed to save weight data")
                }
            }
        }.resume()
    }

    func sendBloodPressureFromBPM(bpm: Int) {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/bp.php") else {
            print("Invalid user ID or URL for blood pressure")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["user_id": currentUserId, "bpm": bpm]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("Sending BP calculation from BPM for user \(currentUserId): \(bpm) BPM")
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    print("Error sending BP: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                if let result = try? JSONDecoder().decode(BloodPressureResponse.self, from: data),
                   result.status.lowercased() == "success" {
                    self.loadLatestBloodPressure()
                    print("BP data calculated and saved successfully")
                } else {
                    print("Failed to save BP data")
                }
            }
        }.resume()
    }
}

// MARK: - Enhanced Supporting Views

struct EnhancedBottomNavItem: View {
    var systemName: String
    var label: String
    var isActive: Bool

    private let activeColor = Color(red: 0.0, green: 0.48, blue: 1.0) // Apple System Blue
    private let inactiveColor = Color(red: 0.55, green: 0.58, blue: 0.65) // Apple Secondary Label

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? activeColor : inactiveColor)
                .scaleEffect(isActive ? 1.06 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isActive)

            Text(label)
                .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? activeColor : inactiveColor)
                .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .contentShape(Rectangle())
    }
}

// MARK: - Custom Button Styles

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Enhanced Visual Effect View

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: effect)
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = effect
    }
}

// MARK: - Enhanced Loading Overlay

struct LoadingOverlay: View {
    @State private var rotationAngle: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.appAccent.opacity(0.3), lineWidth: 4)
                        .frame(width: 50, height: 50)

                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotationAngle)
                }

                Text("Loading...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.textPrimary)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.cardShadow, radius: 20, x: 0, y: 10)
            )
        }
        .onAppear {
            rotationAngle = 360
        }
    }
}

// MARK: - Server Response Models with Avatar Support

struct ServerUserResponse: Codable {
    let status: String
    let data: ServerUserData?
    let message: String?
}

struct ServerUserData: Codable {
    let name: String?
    let age: Int?
    let sex: String?
    let height: String?
    let phone: String?
    let email: String?
    let profile_picture: String? // Avatar field
}

// Keeping original BottomNavBarItem for backward compatibility
struct BottomNavBarItem: View {
    var systemName: String
    var label: String
    var geo: GeometryProxy
    var isActive: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: isActive ? 22 : 20, weight: isActive ? .bold : .medium))
                .foregroundColor(isActive ? Color(red: 0.33, green: 0.42, blue: 0.95) : Color.gray)

            Text(label)
                .font(.system(size: 12, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? Color(red: 0.33, green: 0.42, blue: 0.95) : Color.gray)
        }
        .frame(width: 60)
        .padding(.vertical, 15)
        .background(isActive ? Color(red: 0.33, green: 0.42, blue: 0.95).opacity(0.1) : Color.clear)
        .cornerRadius(12)
    }
}

// MARK: - Preview

struct HomePageView_Previews: PreviewProvider {
    static var previews: some View {
        HomePageView(userId: 1)
            .environmentObject(UserManager.shared)
    }
}
