import SwiftUI
import Charts
import PDFKit
import UniformTypeIdentifiers

// MARK: - Data Models
struct WeeklyReportResponse: Codable {
    let status: String
    let weekly_summary: WeeklySummary
    let daily_readings: [DailyReading]?
}

struct WeeklySummary: Codable {
    let avg_bpm: Double
    let min_bpm: Int
    let max_bpm: Int
    let avg_bp_systolic: Int
    let avg_bp_diastolic: Int
    let avg_hrv: Double?
    let resting_heart_rate: Double?
    let recovery_heart_rate: Double?
}

struct DailyReading: Codable {
    let date: String
    let avg_bpm: Double
    let avg_systolic: Int
    let avg_diastolic: Int
    let measurement_count: Int
    let hrv: Double?
}

struct CardiacRiskAssessmentResponse: Codable {
    let status: String
    let risk_score: Int
    let risk_level: String
    let factors: [String]
    let recommendations: [String]
    let hrv: Double?
}

struct CardiacRiskAssessment: Codable {
    let risk_score: Int
    let risk_level: String
    let factors: [String]
    let recommendations: [String]
}

struct WeeklyReportDay: Identifiable {
    var id = UUID()
    var date: String
    var avg_bpm: Double
    var avg_bp: String
}

struct ExportData: Codable {
    let summary: WeeklySummary?
    let dailyReadings: [DailyReading]
    let riskAssessment: CardiacRiskAssessment?
    let exportDate: Date
}

// MARK: - Color Constants (adaptive — auto light/dark via ThemeColors.swift)
struct AppColors {
    static let primaryColor       = Color.textPrimary
    static let secondaryColor     = Color.appBackground2
    static let accentColor        = Color.appAccent
    static let surfaceColor       = Color.cardBackground
    static let textPrimary        = Color.textPrimary
    static let textSecondary      = Color.textSecondary
    static let shadowColor        = Color.cardShadow
    static let cardBackgroundColor = Color.cardBackground

    static let heroGradient = LinearGradient.appHero

    static var cardGradient: LinearGradient {
        LinearGradient.glossyCardSurface
    }
}

// MARK: - Enhanced History View with Premium Design
struct HistoryView: View {
    @EnvironmentObject var userManager: UserManager
    
    @State private var weeklyData: [WeeklyReportDay] = []
    @State private var dailyReadings: [DailyReading] = []
    @State private var weeklySummary: WeeklySummary?
    @State private var riskAssessment: CardiacRiskAssessment?
    @State private var selectedTimeFrame: TimeFrame = .weekly
    @State private var currentPage: HomePageSection = .history
    @State private var showDetailedReport = false
    @State private var showExportSheet = false
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var scrollOffset: CGFloat = 0
    
    // Premium animation states - initialized to true for instant presentation without loading delays
    @State private var headerAnimated = true
    @State private var riskCardAnimated = true
    @State private var reportButtonAnimated = true
    @State private var timeFrameAnimated = true
    @State private var contentAnimated = true
    @State private var metricsAnimated = true
    @State private var chartsAnimated = true
    
    private var currentUserId: Int {
        let managerId = userManager.currentUserId
        if let managerId = managerId, managerId > 0 {
            return managerId
        } else {
            return 0
        }
    }
    
    enum TimeFrame: String, CaseIterable {
        case daily = "Today"
        case weekly = "This Week"
        case monthly = "This Month"
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Premium Background with Depth
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.98, green: 0.99, blue: 1.0),
                        Color(red: 0.96, green: 0.97, blue: 1.0),
                        AppColors.secondaryColor
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Background Pattern Overlay
                PatternOverlay()
                    .opacity(0.02)
                    .ignoresSafeArea()
                
                contentView(geo: geo)
                
                if isLoading && weeklyData.isEmpty && dailyReadings.isEmpty {
                    PremiumLoadingOverlay()
                }
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            validateUserSession()
            triggerAnimations()
            if !hasLoadedOnce {
                hasLoadedOnce = true
                fetchReport(showLoader: false)
            } else {
                fetchReport(showLoader: false)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
            Button("Retry") {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    fetchReport()
                }
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func triggerAnimations() {
        headerAnimated = true
        riskCardAnimated = true
        reportButtonAnimated = true
        timeFrameAnimated = true
        contentAnimated = true
        metricsAnimated = true
        chartsAnimated = true
    }
    
    private func validateUserSession() {
        if currentUserId == 0 {
            showError = true
            errorMessage = "Invalid user session. Please log in again."
        }
    }
    
    @ViewBuilder
    private func contentView(geo: GeometryProxy) -> some View {
        switch currentPage {
        case .history:
            historyContentView(geo: geo)
        case .home:
            HomePageView(userId: currentUserId)
                .environmentObject(userManager)
                .transition(
    .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
)

        case .userDetails:
            UserDetailsView(userId: currentUserId)
                .environmentObject(userManager)
                .transition(
    .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
)

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
            WeightView()
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

        case .moodWellness: // FIXED: Changed from .bloodSugar to .moodWellness
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
    
    // MARK: - Enhanced History Content with Premium Layout
    private func historyContentView(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            premiumHeaderView(geo: geo)
            
            if isLoading && weeklyData.isEmpty && dailyReadings.isEmpty {
                LoadingContentView()
            } else if weeklyData.isEmpty && dailyReadings.isEmpty && !isLoading {
                ScrollView(.vertical, showsIndicators: false) {
                    PremiumEmptyStateView(geo: geo)
                        .frame(minHeight: geo.size.height - 200)
                }
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // Hero Statistics Section
                        HeroStatsSection()
                            .opacity(riskCardAnimated ? 1.0 : 0.0)
                            .scaleEffect(riskCardAnimated ? 1.0 : 0.95)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: riskCardAnimated)
                        
                        // Risk Assessment with Premium Design
                        if let assessment = riskAssessment {
                            PremiumRiskAssessmentSection(assessment: assessment)
                                .opacity(reportButtonAnimated ? 1.0 : 0.0)
                                .offset(y: reportButtonAnimated ? 0 : 20)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: reportButtonAnimated)
                        }
                        
                        // Action Buttons Row
                        ActionButtonsRow()
                            .opacity(timeFrameAnimated ? 1.0 : 0.0)
                            .scaleEffect(timeFrameAnimated ? 1.0 : 0.95)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: timeFrameAnimated)
                        
                        // Time Frame Selector with Premium Styling
                        PremiumTimeFrameSelector()
                            .opacity(contentAnimated ? 1.0 : 0.0)
                            .offset(y: contentAnimated ? 0 : 30)
                            .animation(.spring(response: 0.8, dampingFraction: 0.8), value: contentAnimated)
                        
                        // Content Sections
                        VStack(spacing: 24) {
                            PremiumHealthMetricsOverview(summary: weeklySummary, geo: geo)
                                .opacity(metricsAnimated ? 1.0 : 0.0)
                                .offset(y: metricsAnimated ? 0 : 30)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: metricsAnimated)
                            
                            // IMPROVED CHARTS SECTION WITH HORIZONTAL SCROLLING
                            PremiumTrendChartsSection(dailyReadings: dailyReadings, geo: geo)
                                .opacity(chartsAnimated ? 1.0 : 0.0)
                                .offset(y: chartsAnimated ? 0 : 30)
                                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: chartsAnimated)
                        }
                        .padding(.top, 16)
                        
                        // Bottom spacing for navigation
                        Color.clear.frame(height: 110 + geo.safeAreaInsets.bottom)
                    }
                }
                .refreshable {
                    await refreshData()
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
        .sheet(isPresented: $showDetailedReport) {
            DetailedReportView(summary: weeklySummary,
                               dailyReadings: dailyReadings,
                               riskAssessment: riskAssessment)
        }
        .sheet(isPresented: $showExportSheet) {
            EnhancedExportDataView(
                weeklySummary: weeklySummary,
                dailyReadings: dailyReadings,
                riskAssessment: riskAssessment
            )
            .environmentObject(userManager)
        }
    }
    
    // MARK: - Premium Header with Dynamic Effects
    private func premiumHeaderView(geo: GeometryProxy) -> some View {
        let headerOpacity = min(1.0, max(0.3, 1.0 - (scrollOffset / -100)))
        
        return VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Dashboard")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .opacity(headerOpacity)
                    
                    Text("Cardiac Analytics")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .scaleEffect(0.9 + (headerOpacity * 0.1), anchor: .leading)
                }
                
                Spacer()
                
                // Premium Export Button
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        showExportSheet = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        AppColors.accentColor.opacity(0.12),
                                        AppColors.accentColor.opacity(0.06)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .shadow(color: AppColors.accentColor.opacity(0.15), radius: 6, x: 0, y: 3)
                        
                        Circle()
                            .stroke(AppColors.accentColor.opacity(0.25), lineWidth: 1)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColors.accentColor)
                    }
                }
                .buttonStyle(PremiumButtonStyle())
                .scaleEffect(headerOpacity)
            }
            .padding(.horizontal, 20)
            .padding(.top, max(geo.safeAreaInsets.top, 44) + 8)
            .padding(.bottom, 20)
            
            // Divider with Gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    AppColors.textSecondary.opacity(0.1),
                    Color.clear
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .padding(.horizontal, 20)
        }
        .background(
            AppColors.secondaryColor
                .opacity(scrollOffset < -50 ? 0.95 : 1.0)
                .blur(radius: scrollOffset < -50 ? 10 : 0)
        )
    }
    
    // MARK: - Hero Statistics Section
    private func HeroStatsSection() -> some View {
        VStack(spacing: 0) {
            if let summary = weeklySummary {
                HStack(spacing: 20) {
                    HeroStatCard(
                        title: "Avg BPM",
                        value: "\(Int(summary.avg_bpm))",
                        subtitle: "Heart Rate",
                        color: getHeartRateColor(summary.avg_bpm),
                        icon: "heart.fill"
                    )
                    
                    HeroStatCard(
                        title: "Blood Pressure",
                        value: "\(summary.avg_bp_systolic)/\(summary.avg_bp_diastolic)",
                        subtitle: "mmHg",
                        color: getBPColor(systolic: summary.avg_bp_systolic, diastolic: summary.avg_bp_diastolic),
                        icon: "heart.text.square.fill"
                    )
                    
                    if let hrv = summary.avg_hrv {
                        HeroStatCard(
                            title: "HRV",
                            value: String(format: "%.1f", hrv),
                            subtitle: "ms",
                            color: getHRVColor(hrv),
                            icon: "waveform.path.ecg"
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .background(AppColors.surfaceColor)
    }
    
    private func HeroStatCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
            
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.1))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: AppColors.shadowColor, radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Premium Risk Assessment Section
    private func PremiumRiskAssessmentSection(assessment: CardiacRiskAssessment) -> some View {
        VStack(spacing: 0) {
            PremiumRiskAssessmentCard(assessment: assessment)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background(AppColors.surfaceColor)
    }
    
    // MARK: - Action Buttons Row
    private func ActionButtonsRow() -> some View {
        HStack(spacing: 16) {
            // Detailed Report Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showDetailedReport = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.accentColor)
                    
                    Text("Detailed Report")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accentColor)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.accentColor.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppColors.accentColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PremiumButtonStyle())
            
            // Quick Export Button
            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    showExportSheet = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color.green)
                    
                    Text("Export")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.green.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.green.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PremiumButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppColors.surfaceColor)
    }
    
    // MARK: - Premium Time Frame Selector
    private func PremiumTimeFrameSelector() -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Time Period")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            
            // Custom Segmented Control
            HStack(spacing: 0) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedTimeFrame = timeframe
                        }
                    }) {
                        Text(timeframe.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(selectedTimeFrame == timeframe ? .white : AppColors.textSecondary)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(selectedTimeFrame == timeframe ? AppColors.accentColor : Color.clear)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .onChange(of: selectedTimeFrame) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.5)) {
                    fetchReport()
                }
            }
        }
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(AppColors.surfaceColor)
                .shadow(color: AppColors.shadowColor, radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Loading Content View
    private func LoadingContentView() -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(AppColors.accentColor.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0.0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [AppColors.accentColor, AppColors.accentColor.opacity(0.3)]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isLoading)
            }
            
            VStack(spacing: 8) {
                Text("Loading cardiac insights...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Analyzing your health data")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Native iOS Bottom Navigation Tab Bar
    private func enhancedBottomNavigation(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // Native iOS hairline separator
                Rectangle()
                    .fill(Color(.separator).opacity(0.6))
                    .frame(height: 0.5)

                HStack(spacing: 0) {
                    ForEach([
                        ("house.fill", "Home", HomePageSection.home),
                        ("clock.fill", "History", HomePageSection.history),
                        ("person.fill", "Profile", HomePageSection.userDetails)
                    ], id: \.1) { icon, label, page in
                        Button {
                            if page != .history {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                    currentPage = page
                                }
                            } else {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            }
                        } label: {
                            PremiumBottomNavItem(
                                systemName: icon,
                                label: label,
                                isActive: currentPage == page
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 6)
                .padding(.bottom, max(geo.safeAreaInsets.bottom - 4, 8))
                .frame(maxWidth: .infinity)
            }
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color(.systemBackground).opacity(0.8))
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    // MARK: - Refresh Data Helper Function
    @MainActor
    private func refreshData() async {
        await withCheckedContinuation { continuation in
            fetchReport()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                continuation.resume()
            }
        }
    }
    
    // MARK: - Data Fetching Methods
    func fetchReport(showLoader: Bool = false) {
        guard currentUserId > 0 else {
            showError = true
            errorMessage = "Invalid user session"
            return
        }
        
        if showLoader && weeklyData.isEmpty && dailyReadings.isEmpty {
            isLoading = true
        }
        let endpoint: String
        
        switch selectedTimeFrame {
        case .daily:
            endpoint = "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/daily_report.php?user_id=\(currentUserId)"
        case .weekly:
            endpoint = "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/weekly_report.php?user_id=\(currentUserId)"
        case .monthly:
            endpoint = "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/monthly_report.php?user_id=\(currentUserId)"
        }
        
        guard let url = URL(string: endpoint) else {
            isLoading = false
            showError = true
            errorMessage = "Invalid URL for report"
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.showError = true
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.showError = true
                    self.errorMessage = "No data received"
                }
                return
            }
            
            do {
                let result = try JSONDecoder().decode(WeeklyReportResponse.self, from: data)
                
                if result.status != "success" {
                    DispatchQueue.main.async {
                        self.showError = true
                        self.errorMessage = "API Error: \(result.status)"
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.weeklySummary = result.weekly_summary
                    self.dailyReadings = result.daily_readings ?? []
                    self.processDataForDisplay()
                    self.fetchRiskAssessment()
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError = true
                    self.errorMessage = "Failed to parse report data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func fetchRiskAssessment() {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/risk_assessment.php?user_id=\(currentUserId)") else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Risk assessment fetch error:", error)
                return
            }
            guard let data = data else { return }
            
            do {
                if let response = try? JSONDecoder().decode(CardiacRiskAssessmentResponse.self, from: data) {
                    if response.status == "success" {
                        DispatchQueue.main.async {
                            self.riskAssessment = CardiacRiskAssessment(
                                risk_score: response.risk_score,
                                risk_level: response.risk_level,
                                factors: response.factors,
                                recommendations: response.recommendations
                                //hrv: response.hrv
                            )
                        }
                    }
                } else {
                    let assessment = try JSONDecoder().decode(CardiacRiskAssessment.self, from: data)
                    DispatchQueue.main.async {
                        self.riskAssessment = assessment
                    }
                }
            } catch {
                print("Risk assessment decoding error:", error)
            }
        }.resume()
    }
    
    func processDataForDisplay() {
        weeklyData = dailyReadings.map { reading in
            WeeklyReportDay(
                date: formatDate(reading.date),
                avg_bpm: reading.avg_bpm,
                avg_bp: "\(reading.avg_systolic)/\(reading.avg_diastolic)"
            )
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    // MARK: - Helper Functions for Colors
    private func getHeartRateColor(_ bpm: Double) -> Color {
        switch bpm {
        case 0: return .gray
        case ..<60: return .blue
        case 60...100: return .green
        default: return .red
        }
    }
    
    private func getBPColor(systolic: Int, diastolic: Int) -> Color {
        if systolic == 0 && diastolic == 0 { return .gray }
        if systolic < 120 && diastolic < 80 { return .green }
        if systolic < 130 && diastolic < 80 { return .yellow }
        if systolic < 140 || diastolic < 90 { return .orange }
        return .red
    }
    
    private func getHRVColor(_ hrv: Double) -> Color {
        switch hrv {
        case 0: return .gray
        case ..<20: return .red
        case 20...60: return .yellow
        default: return .green
        }
    }
}

// MARK: - Premium Supporting Views
struct PatternOverlay: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 30
            let dotSize: CGFloat = 2
            
            for x in stride(from: 0, to: size.width, by: spacing) {
                for y in stride(from: 0, to: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.gray.opacity(0.3)))
                }
            }
        }
    }
}

struct PremiumLoadingOverlay: View {
    @State private var rotationAngle: Double = 0
    @State private var scaleEffect: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { }
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                        .frame(width: 70, height: 70)
                        .scaleEffect(scaleEffect)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: scaleEffect)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.7)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple, Color.blue]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(rotationAngle))
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: rotationAngle)
                }
                
                VStack(spacing: 8) {
                    Text("Analyzing cardiac data...")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Please wait while we process your health insights")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
        }
        .onAppear {
            rotationAngle = 360
            scaleEffect = 1.2
        }
    }
}

struct PremiumEmptyStateView: View {
    var geo: GeometryProxy
    @State private var animateEmpty = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 80)
            
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateEmpty ? 1.0 : 0.8)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateEmpty)
                
                Image(systemName: "heart.text.square")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animateEmpty ? 1.0 : 0.8)
                    .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2), value: animateEmpty)
            }
            
            VStack(spacing: 16) {
                Text("Begin Your Health Journey")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Start tracking your cardiac health to unlock personalized insights, comprehensive analytics, and professional medical reports.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 32)
            }
            .opacity(animateEmpty ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.8).delay(0.4), value: animateEmpty)
            
            VStack(spacing: 12) {
                Button(action: {
                    // Navigate to measurement
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Take First Measurement")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: Color.blue.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .scaleEffect(animateEmpty ? 1.0 : 0.8)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: animateEmpty)
                .buttonStyle(PremiumButtonStyle())
                
                Text("Go to Home Page and Measure Your heart beat and visit here")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(animateEmpty ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8).delay(0.8), value: animateEmpty)
            }
            
            Spacer(minLength: 80)
        }
        .frame(minHeight: geo.size.height * 0.7)
        .onAppear {
            withAnimation {
                animateEmpty = true
            }
        }
    }
}

struct PremiumRiskAssessmentCard: View {
    var assessment: CardiacRiskAssessment
    @State private var pulseAnimation = false
    @State private var glowAnimation = false
    
    var riskColor: Color {
        switch assessment.risk_level.lowercased() {
        case "low": return .green
        case "moderate": return .orange
        case "high": return .red
        case "very high": return .red
        default: return .gray
        }
    }
    
    var riskIcon: String {
        switch assessment.risk_level.lowercased() {
        case "low": return "checkmark.shield.fill"
        case "moderate": return "exclamationmark.triangle.fill"
        case "high": return "heart.slash.fill"
        case "very high": return "exclamationmark.octagon.fill"
        default: return "questionmark.circle"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Premium Header Section
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(riskColor.opacity(0.1))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .stroke(riskColor.opacity(glowAnimation ? 0.8 : 0.3), lineWidth: 2)
                                .scaleEffect(glowAnimation ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowAnimation)
                        )
                    
                    Image(systemName: riskIcon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(riskColor)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Cardiac Risk Assessment")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("Score:")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(assessment.risk_score)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(riskColor)
                        }
                        
                    }
                }
                
                Spacer()
                
                // Premium Risk Badge
                Text(assessment.risk_level.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(riskColor)
                            .shadow(color: riskColor.opacity(0.4), radius: 6, x: 0, y: 3)
                    )
            }
            
            // Risk Factors with Premium Styling
            if !assessment.factors.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Contributing Factors")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                        ForEach(Array(assessment.factors.prefix(3).enumerated()), id: \.offset) { index, factor in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(riskColor.opacity(0.2))
                                        .frame(width: 8, height: 8)
                                    Circle()
                                        .fill(riskColor)
                                        .frame(width: 6, height: 6)
                                }
                                .padding(.top, 6)
                                
                                Text(factor)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    riskColor.opacity(0.3),
                                    riskColor.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: riskColor.opacity(0.1), radius: 15, x: 0, y: 8)
        )
        .onAppear {
            pulseAnimation = true
            glowAnimation = true
        }
    }
}

struct PremiumBottomNavItem: View {
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

// MARK: - Premium Health Metrics Overview
struct PremiumHealthMetricsOverview: View {
    var summary: WeeklySummary?
    var geo: GeometryProxy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Health Metrics Overview")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                PremiumMetricCard(
                    title: "Heart Rate",
                    value: summary != nil ? "\(Int(summary!.avg_bpm))" : "--",
                    unit: "BPM",
                    subtitle: summary != nil ? "\(summary!.min_bpm)-\(summary!.max_bpm) range" : "No data",
                    icon: "heart.fill",
                    color: getHeartRateColor(summary?.avg_bpm ?? 0)
                )
                
                PremiumMetricCard(
                    title: "Blood Pressure",
                    value: summary != nil ? "\(summary!.avg_bp_systolic)/\(summary!.avg_bp_diastolic)" : "--/--",
                    unit: "mmHg",
                    subtitle: "Average pressure",
                    icon: "heart.text.square.fill",
                    color: getBPColor(systolic: summary?.avg_bp_systolic ?? 0,
                                      diastolic: summary?.avg_bp_diastolic ?? 0)
                )
                
                PremiumMetricCard(
                    title: "Heart Rate Variability",
                    value: summary?.avg_hrv != nil ? String(format: "%.1f", summary!.avg_hrv!) : "--",
                    unit: "ms",
                    subtitle: "Autonomic balance",
                    icon: "waveform.path.ecg",
                    color: getHRVColor(summary?.avg_hrv ?? 0)
                )
                
                PremiumMetricCard(
                    title: "Resting Heart Rate",
                    value: summary?.resting_heart_rate != nil ? String(format: "%.0f", summary!.resting_heart_rate!) : "--",
                    unit: "BPM",
                    subtitle: "At rest",
                    icon: "moon.zzz.fill",
                    color: getRestingHRColor(summary?.resting_heart_rate ?? 0)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.cardBackgroundColor)
                .shadow(color: AppColors.shadowColor, radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
    
    private func getHeartRateColor(_ bpm: Double) -> Color {
        switch bpm {
        case 0: return .gray
        case ..<60: return .blue
        case 60...100: return .green
        default: return .red
        }
    }
    
    private func getBPColor(systolic: Int, diastolic: Int) -> Color {
        if systolic == 0 && diastolic == 0 { return .gray }
        if systolic < 120 && diastolic < 80 { return .green }
        if systolic < 130 && diastolic < 80 { return .yellow }
        if systolic < 140 || diastolic < 90 { return .orange }
        return .red
    }
    
    private func getHRVColor(_ hrv: Double) -> Color {
        switch hrv {
        case 0: return .gray
        case ..<20: return .red
        case 20...60: return .yellow
        default: return .green
        }
    }
    
    private func getRestingHRColor(_ hr: Double) -> Color {
        switch hr {
        case 0: return .gray
        case ..<60: return .blue
        case 60...80: return .green
        default: return .red
        }
    }
}

struct PremiumMetricCard: View {
    var title: String
    var value: String
    var unit: String
    var subtitle: String
    var icon: String
    var color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    Text(unit)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - CORRECTED Premium Trend Charts Section with Horizontal Scrolling
struct PremiumTrendChartsSection: View {
    var dailyReadings: [DailyReading]
    var geo: GeometryProxy
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Health Trends")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Scroll indicator
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left.chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Scroll to explore")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                )
            }
            
            if dailyReadings.isEmpty {
                EmptyChartView()
            } else {
                VStack(spacing: 24) {
                    // Heart Rate Trend Chart
                    PremiumScrollableChartCard(
                        title: "Heart Rate Trend",
                        subtitle: "Daily average BPM over time",
                        color: .red,
                        geo: geo
                    ) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Chart {
                                ForEach(dailyReadings, id: \.date) { reading in
                                    LineMark(
                                        x: .value("Date", formatChartDate(reading.date)),
                                        y: .value("BPM", reading.avg_bpm)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.red, Color.red.opacity(0.7)]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                    
                                    AreaMark(
                                        x: .value("Date", formatChartDate(reading.date)),
                                        y: .value("BPM", reading.avg_bpm)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.red.opacity(0.2), Color.clear]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    
                                    PointMark(
                                        x: .value("Date", formatChartDate(reading.date)),
                                        y: .value("BPM", reading.avg_bpm)
                                    )
                                    .foregroundStyle(Color.red)
                                    .symbolSize(60)
                                }
                            }
                            .frame(width: max(geo.size.width - 80, CGFloat(dailyReadings.count * 80)), height: 220)
                            .chartXAxis {
                                AxisMarks(values: .automatic(desiredCount: min(dailyReadings.count, 7))) { value in
                                    AxisGridLine()
                                        .foregroundStyle(Color.gray.opacity(0.3))
                                    AxisTick()
                                        .foregroundStyle(Color.gray)
                                    AxisValueLabel {
                                        if let stringValue = value.as(String.self) {
                                            Text(stringValue)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                                    AxisGridLine()
                                        .foregroundStyle(Color.gray.opacity(0.3))
                                    AxisTick()
                                        .foregroundStyle(Color.gray)
                                    AxisValueLabel {
                                        if let doubleValue = value.as(Double.self) {
                                            Text("\(Int(doubleValue))")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .padding(.horizontal, 10)
                        }
                        .scrollIndicators(.hidden)
                    }
                    
                    // CORRECTED Blood Pressure Trend Chart
                    PremiumScrollableChartCard(
                        title: "Blood Pressure Trend",
                        subtitle: "Systolic & Diastolic pressure over time",
                        color: .purple,
                        geo: geo
                    ) {
                        VStack(spacing: 0) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                Chart {
                                    ForEach(dailyReadings, id: \.date) { reading in
                                        // Systolic Line
                                        LineMark(
                                            x: .value("Date", formatChartDate(reading.date)),
                                            y: .value("Pressure", reading.avg_systolic),
                                            series: .value("Type", "Systolic")
                                        )
                                        .foregroundStyle(Color.purple)
                                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                        
                                        // Diastolic Line
                                        LineMark(
                                            x: .value("Date", formatChartDate(reading.date)),
                                            y: .value("Pressure", reading.avg_diastolic),
                                            series: .value("Type", "Diastolic")
                                        )
                                        .foregroundStyle(Color.blue)
                                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                                        
                                        // Systolic Points
                                        PointMark(
                                            x: .value("Date", formatChartDate(reading.date)),
                                            y: .value("Pressure", reading.avg_systolic)
                                        )
                                        .foregroundStyle(Color.purple)
                                        .symbolSize(50)
                                        
                                        // Diastolic Points
                                        PointMark(
                                            x: .value("Date", formatChartDate(reading.date)),
                                            y: .value("Pressure", reading.avg_diastolic)
                                        )
                                        .foregroundStyle(Color.blue)
                                        .symbolSize(50)
                                    }
                                }
                                .frame(width: max(geo.size.width - 80, CGFloat(dailyReadings.count * 80)), height: 220)
                                .chartXAxis {
                                    AxisMarks(values: .automatic(desiredCount: min(dailyReadings.count, 7))) { value in
                                        AxisGridLine()
                                            .foregroundStyle(Color.gray.opacity(0.3))
                                        AxisTick()
                                            .foregroundStyle(Color.gray)
                                        AxisValueLabel {
                                            if let stringValue = value.as(String.self) {
                                                Text(stringValue)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                                        AxisGridLine()
                                            .foregroundStyle(Color.gray.opacity(0.3))
                                        AxisTick()
                                            .foregroundStyle(Color.gray)
                                        AxisValueLabel {
                                            if let doubleValue = value.as(Double.self) {
                                                Text("\(Int(doubleValue))")
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                                .chartYScale(domain: .automatic(includesZero: false))
                                .padding(.horizontal, 10)
                            }
                            .scrollIndicators(.hidden)
                            
                            // Legend for Blood Pressure Chart
                            HStack(spacing: 20) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.purple)
                                        .frame(width: 10, height: 10)
                                    Text("Systolic")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 10, height: 10)
                                    Text("Diastolic")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.top, 12)
                        }
                    }
                    
                    // HRV Chart (if data available)
                    
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.cardBackgroundColor)
                .shadow(color: AppColors.shadowColor, radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, 20)
    }
    
    // Date formatting for chart readability
    private func formatChartDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        
        // Use shorter format for better readability in charts
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - NEW Scrollable Chart Card Component
struct PremiumScrollableChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let color: Color
    let geo: GeometryProxy
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enhanced Header with Chart Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Enhanced Chart Indicator
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color.opacity(0.2))
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                            )
                        
                        // Scroll hint for mobile
                        Image(systemName: "hand.draw")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(color.opacity(0.7))
                    }
                }
                
                // Data point count indicator
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Swipe to view all data points")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            // Chart Content with Improved Container
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                color.opacity(0.02),
                                Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                content()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color.opacity(0.2),
                                    color.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No trend data available")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("Take more measurements to see your health trends")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}

// MARK: - Updated Detailed Report View (Removed Export Option)
struct DetailedReportView: View {
    var summary: WeeklySummary?
    var dailyReadings: [DailyReading]
    var riskAssessment: CardiacRiskAssessment?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cardiac Health Report")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Generated on \(getCurrentDate())")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Divider()
                    }
                    .padding(.horizontal, 20)
                    
                    // Summary Section
                    if let summary = summary {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Health Summary")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)

                            VStack(spacing: 12) {
                                HealthMetricRow(
                                    title: "Average Heart Rate",
                                    value: "\(Int(summary.avg_bpm)) BPM",
                                    status: getHeartRateStatus(summary.avg_bpm)
                                )
                                
                                HealthMetricRow(
                                    title: "Heart Rate Range",
                                    value: "\(summary.min_bpm) - \(summary.max_bpm) BPM",
                                    status: "Range"
                                )
                                
                                HealthMetricRow(
                                    title: "Average Blood Pressure",
                                    value: "\(summary.avg_bp_systolic)/\(summary.avg_bp_diastolic) mmHg",
                                    status: getBPStatus(systolic: summary.avg_bp_systolic, diastolic: summary.avg_bp_diastolic)
                                )
                                
                                if let hrv = summary.avg_hrv {
                                    HealthMetricRow(
                                        title: "Heart Rate Variability",
                                        value: String(format: "%.1f ms", hrv),
                                        status: getHRVStatus(hrv)
                                    )
                                }
                                
                                if let restingHR = summary.resting_heart_rate {
                                    HealthMetricRow(
                                        title: "Resting Heart Rate",
                                        value: String(format: "%.0f BPM", restingHR),
                                        status: getRestingHRStatus(restingHR)
                                    )
                                }
                                
                                if let recoveryHR = summary.recovery_heart_rate {
                                    HealthMetricRow(
                                        title: "Recovery Heart Rate",
                                        value: String(format: "%.0f BPM", recoveryHR),
                                        status: "Recovery Rate"
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.05))
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Risk Assessment Section
                    if let risk = riskAssessment {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Risk Assessment")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Risk Level:")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                    Text(risk.risk_level.uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(getRiskColor(risk.risk_level))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(getRiskColor(risk.risk_level).opacity(0.2))
                                        )
                                }
                                
                                HStack {
                                    Text("Risk Score:")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                    Text("\(risk.risk_score)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(getRiskColor(risk.risk_level))
                                }
                                
                                if !risk.factors.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Risk Factors:")
                                            .font(.system(size: 16, weight: .semibold))
                                        
                                        ForEach(risk.factors, id: \.self) { factor in
                                            HStack(alignment: .top, spacing: 8) {
                                                Circle()
                                                    .fill(Color.orange)
                                                    .frame(width: 6, height: 6)
                                                    .padding(.top, 6)
                                                
                                                Text(factor)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                                
                                if !risk.recommendations.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Recommendations:")
                                            .font(.system(size: 16, weight: .semibold))
                                        
                                        ForEach(risk.recommendations, id: \.self) { recommendation in
                                            HStack(alignment: .top, spacing: 8) {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 6, height: 6)
                                                    .padding(.top, 6)
                                                
                                                Text(recommendation)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.05))
                        )
                    }
                    
                    // Framingham Risk Score Documentation Card
                    framinghamDocumentationCard
                    if !dailyReadings.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Daily Measurements")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(dailyReadings, id: \.date) { reading in
                                    DailyReadingCard(reading: reading)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Footer
                    VStack(spacing: 8) {
                        Text("This report is for informational purposes only and should not replace professional medical advice.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Consult with your healthcare provider for proper medical evaluation.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Medical Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Enhanced Framingham Risk Score Documentation Card
    private var framinghamDocumentationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.22), Color.blue.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.appAccent.opacity(0.35), lineWidth: 1)
                        )
                    
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.appAccent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Framingham Risk Score")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textPrimary)
                    
                    Text("10-Year Cardiovascular Disease Guidelines")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.textSecondary)
                }
                
                Spacer()
                
                Text("CLINICAL")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundColor(Color.appAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appAccent.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Text("Risk scores are calculated based on peer-reviewed cardiovascular risk assessment guidelines from the Framingham Heart Study.")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.textSecondary)
                .lineSpacing(2)
            
            if let url = URL(string: "https://www.framinghamheartstudy.org/fhs-risk-functions/cardiovascular-disease-10-year-risk/") {
                Link(destination: url) {
                    HStack(spacing: 10) {
                        Image(systemName: "safari.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.appAccent)
                        
                        Text("View Framingham Risk Score Documentation")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.appAccent)
                            .padding(6)
                            .background(Color.appAccent.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.appAccent.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.appAccent.opacity(0.25), lineWidth: 1)
                    )
                }
            }
        }
        .padding(18)
        .glossyCard(cornerRadius: 18, borderTint: Color.appAccent.opacity(0.4))
        .padding(.horizontal, 20)
    }
    
    
    // Helper Functions
    private func getCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    private func getHeartRateStatus(_ bpm: Double) -> String {
        switch bpm {
        case 0: return "No Data"
        case ..<60: return "Below Normal"
        case 60...100: return "Normal"
        default: return "Above Normal"
        }
    }
    
    private func getBPStatus(systolic: Int, diastolic: Int) -> String {
        if systolic == 0 && diastolic == 0 { return "No Data" }
        if systolic < 120 && diastolic < 80 { return "Normal" }
        if systolic < 130 && diastolic < 80 { return "Elevated" }
        if systolic < 140 || diastolic < 90 { return "High Stage 1" }
        return "High Stage 2"
    }
    
    private func getHRVStatus(_ hrv: Double) -> String {
        switch hrv {
        case 0: return "No Data"
        case ..<20: return "Poor"
        case 20...60: return "Average"
        default: return "Good"
        }
    }
    
    private func getRestingHRStatus(_ hr: Double) -> String {
        switch hr {
        case 0: return "No Data"
        case ..<60: return "Athletic"
        case 60...80: return "Normal"
        default: return "Above Normal"
        }
    }
    
    private func getRiskColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "low": return .green
        case "moderate": return .orange
        case "high", "very high": return .red
        default: return .gray
        }
    }
    
}

struct HealthMetricRow: View {
    let title: String
    let value: String
    let status: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
    }
}

struct DailyReadingCard: View {
    let reading: DailyReading
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(formatDate(reading.date))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Heart Rate")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(Int(reading.avg_bpm)) BPM")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("Blood Pressure")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(reading.avg_systolic)/\(reading.avg_diastolic)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Measurements")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("\(reading.measurement_count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            
            if let hrv = reading.hrv {
                HStack {
                    Text("HRV:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f ms", hrv))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.cardBackgroundColor)
                .shadow(color: AppColors.shadowColor, radius: 4, x: 0, y: 2)
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Enhanced Export Data View with Premium Design (UPDATED)
struct EnhancedExportDataView: View {
    @EnvironmentObject var userManager: UserManager
    var weeklySummary: WeeklySummary?
    var dailyReadings: [DailyReading]
    var riskAssessment: CardiacRiskAssessment?
    
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var exportItems: [Any] = []
    @State private var isExporting = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Export Health Data")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Export your cardiac health data as a professional PDF report that can be shared with healthcare providers.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    
                    // ENHANCED PREMIUM PDF EXPORT CARD SECTION
                    VStack(alignment: .leading, spacing: 20) {
                        // Enhanced Section Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Export Options")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.primary,
                                                Color.primary.opacity(0.8)
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                Text("Choose your preferred format")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Premium badge/indicator
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.blue.opacity(0.1),
                                                Color.purple.opacity(0.05)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue, Color.purple]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Enhanced PDF Export Card with Premium Design
                        VStack(spacing: 0) {
                            // Card Header with Gradient Background
                            HStack(spacing: 16) {
                                // Enhanced Icon Container
                                ZStack {
                                    // Outer glow circle
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                gradient: Gradient(colors: [
                                                    Color.blue.opacity(0.3),
                                                    Color.blue.opacity(0.1),
                                                    Color.clear
                                                ]),
                                                center: .center,
                                                startRadius: 5,
                                                endRadius: 35
                                            )
                                        )
                                        .frame(width: 70, height: 70)
                                    
                                    // Main icon background
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.blue,
                                                    Color.blue.opacity(0.8)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 56, height: 56)
                                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                                    
                                    // PDF Icon with enhanced styling
                                    Image(systemName: "doc.richtext.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(.white)
                                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    // Enhanced title with gradient
                                    HStack(alignment: .center, spacing: 8) {
                                        Text("Professional PDF Report")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        // Premium badge
                                        }
                                    
                                    // Enhanced description with better typography
                                    Text("Overall Selected Report optimized for healthcare professionals")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                
                                Spacer()
                                
                                // Enhanced status indicator
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.green.opacity(0.2))
                                            .frame(width: 32, height: 32)
                                        
                                        Circle()
                                            .stroke(Color.green, lineWidth: 2)
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.green)
                                    }
                                    
                                    Text("Ready")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(20)
                            .background(
                                // Premium gradient background
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.white, location: 0),
                                        .init(color: Color.blue.opacity(0.02), location: 0.5),
                                        .init(color: Color.white, location: 1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            
                            // Feature highlights section
                            VStack(spacing: 12) {
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.clear,
                                                Color.blue.opacity(0.1),
                                                Color.clear
                                            ]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(height: 1)
                                
                                HStack(spacing: 20) {
                                    FeatureHighlight(
                                        icon: "shield.checkered",
                                        title: "Secure",
                                        color: .green
                                    )
                                    
                                    FeatureHighlight(
                                        icon: "clock.fill",
                                        title: "Instant",
                                        color: .orange
                                    )
                                    
                                    
                                    FeatureHighlight(
                                        icon: "person.fill.checkmark",
                                        title: "Medical Grade",
                                        color: .blue
                                    )
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 16)
                            }
                            .background(Color.gray.opacity(0.02))
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(AppColors.cardBackgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.blue.opacity(0.3),
                                                    Color.blue.opacity(0.1),
                                                    Color.purple.opacity(0.1),
                                                    Color.blue.opacity(0.2)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .shadow(
                                    color: Color.blue.opacity(0.15),
                                    radius: 20,
                                    x: 0,
                                    y: 8
                                )
                                .shadow(
                                    color: Color.black.opacity(0.05),
                                    radius: 5,
                                    x: 0,
                                    y: 2
                                )
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Data Preview
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Summary")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 12) {
                            DataSummaryRow(title: "Health Metrics", value: weeklySummary != nil ? "Available" : "Not Available", color: weeklySummary != nil ? .green : .gray)
                            DataSummaryRow(title: "Daily Readings", value: "\(dailyReadings.count) days", color: dailyReadings.isEmpty ? .gray : .blue)
                            DataSummaryRow(title: "Risk Assessment", value: riskAssessment != nil ? "Available" : "Not Available", color: riskAssessment != nil ? .green : .gray)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.gray.opacity(0.05))
                        )
                        .padding(.horizontal, 20)
                    }
                    
                    // Export Button
                    VStack(spacing: 16) {
                        Button(action: exportData) {
                            HStack {
                                if isExporting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                
                                Text(isExporting ? "Exporting..." : "Export PDF Report")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.blue)
                            )
                        }
                        .disabled(isExporting)
                        .padding(.horizontal, 20)
                        
                        Text("Your data will be exported securely as a PDF report that can be shared with healthcare providers or saved for personal records.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if !exportItems.isEmpty {
                ShareSheet(activityItems: exportItems)
            }
        }
        .alert("Export Status", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func exportData() {
        isExporting = true
        exportItems.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let pdfData = createPDFData() {
                // Save to file URL with proper .pdf filename in temporary directory
                let fileName = "CoreCare_Cardiac_Health_Report.pdf"
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                do {
                    try pdfData.write(to: fileURL, options: .atomic)
                    DispatchQueue.main.async {
                        self.isExporting = false
                        self.exportItems = [fileURL]
                        self.showShareSheet = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.isExporting = false
                        self.alertMessage = "Failed to save PDF file: \(error.localizedDescription)"
                        self.showAlert = true
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.alertMessage = "Failed to export PDF. Please try again."
                    self.showAlert = true
                }
            }
        }
    }
    
    private func createPDFData() -> Data? {
        let pdfCreator = PDFCreator()
        let patient = userManager.userData?.emailOrPhone ?? (userManager.currentUserId != nil ? "User ID: \(userManager.currentUserId!)" : "Patient")
        return pdfCreator.createPDF(
            patientInfo: patient,
            summary: weeklySummary,
            dailyReadings: dailyReadings,
            riskAssessment: riskAssessment
        )
    }
}

// MARK: - Supporting Feature Highlight Component
struct FeatureHighlight: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 1)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DataSummaryRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
        }
    }
}

// MARK: - PDF Creator Class with Professional Medical Styling
class PDFCreator {
    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792
    private let marginX: CGFloat = 44
    private let marginY: CGFloat = 44
    private var contentWidth: CGFloat { pageWidth - (marginX * 2) }
    
    private let medicalBlue = UIColor(red: 0.05, green: 0.40, blue: 0.75, alpha: 1.0)
    private let secondaryText = UIColor(white: 0.40, alpha: 1.0)
    private let cardBackground = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
    private let cardBorder = UIColor(red: 0.88, green: 0.91, blue: 0.95, alpha: 1.0)
    
    func createPDF(patientInfo: String = "CoreCare Patient", summary: WeeklySummary?, dailyReadings: [DailyReading], riskAssessment: CardiacRiskAssessment?) -> Data? {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        return pdfRenderer.pdfData { context in
            var pageNumber = 1
            context.beginPage()
            
            var yPosition: CGFloat = marginY
            
            // Draw First Page Header
            drawHeader(context: context, pageNumber: pageNumber, patientInfo: patientInfo, yPosition: &yPosition)
            
            // 1. Patient & Report Details Card
            drawPatientInfoCard(context: context, patientInfo: patientInfo, summary: summary, yPosition: &yPosition)
            
            // 2. Health Metrics Summary
            drawHealthSummarySection(context: context, summary: summary, yPosition: &yPosition)
            
            // 3. Risk Assessment Section
            drawRiskAssessmentSection(context: context, riskAssessment: riskAssessment, patientInfo: patientInfo, pageNumber: &pageNumber, yPosition: &yPosition)
            
            // 4. Daily Readings Log Table
            drawDailyReadingsSection(context: context, dailyReadings: dailyReadings, patientInfo: patientInfo, pageNumber: &pageNumber, yPosition: &yPosition)
            
            // Final footer on the last page
            drawFooter(context: context, pageNumber: pageNumber)
        }
    }
    
    private func checkPageBreak(neededHeight: CGFloat, context: UIGraphicsPDFRendererContext, patientInfo: String, pageNumber: inout Int, yPosition: inout CGFloat) {
        if yPosition + neededHeight > pageHeight - marginY - 30 {
            drawFooter(context: context, pageNumber: pageNumber)
            context.beginPage()
            pageNumber += 1
            yPosition = marginY
            drawHeader(context: context, pageNumber: pageNumber, patientInfo: patientInfo, yPosition: &yPosition)
        }
    }
    
    private func drawHeader(context: UIGraphicsPDFRendererContext, pageNumber: Int, patientInfo: String, yPosition: inout CGFloat) {
        let brandAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: medicalBlue
        ]
        "CoreCare Health".draw(at: CGPoint(x: marginX, y: yPosition), withAttributes: brandAttributes)
        
        let reportTypeAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: UIColor(red: 0.1, green: 0.5, blue: 0.9, alpha: 1.0)
        ]
        "CLINICAL CARDIAC REPORT".draw(at: CGPoint(x: marginX, y: yPosition + 25), withAttributes: reportTypeAttributes)
        
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: secondaryText
        ]
        let dateStr = "Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
        let dateSize = (dateStr as NSString).size(withAttributes: dateAttributes)
        dateStr.draw(at: CGPoint(x: pageWidth - marginX - dateSize.width, y: yPosition + 4), withAttributes: dateAttributes)
        
        yPosition += 45
        
        let cg = context.cgContext
        cg.setStrokeColor(medicalBlue.withAlphaComponent(0.3).cgColor)
        cg.setLineWidth(1.5)
        cg.move(to: CGPoint(x: marginX, y: yPosition))
        cg.addLine(to: CGPoint(x: pageWidth - marginX, y: yPosition))
        cg.strokePath()
        
        yPosition += 16
    }
    
    private func drawFooter(context: UIGraphicsPDFRendererContext, pageNumber: Int) {
        let footerY = pageHeight - marginY + 10
        let cg = context.cgContext
        
        cg.setStrokeColor(UIColor(white: 0.85, alpha: 1.0).cgColor)
        cg.setLineWidth(0.5)
        cg.move(to: CGPoint(x: marginX, y: footerY - 8))
        cg.addLine(to: CGPoint(x: pageWidth - marginX, y: footerY - 8))
        cg.strokePath()
        
        let disclaimerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: UIColor.gray
        ]
        let disclaimer = "Confidential • Generated by CoreCare iOS • For personal health tracking & physician review."
        disclaimer.draw(at: CGPoint(x: marginX, y: footerY), withAttributes: disclaimerAttributes)
        
        let pageAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: UIColor.gray
        ]
        let pageStr = "Page \(pageNumber)"
        let pageSize = (pageStr as NSString).size(withAttributes: pageAttributes)
        pageStr.draw(at: CGPoint(x: pageWidth - marginX - pageSize.width, y: footerY), withAttributes: pageAttributes)
    }
    
    private func drawPatientInfoCard(context: UIGraphicsPDFRendererContext, patientInfo: String, summary: WeeklySummary?, yPosition: inout CGFloat) {
        let cardRect = CGRect(x: marginX, y: yPosition, width: contentWidth, height: 48)
        let cg = context.cgContext
        
        cg.setFillColor(cardBackground.cgColor)
        cg.setStrokeColor(cardBorder.cgColor)
        cg.setLineWidth(1.0)
        let path = UIBezierPath(roundedRect: cardRect, cornerRadius: 8)
        cg.addPath(path.cgPath)
        cg.drawPath(using: .fillStroke)
        
        let labelAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: secondaryText
        ]
        let valAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.darkText
        ]
        
        "PATIENT / ACCOUNT".draw(at: CGPoint(x: marginX + 16, y: yPosition + 10), withAttributes: labelAttr)
        patientInfo.draw(at: CGPoint(x: marginX + 16, y: yPosition + 24), withAttributes: valAttr)
        
        "EVALUATION PERIOD".draw(at: CGPoint(x: marginX + 220, y: yPosition + 10), withAttributes: labelAttr)
        "Last 7 Days Assessment".draw(at: CGPoint(x: marginX + 220, y: yPosition + 24), withAttributes: valAttr)
        
        "STATUS".draw(at: CGPoint(x: marginX + 400, y: yPosition + 10), withAttributes: labelAttr)
        "Active Record".draw(at: CGPoint(x: marginX + 400, y: yPosition + 24), withAttributes: valAttr)
        
        yPosition += 62
    }
    
    private func drawHealthSummarySection(context: UIGraphicsPDFRendererContext, summary: WeeklySummary?, yPosition: inout CGFloat) {
        let sectionTitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: medicalBlue
        ]
        "VITAL METRICS SUMMARY".draw(at: CGPoint(x: marginX, y: yPosition), withAttributes: sectionTitleAttr)
        yPosition += 22
        
        let cardWidth = (contentWidth - 20) / 3
        let cardHeight: CGFloat = 64
        
        let avgBPM = summary != nil ? "\(Int(summary!.avg_bpm)) BPM" : "--"
        let hrRange = summary != nil ? "\(summary!.min_bpm) - \(summary!.max_bpm) BPM" : "No range data"
        drawMetricBox(context: context, rect: CGRect(x: marginX, y: yPosition, width: cardWidth, height: cardHeight), title: "AVERAGE HEART RATE", value: avgBPM, subtext: "Range: \(hrRange)", valueColor: UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0))
        
        let bpText = summary != nil ? "\(summary!.avg_bp_systolic)/\(summary!.avg_bp_diastolic) mmHg" : "--"
        drawMetricBox(context: context, rect: CGRect(x: marginX + cardWidth + 10, y: yPosition, width: cardWidth, height: cardHeight), title: "AVG BLOOD PRESSURE", value: bpText, subtext: "Systolic / Diastolic", valueColor: medicalBlue)
        
        let statusText = summary != nil ? "Regular" : "No Data"
        let statusSub = summary != nil ? "Monitored Regularly" : "Awaiting readings"
        drawMetricBox(context: context, rect: CGRect(x: marginX + (cardWidth + 10) * 2, y: yPosition, width: cardWidth, height: cardHeight), title: "ACTIVITY STATUS", value: statusText, subtext: statusSub, valueColor: UIColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1.0))
        
        yPosition += cardHeight + 20
    }
    
    private func drawMetricBox(context: UIGraphicsPDFRendererContext, rect: CGRect, title: String, value: String, subtext: String, valueColor: UIColor) {
        let cg = context.cgContext
        cg.setFillColor(cardBackground.cgColor)
        cg.setStrokeColor(cardBorder.cgColor)
        cg.setLineWidth(1.0)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        cg.addPath(path.cgPath)
        cg.drawPath(using: .fillStroke)
        
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: secondaryText
        ]
        title.draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 10), withAttributes: titleAttr)
        
        let valAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 15),
            .foregroundColor: valueColor
        ]
        value.draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 24), withAttributes: valAttr)
        
        let subAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .regular),
            .foregroundColor: secondaryText
        ]
        subtext.draw(at: CGPoint(x: rect.minX + 10, y: rect.minY + 46), withAttributes: subAttr)
    }
    
    private func drawRiskAssessmentSection(context: UIGraphicsPDFRendererContext, riskAssessment: CardiacRiskAssessment?, patientInfo: String, pageNumber: inout Int, yPosition: inout CGFloat) {
        checkPageBreak(neededHeight: 120, context: context, patientInfo: patientInfo, pageNumber: &pageNumber, yPosition: &yPosition)
        
        let sectionTitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: medicalBlue
        ]
        "CARDIOVASCULAR RISK ASSESSMENT".draw(at: CGPoint(x: marginX, y: yPosition), withAttributes: sectionTitleAttr)
        yPosition += 22
        
        if let risk = riskAssessment {
            let riskColor: UIColor
            switch risk.risk_level.lowercased() {
            case "high": riskColor = UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1.0)
            case "moderate": riskColor = UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1.0)
            default: riskColor = UIColor(red: 0.15, green: 0.65, blue: 0.35, alpha: 1.0)
            }
            
            let cardRect = CGRect(x: marginX, y: yPosition, width: contentWidth, height: 42)
            let cg = context.cgContext
            cg.setFillColor(cardBackground.cgColor)
            cg.setStrokeColor(cardBorder.cgColor)
            cg.setLineWidth(1.0)
            cg.addPath(UIBezierPath(roundedRect: cardRect, cornerRadius: 8).cgPath)
            cg.drawPath(using: .fillStroke)
            
            let riskLevelTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            "Calculated Risk Level:".draw(at: CGPoint(x: marginX + 14, y: yPosition + 14), withAttributes: riskLevelTitleAttr)
            
            let riskLevelValAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 13),
                .foregroundColor: riskColor
            ]
            risk.risk_level.uppercased().draw(at: CGPoint(x: marginX + 150, y: yPosition + 13), withAttributes: riskLevelValAttr)
            
            let scoreAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: UIColor.darkGray
            ]
            let scoreStr = "Score: \(risk.risk_score)/100"
            let scoreSize = (scoreStr as NSString).size(withAttributes: scoreAttr)
            scoreStr.draw(at: CGPoint(x: pageWidth - marginX - scoreSize.width - 14, y: yPosition + 14), withAttributes: scoreAttr)
            
            yPosition += 52
            
            if !risk.factors.isEmpty {
                checkPageBreak(neededHeight: 40, context: context, patientInfo: patientInfo, pageNumber: &pageNumber, yPosition: &yPosition)
                let subheadAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: UIColor.darkText
                ]
                "Identified Risk Factors:".draw(at: CGPoint(x: marginX + 4, y: yPosition), withAttributes: subheadAttr)
                yPosition += 18
                
                let regularAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor(white: 0.2, alpha: 1.0)
                ]
                
                for factor in risk.factors {
                    checkPageBreak(neededHeight: 20, context: context, patientInfo: patientInfo, pageNumber: &pageNumber, yPosition: &yPosition)
                    drawWrappedText(bulletText: "•  \(factor)", x: marginX + 12, width: contentWidth - 24, attributes: regularAttr, yPosition: &yPosition)
                }
                yPosition += 10
            }
            
            if !risk.recommendations.isEmpty {
                checkPageBreak(neededHeight: 40, context: context, patientInfo: patientInfo, pageNumber: &pageNumber, yPosition: &yPosition)
                let subheadAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 11),
                    .foregroundColor: UIColor.darkText
                ]
                "Clinical Recommendations:".draw(at: CGPoint(x: marginX + 4, y: yPosition), withAttributes: subheadAttr)
                yPosition += 18
                
                let regularAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor(white: 0.2, alpha: 1.0)
                ]
                
                for rec in risk.recommendations {
                    checkPageBreak(neededHeight: 24, context: context, patientInfo: patientInfo, pageNumber: &pageNumber, yPosition: &yPosition)
                    drawWrappedText(bulletText: "•  \(rec)", x: marginX + 12, width: contentWidth - 24, attributes: regularAttr, yPosition: &yPosition)
                }
                yPosition += 12
            }
        } else {
            let regularAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            "No risk assessment data recorded for this timeframe.".draw(at: CGPoint(x: marginX + 4, y: yPosition), withAttributes: regularAttr)
            yPosition += 24
        }
        
        yPosition += 12
    }
    
    private func drawDailyReadingsSection(context: UIGraphicsPDFRendererContext, dailyReadings: [DailyReading], patientInfo: String, pageNumber: inout Int, yPosition: inout CGFloat) {
        checkPageBreak(neededHeight: 80, context: context, patientInfo: patientInfo, pageNumber: &pageNumber, yPosition: &yPosition)
        
        let sectionTitleAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: medicalBlue
        ]
        "DAILY MEASUREMENTS LOG".draw(at: CGPoint(x: marginX, y: yPosition), withAttributes: sectionTitleAttr)
        yPosition += 22
        
        let colWidths: [CGFloat] = [140, 120, 140, 124]
        let colHeaders = ["DATE", "AVG HEART RATE", "BLOOD PRESSURE", "HRV"]
        let headerHeight: CGFloat = 22
        
        let cg = context.cgContext
        let headerRect = CGRect(x: marginX, y: yPosition, width: contentWidth, height: headerHeight)
        cg.setFillColor(medicalBlue.withAlphaComponent(0.08).cgColor)
        cg.fill(headerRect)
        
        let thAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: medicalBlue
        ]
        
        var colX = marginX + 10
        for (i, title) in colHeaders.enumerated() {
            title.draw(at: CGPoint(x: colX, y: yPosition + 6), withAttributes: thAttr)
            colX += colWidths[i]
        }
        yPosition += headerHeight
        
        if dailyReadings.isEmpty {
            let emptyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.gray
            ]
            "No daily readings logged for this timeframe.".draw(at: CGPoint(x: marginX + 10, y: yPosition + 8), withAttributes: emptyAttr)
            yPosition += 26
            return
        }
        
        let rowHeight: CGFloat = 20
        let tdAttr: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.darkText
        ]
        
        for (idx, reading) in dailyReadings.enumerated() {
            checkPageBreak(neededHeight: rowHeight + 10, context: context, patientInfo: patientInfo, pageNumber: &pageNumber, yPosition: &yPosition)
            
            let rowRect = CGRect(x: marginX, y: yPosition, width: contentWidth, height: rowHeight)
            if idx % 2 == 1 {
                cg.setFillColor(UIColor(white: 0.97, alpha: 1.0).cgColor)
                cg.fill(rowRect)
            }
            
            let hrvStr = reading.hrv != nil ? String(format: "%.1f ms", reading.hrv!) : "--"
            let values = [
                reading.date,
                "\(Int(reading.avg_bpm)) BPM",
                "\(reading.avg_systolic)/\(reading.avg_diastolic) mmHg",
                hrvStr
            ]
            
            colX = marginX + 10
            for (i, val) in values.enumerated() {
                val.draw(at: CGPoint(x: colX, y: yPosition + 5), withAttributes: tdAttr)
                colX += colWidths[i]
            }
            
            yPosition += rowHeight
        }
    }
    
    private func drawWrappedText(bulletText: String, x: CGFloat, width: CGFloat, attributes: [NSAttributedString.Key: Any], yPosition: inout CGFloat) {
        let str = bulletText as NSString
        let bounds = str.boundingRect(
            with: CGSize(width: width, height: 1000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        let rect = CGRect(x: x, y: yPosition, width: width, height: ceil(bounds.height))
        str.draw(in: rect, withAttributes: attributes)
        yPosition += ceil(bounds.height) + 6
    }
}

// MARK: - ShareSheet for iOS
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        if let popover = controller.popoverPresentationController {
            popover.permittedArrowDirections = []
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            }
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Custom Button Style
struct PremiumButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollsOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(UserManager.shared)
    }
}


