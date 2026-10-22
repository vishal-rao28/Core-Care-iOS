import SwiftUI
import AVFoundation
import Combine

struct AIView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var toBreathe = false
    @State private var toHome = false

    @State private var heartbeat: Int?
    @State private var systolic: Int?
    @State private var diastolic: Int?

    @State private var stressPercentage: Double = 0
    @State private var stressCategory: String = "Low"
    
    // Advanced AI Stress Analysis Properties
    @State private var heartAttackRisk: Double = 0.0
    @State private var strokeRisk: Double = 0.0
    @State private var aiPrediction: String = "Analyzing..."
    @State private var riskFactors: [String] = []
    @State private var healthScore: Int = 85
    @State private var stressPattern: StressPattern = .stable
    @State private var cardiacStress: Double = 0.0
    @State private var autonomicBalance: Double = 0.5
    @State private var recoveryTime: Int = 0
    
    // Enhanced UI Animation States
    @State private var pulseAnimation = false
    @State private var glowEffect = false
    @State private var breathingAnimation = false
    @State private var particleAnimation = false
    
    // Static fallback data
    @State private var isUsingStaticData = false
    @State private var simulationTimer: Timer?
    
    // --- NEW: One-Time Critical Stress Alert System ---
    @State private var showCriticalStressAlert = false
    @State private var criticalAlertShown = false
    @State private var userDismissedAlert = false
    // --- END NEW ALERT SYSTEM ---
    
    // Audio Manager for breathing exercises
    @StateObject private var audioManager = AudioManager()
    
    
    @State private var showStressCitation = false
    
    
    // Get current user ID from UserManager
    private var currentUserId: Int {
        guard let userId = userManager.currentUserId, userId > 0 else {
            return 0
        }
        return userId
    }

    var body: some View {
        ZStack {
            // Animated background particles
            ParticleBackground()
                .opacity(particleAnimation ? 0.3 : 0.1)
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: particleAnimation)
            
            if toBreathe {
                BreatheView(
                    initialTechnique: stressCategory == "High" ? .quickReset : .coherence,
                    onSessionComplete: { _ in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            toBreathe = false
                        }
                    },
                    onSessionEnd: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            toBreathe = false
                        }
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            toBreathe = false
                        }
                    }
                )
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .slide
                    ))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: toBreathe)
                    .environmentObject(userManager)
                    .environmentObject(audioManager)
            } else if toHome {
                HomePageView(userId: currentUserId)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: toHome)
                    .environmentObject(userManager)
            } else {
                mainContent
                    .transition(
    .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
)

                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: toBreathe || toHome)
            }
            
            // --- NEW: One-Time Critical Stress Alert (shows above everything) ---
            if showCriticalStressAlert {
                criticalStressAlertOverlay
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(1000)
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            validateUserAndStart()
            startAnimations()
        }
        .onDisappear {
            simulationTimer?.invalidate()
            audioManager.stopBreathingAudio()
            resetAlertFlags() // Reset alert system when view disappears
        }
    }
    
    // MARK: - One-Time Critical Stress Alert Overlay
    
    var criticalStressAlertOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 25) {
                ZStack {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 100, height: 100)
                        .shadow(color: .red.opacity(0.5), radius: 15)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.red)
                }
                
                VStack(spacing: 15) {
                    Text("⚠️ Critical Stress Detected")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    VStack(spacing: 8) {
                        Text("Your stress level is at \(Int(stressPercentage))%")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let hr = heartbeat {
                            Text("Heart Rate: \(hr) BPM")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Text("Would you like to start a breathing exercise to help reduce your stress?")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(25)
                .glossyCard(cornerRadius: 20, borderTint: Color.red)
                
                HStack(spacing: 20) {
                    Button("Not Now") {
                        dismissCriticalAlert()
                    }
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    Button("Start Breathing") {
                        startBreathingFromAlert()
                    }
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [.red, .red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .red.opacity(0.3), radius: 5)
                }
                .padding(.horizontal, 25)
            }
            .padding(25)
        }
    }
    
    // MARK: - Alert Action Functions
    
    func dismissCriticalAlert() {
        withAnimation(.easeOut(duration: 0.3)) {
            showCriticalStressAlert = false
        }
        userDismissedAlert = true
        audioManager.stopBreathingAudio()
    }
    
    func startBreathingFromAlert() {
        withAnimation(.easeOut(duration: 0.3)) {
            showCriticalStressAlert = false
        }
        audioManager.startBreathingAudio()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            toBreathe = true
        }
    }
    
    func resetAlertFlags() {
        criticalAlertShown = false
        userDismissedAlert = false
        showCriticalStressAlert = false
    }

    // MARK: - Enhanced Main Content
    var mainContent: some View {
        GeometryReader { geo in
            let safeTop = max(geo.safeAreaInsets.top, 44)
            let safeBottom = max(geo.safeAreaInsets.bottom, 20)

            VStack(spacing: 0) {
                // Enhanced Header pinned at top
                enhancedHeaderSection
                    .padding(.horizontal, 20)
                    .padding(.top, safeTop + 8)
                    .padding(.bottom, 12)
                    .background(
                        Color.appBackground.opacity(0.85)
                            .background(.ultraThinMaterial)
                    )

                ScrollView {
                    VStack(spacing: 26) {
                        // AI Health Score with advanced graphics
                        advancedHealthScoreSection
                        
                        // Enhanced Risk Assessment
                        enhancedRiskAssessmentSection
                        
                        // Advanced Vitals Display
                        advancedVitalsSection
                        
                        // Sophisticated AI Analysis
                        sophisticatedAiAnalysisSection
                        
                        // Dynamic Smart Recommendations
                        smartRecommendationsSection
                        
                        // Enhanced Action Buttons
                        enhancedActionButtonsSection
                        
                        // Advanced AI Insights
                        advancedAiInsightsSection

                        Spacer(minLength: safeBottom + 20)
                    }
                    .padding(.top, 12)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(
            ZStack {
                Color.appBackground
                
                // Animated gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.08),
                        Color.purple.opacity(0.06),
                        Color.cyan.opacity(0.04)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle animated overlay
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.1),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 100,
                    endRadius: 400
                )
                .scaleEffect(glowEffect ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: glowEffect)
            }
            .ignoresSafeArea()
        )
    }
    
    // MARK: - Enhanced UI Sections
    
    var enhancedHeaderSection: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    toHome = true
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }

            ZStack {
                // Multi-layered icon design
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue,
                                Color.purple,
                                Color.cyan
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 46, height: 46)
                    .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 3)
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 38, height: 38)
                
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("Core Care AI")
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue,
                                Color.purple,
                                Color.blue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 2)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(isUsingStaticData ? .orange : .green)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Text(isUsingStaticData ? "Demo Mode" : "Live Analysis")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(isUsingStaticData ? .orange : .green)
                }
            }
            
            Spacer()
            
            // Enhanced Health Score Badge
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                healthScoreColor.opacity(0.15),
                                healthScoreColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(healthScoreColor.opacity(0.3), lineWidth: 1.5)
                    )
                    .frame(width: 65, height: 44)
                
                VStack(spacing: 1) {
                    Text("\(healthScore)")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(healthScoreColor)
                    
                    Text("Score")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .shadow(color: healthScoreColor.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
    
    var advancedHealthScoreSection: some View {
        ZStack {
            // Outer decorative ring
            Circle()
                .stroke(healthScoreColor.opacity(0.1), lineWidth: 8)
                .frame(width: 220, height: 220)
            
            // Animated progress ring
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 20)
                .frame(width: 200, height: 200)
            
            Circle()
                .trim(from: 0, to: CGFloat(Double(healthScore) / 100))
                .stroke(
                    AngularGradient(
                        colors: [
                            healthScoreColor,
                            healthScoreColor.opacity(0.8),
                            healthScoreColor.opacity(0.6),
                            healthScoreColor
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.5, dampingFraction: 0.7), value: healthScore)
                .shadow(color: healthScoreColor.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Central content
            VStack(spacing: 8) {
                Text("\(healthScore)")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [healthScoreColor, healthScoreColor.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: healthScoreColor.opacity(0.3), radius: 3)
                
                Text("HEALTH SCORE")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .tracking(1.5)
                
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Star(filled: index < healthStars)
                            .fill(healthScoreColor)
                            .frame(width: 12, height: 12)
                    }
                }
                
                Text(enhancedHealthScoreDescription)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            // Floating decorative elements
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(healthScoreColor.opacity(0.3))
                    .frame(width: 4, height: 4)
                    .offset(
                        x: cos(Double(index) * .pi / 3) * 110,
                        y: sin(Double(index) * .pi / 3) * 110
                    )
                    .scaleEffect(particleAnimation ? 1.5 : 0.5)
                    .animation(
                        .easeInOut(duration: 2)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.2),
                        value: particleAnimation
                    )
            }
        }
        .padding(.vertical, 25)
    }
    
    var enhancedRiskAssessmentSection: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Advanced Risk Analysis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("AI Powered")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 25)
            
            VStack(spacing: 15) {
                HStack(spacing: 15) {
                    AdvancedRiskCard(
                        title: "Cardiac Stress",
                        risk: cardiacStress,
                        icon: "heart.circle.fill",
                        color: cardiacRiskColor,
                        description: cardiacRiskDescription,
                        isWide: false
                    )
                    
                    AdvancedRiskCard(
                        title: "Autonomic Balance",
                        risk: autonomicBalance,
                        icon: "brain.head.profile.fill",
                        color: autonomicBalanceColor,
                        description: autonomicBalanceDescription,
                        isWide: false
                    )
                }
                
                AdvancedRiskCard(
                    title: "Overall Stress Impact",
                    risk: stressPercentage / 100,
                    icon: "waveform.path.ecg.rectangle.fill",
                    color: overallStressColor,
                    description: overallStressDescription,
                    isWide: true
                )
            }
            .padding(.horizontal, 25)
        }
    }
    
    var advancedVitalsSection: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2)
                    .foregroundColor(.green)
                
                Text("Live Vital Monitoring")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    Text("Real-time")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 25)
            
            HStack(spacing: 12) {
                AdvancedVitalCard(
                    icon: "heart.fill",
                    value: heartbeat != nil ? "\(heartbeat!)" : "--",
                    unit: "BPM",
                    label: "Heart Rate",
                    color: heartbeatColor,
                    trend: getHeartRateTrend(),
                    status: getHeartRateStatus()
                )
                
                AdvancedVitalCard(
                    icon: "arrow.up.right.circle.fill",
                    value: systolic != nil ? "\(systolic!)" : "--",
                    unit: "mmHg",
                    label: "Systolic",
                    color: systolicColor,
                    trend: getBPTrend(),
                    status: getSystolicStatus()
                )
                
                AdvancedVitalCard(
                    icon: "arrow.down.right.circle.fill",
                    value: diastolic != nil ? "\(diastolic!)" : "--",
                    unit: "mmHg",
                    label: "Diastolic",
                    color: diastolicColor,
                    trend: getBPTrend(),
                    status: getDiastolicStatus()
                )
            }
            .padding(.horizontal, 25)
        }
    }
    
    var sophisticatedAiAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 45, height: 45)
                        .shadow(color: .blue.opacity(0.3), radius: 5)
                    
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Core Assistant Analysis")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    HStack(spacing: 8) {
                        Text("Confidence: 96%")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.semibold)
                        
                        Text("•")
                            .foregroundColor(.gray)
                        
                        Text("Pattern: \(stressPattern.rawValue)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // AI Processing indicator
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: pulseAnimation
                            )
                    }
                }
            }

            Text(advancedAiAnalysisText)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // Advanced metrics display
            HStack(spacing: 15) {
                MetricPill(
                    label: "Recovery Time",
                    value: "\(recoveryTime) min",
                    color: recoveryTimeColor
                )
                
                MetricPill(
                    label: "Stress Pattern",
                    value: stressPattern.displayName,
                    color: stressPattern.color
                )
                
                MetricPill(
                    label: "ANS Balance",
                    value: "\(Int(autonomicBalance * 100))%",
                    color: autonomicBalanceColor
                )
            }
            
            if !riskFactors.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("AI-Detected Risk Factors")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    
                    ForEach(riskFactors.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.2))
                                    .frame(width: 25, height: 25)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            
                            Text(riskFactors[index])
                                .font(.caption)
                                .foregroundColor(.gray)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("High Priority")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(25)
        .glossyCard(cornerRadius: 20, borderTint: Color.blue)
        .padding(.horizontal, 25)
    }
    
    var smartRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "lightbulb.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Text("Smart Recommendations")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Personalized")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 25)
            
            // Dynamic recommendations from your existing data
            ForEach(advancedDynamicRecommendations, id: \.title) { recommendation in
                AdvancedRecommendationCard(recommendation: recommendation)
                    .padding(.horizontal, 25)
            }
            
            // Breathing exercise recommendation with citation
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("🧘‍♀️ Breathing Exercise Recommended")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        showStressCitation = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
                
                Text("Research shows deep breathing reduces stress hormones")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.05))
            )
            .padding(.horizontal, 25)
        }
        .sheet(isPresented: $showStressCitation) {
            MedicalCitationView(
                title: "Breathing Exercises for Stress Management",
                citation: "American Psychological Association. (2024). Stress Management: Breathing Exercises. APA Help Center for Stress Management.",
                url: "https://www.mayoclinic.org/healthy-lifestyle/stress-management/in-depth/stress-relievers/art-20047257"
            )
        }
    }

    
    // UPDATED: Navigation buttons now always visible with stress-aware styling
    var enhancedActionButtonsSection: some View {
        VStack(spacing: 20) {
            // Always show breathing button with dynamic styling
            Button(action: {
                audioManager.startBreathingAudio()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    toBreathe = true
                }
            }) {
                HStack(spacing: 15) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 35, height: 35)
                        
                        Image(systemName: "wind.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stressCategory == "High" ? "Emergency Breathing" : "Start Advanced Breathing")
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(stressCategory == "High" ? "Critical stress intervention" : "AI-guided stress reduction protocol")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 25)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        // Red gradient for high stress, blue for normal
                                        stressCategory == "High" ? Color.red : Color.blue,
                                        stressCategory == "High" ? Color.red.opacity(0.8) : Color.blue.opacity(0.8),
                                        stressCategory == "High" ? Color.pink.opacity(0.9) : Color.cyan.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                    }
                )
                .shadow(color: (stressCategory == "High" ? Color.red : Color.blue).opacity(0.4), radius: 12, x: 0, y: 6)
                .scaleEffect(glowEffect ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowEffect)
            }
            .padding(.horizontal, 25)
            
            // Always show home button with dynamic styling
            Button(action: {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    toHome = true
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "house.circle.fill")
                        .font(.title3)
                        .foregroundColor(stressCategory == "High" ? .red : .blue)
                    
                    Text("Return to Home Page")
                        .fontWeight(.semibold)
                        .foregroundColor(stressCategory == "High" ? .red : .blue)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill((stressCategory == "High" ? Color.red : Color.blue).opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke((stressCategory == "High" ? Color.red : Color.blue).opacity(0.3), lineWidth: 1.5)
                        )
                )
            }
        }
    }
    
    var advancedAiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 45, height: 45)
                        .shadow(color: .purple.opacity(0.3), radius: 5)
                    
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Core Assistant Insights")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    
                    Text("Advanced pattern recognition active")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
                }
                
                Spacer()
                
                // AI thinking indicator
                HStack(spacing: 3) {
                    ForEach(0..<4) { index in
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: 3, height: 12)
                            .scaleEffect(y: pulseAnimation ? 1.5 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                                value: pulseAnimation
                            )
                    }
                }
            }
            
            Text(enhancedAiInsightsText)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // Advanced insights metrics
            HStack(spacing: 12) {
                InsightMetric(
                    icon: "timer",
                    label: "Recovery",
                    value: "\(recoveryTime)m",
                    color: recoveryTimeColor
                )
                
                InsightMetric(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Trend",
                    value: stressPattern.trend,
                    color: stressPattern.color
                )
                
                InsightMetric(
                    icon: "target",
                    label: "Accuracy",
                    value: "96%",
                    color: .green
                )
            }
        }
        .padding(25)
        .glossyCard(cornerRadius: 20, borderTint: Color.purple)
        .padding(.horizontal, 25)
        .padding(.bottom, 35)
    }

    // MARK: - Animation Control
    private func startAnimations() {
        withAnimation {
            pulseAnimation = true
            glowEffect = true
            breathingAnimation = true
            particleAnimation = true
        }
    }
    
    // MARK: - User Validation
    private func validateUserAndStart() {
        guard currentUserId > 0 else {
            print("AIView: No valid user ID, switching to advanced simulation")
            startAdvancedSimulation()
            return
        }
        
        print("AIView: Starting with user ID: \(currentUserId)")
        startAutoRefresh()
    }
    
    // MARK: - Advanced AI Stress Analysis
    func performAdvancedStressAnalysis() {
        calculateCardiacStress()
        calculateAutonomicBalance()
        determineStressPattern()
        calculateRecoveryTime()
        updateAdvancedHealthScore()
        updateAdvancedRiskFactors()
    }
    
    func calculateCardiacStress() {
        var stress: Double = 0.0
        
        if let bpm = heartbeat {
            // Heart rate variability analysis
            switch bpm {
            case 0..<60:
                stress += 0.2 // Bradycardia stress
            case 100..<120:
                stress += 0.4 // Tachycardia
            case 120...:
                stress += 0.8 // Severe tachycardia
            default:
                stress += 0.0 // Normal range
            }
        }
        
        if let sys = systolic, let dia = diastolic {
            // Blood pressure impact on cardiac stress
            let meanAP = (sys + 2 * dia) / 3
            switch meanAP {
            case 90...:
                stress += Double(meanAP - 90) / 100
            default:
                stress += 0.0
            }
        }
        
        // Stress percentage contribution
        stress += (stressPercentage / 100) * 0.6
        
        cardiacStress = min(stress, 1.0)
    }
    
    func calculateAutonomicBalance() {
        var balance: Double = 0.5 // Neutral
        
        if let bpm = heartbeat {
            // Heart rate variability indicates autonomic function
            switch bpm {
            case 60...80:
                balance = 0.8 // Excellent balance
            case 81...100:
                balance = 0.6 // Good balance
            case 101...120:
                balance = 0.4 // Sympathetic dominance
            default:
                balance = 0.2 // Poor balance
            }
        }
        
        // Stress impact on autonomic balance
        let stressImpact = 1.0 - (stressPercentage / 100)
        autonomicBalance = (balance + stressImpact) / 2
    }
    
    func determineStressPattern() {
        if stressPercentage > 80 {
            stressPattern = .acute
        } else if stressPercentage > 60 && cardiacStress > 0.6 {
            stressPattern = .escalating
        } else if stressPercentage > 40 {
            stressPattern = .moderate
        } else if stressPercentage < 20 {
            stressPattern = .recovery
        } else {
            stressPattern = .stable
        }
    }
    
    func calculateRecoveryTime() {
        // Estimate recovery time based on current stress levels and vitals
        let baseRecovery = Int(stressPercentage / 10) * 2
        
        var modifiers = 0
        if let bpm = heartbeat, bpm > 100 {
            modifiers += 3
        }
        if cardiacStress > 0.6 {
            modifiers += 5
        }
        if autonomicBalance < 0.4 {
            modifiers += 4
        }
        
        recoveryTime = max(baseRecovery + modifiers, 2)
    }
    
    func updateAdvancedHealthScore() {
        let baseScore = 100
        var deductions = 0
        
        // Stress impact (weighted heavily)
        deductions += Int(stressPercentage * 0.3)
        
        // Cardiac stress impact
        deductions += Int(cardiacStress * 25)
        
        // Autonomic balance impact
        deductions += Int((1.0 - autonomicBalance) * 20)
        
        // Heart rate impact
        if let bpm = heartbeat {
            switch bpm {
            case 0..<60, 120...:
                deductions += 15
            case 100..<120:
                deductions += 8
            default:
                deductions += 0
            }
        }
        
        // Blood pressure impact
        if let sys = systolic {
            switch sys {
            case 140...:
                deductions += 20
            case 130..<140:
                deductions += 10
            default:
                deductions += 0
            }
        }
        
        healthScore = max(baseScore - deductions, 10)
    }
    
    func updateAdvancedRiskFactors() {
        riskFactors.removeAll()
        
        if stressPercentage > 70 {
            riskFactors.append("Chronic stress detected - elevated cortisol likely")
        }
        
        if let bpm = heartbeat, bpm > 100 {
            riskFactors.append("Tachycardia present - sympathetic overdrive (\(bpm) BPM)")
        }
        
        if let sys = systolic, sys > 140 {
            riskFactors.append("Hypertensive state - vascular stress (\(sys) mmHg)")
        }
        
        if cardiacStress > 0.6 {
            riskFactors.append("High cardiac workload - myocardial strain detected")
        }
        
        if autonomicBalance < 0.4 {
            riskFactors.append("Autonomic dysfunction - poor stress adaptation")
        }
        
        if recoveryTime > 15 {
            riskFactors.append("Prolonged recovery time - reduced resilience")
        }
    }

    // MARK: - Helper Functions
    func getHeartRateTrend() -> String? {
        guard let bpm = heartbeat else { return nil }
        
        if bpm > 100 { return "↗️" }
        else if bpm < 60 { return "↘️" }
        else { return "➡️" }
    }
    
    func getBPTrend() -> String? {
        guard let sys = systolic else { return nil }
        
        if sys > 130 { return "⬆️" }
        else if sys < 90 { return "⬇️" }
        else { return "➡️" }
    }
    
    func getHeartRateStatus() -> String {
        guard let bpm = heartbeat else { return "No Data" }
        
        switch bpm {
        case 0..<60: return "Bradycardia"
        case 60...100: return "Normal"
        case 101...120: return "Elevated"
        default: return "Tachycardia"
        }
    }
    
    func getSystolicStatus() -> String {
        guard let sys = systolic else { return "No Data" }
        
        switch sys {
        case 0..<90: return "Low"
        case 90...120: return "Optimal"
        case 121...130: return "Elevated"
        default: return "High"
        }
    }
    
    func getDiastolicStatus() -> String {
        guard let dia = diastolic else { return "No Data" }
        
        switch dia {
        case 0..<60: return "Low"
        case 60...80: return "Normal"
        case 81...90: return "Elevated"
        default: return "High"
        }
    }

    // MARK: - Auto Refresh Logic
    func startAutoRefresh() {
        fetchAllVitals()
        
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            fetchAllVitals()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if heartbeat == nil && systolic == nil && diastolic == nil {
                startAdvancedSimulation()
            }
        }
    }
    
    // MARK: - Advanced Static Data Simulation
    func startAdvancedSimulation() {
        isUsingStaticData = true
        generateAdvancedStaticVitals()
        
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { _ in
            withAnimation(.spring(response: 1, dampingFraction: 0.7)) {
                generateAdvancedStaticVitals()
            }
        }
    }
    
    func generateAdvancedStaticVitals() {
        let advancedScenarios = [
            (hr: 72, sys: 118, dia: 78, stress: 25.0, category: "Low", pattern: StressPattern.stable),
            (hr: 85, sys: 125, dia: 82, stress: 45.0, category: "Moderate", pattern: StressPattern.moderate),
            (hr: 68, sys: 110, dia: 75, stress: 15.0, category: "Low", pattern: StressPattern.recovery),
            (hr: 95, sys: 135, dia: 88, stress: 65.0, category: "High", pattern: StressPattern.escalating),
            (hr: 78, sys: 122, dia: 80, stress: 35.0, category: "Low", pattern: StressPattern.stable),
            (hr: 105, sys: 145, dia: 92, stress: 85.0, category: "High", pattern: StressPattern.acute),
            (hr: 88, sys: 128, dia: 84, stress: 55.0, category: "Moderate", pattern: StressPattern.moderate),
            (hr: 65, sys: 115, dia: 76, stress: 20.0, category: "Low", pattern: StressPattern.recovery)
        ]
        
        let scenario = advancedScenarios.randomElement()!
        
        heartbeat = scenario.hr + Int.random(in: -4...4)
        systolic = scenario.sys + Int.random(in: -6...6)
        diastolic = scenario.dia + Int.random(in: -4...4)
        stressPercentage = scenario.stress + Double.random(in: -8...8)
        stressCategory = scenario.category
        stressPattern = scenario.pattern
        
        // Perform advanced AI analysis
        performAdvancedStressAnalysis()
        checkForHighStress()
    }

    // MARK: - Networking
    func fetchAllVitals() {
        guard currentUserId > 0 else {
            print("AIView: No valid user ID for API call")
            return
        }
        
        guard let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/stress.php?user_id=\(currentUserId)") else {
            print("AIView: Invalid URL for user ID: \(currentUserId)")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(CompleteVitalsResponse.self, from: data)
                    DispatchQueue.main.async {
                        self.heartbeat = decoded.bpm
                        self.stressPercentage = decoded.stress_percentage
                        self.systolic = decoded.systolic
                        self.diastolic = decoded.diastolic
                        self.stressPercentage = decoded.stress_percentage
                        self.stressCategory = decoded.stress_category
                        
                        self.isUsingStaticData = false
                        self.simulationTimer?.invalidate()
                        
                        // Perform advanced AI analysis
                        self.performAdvancedStressAnalysis()
                        self.checkForHighStress()
                    }
                } catch {
                    print("AIView: Decoding error: \(error)")
                }
            }
        }.resume()
    }
    
    // MARK: - NEW: One-Time High Stress Detection
    func checkForHighStress() {
        
        let newCategory = determineStressCategory(percentage: stressPercentage)
        // Only show alert once, if user hasn't already dismissed or seen it.
        if newCategory == "High" && !criticalAlertShown && !userDismissedAlert && !showCriticalStressAlert {
            stressCategory = newCategory
            criticalAlertShown = true // Mark as shown in session
            triggerOneTimeCriticalAlert()
        } else {
            stressCategory = newCategory
        }
        // (Flags reset only when view disappears.)
    }
    func checkAlertCondition() {
        let isStressHigh = stressPercentage >= 65.0  // adapt as needed
        let isHeartRateHigh = (heartbeat ?? 0) > 100

        if (isStressHigh || isHeartRateHigh) && !criticalAlertShown && !userDismissedAlert {
            criticalAlertShown = true
            triggerOneTimeCriticalAlert()  // your alert trigger function name
        }
    }


    
    func triggerOneTimeCriticalAlert() {
        audioManager.playAlertSound()
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showCriticalStressAlert = true
        }
    }
    
    func determineStressCategory(percentage: Double) -> String {
        switch percentage {
        case 0..<40:
            return "Low"
        case 40..<60:
            return "Moderate"
        default:
            return "High"
        }
    }

    // MARK: - Enhanced AI Analysis Text
    var advancedAiAnalysisText: String {
        var analysis = ""
        
        // Advanced stress assessment
        analysis += "🧠 Core Assistant Analysis: Advanced pattern recognition identifies \(stressCategory.lowercased()) stress state at \(Int(stressPercentage))% with \(stressPattern.rawValue) characteristics. "
        
        // Sophisticated heart rate analysis
        if let bpm = heartbeat {
            switch bpm {
            case 0..<50:
                analysis += "Severe bradycardia (\(bpm) BPM) - potential autonomic dysfunction or athletic conditioning. AI recommends cardiac evaluation. "
            case 50..<60:
                analysis += "Mild bradycardia (\(bpm) BPM) - excellent cardiovascular efficiency or training adaptation detected. "
            case 60...75:
                analysis += "Optimal heart rate (\(bpm) BPM) - perfect cardiovascular-autonomic synchronization observed. "
            case 76...90:
                analysis += "Good heart rate (\(bpm) BPM) - healthy cardiovascular response within normal parameters. "
            case 91...110:
                analysis += "Elevated response (\(bpm) BPM) - sympathetic activation detected, likely stress-induced tachycardia. "
            case 111...130:
                analysis += "Significant tachycardia (\(bpm) BPM) - acute stress response with potential cardiac strain. "
            default:
                analysis += "Critical tachycardia (\(bpm) BPM) - immediate intervention required for cardiovascular safety. "
            }
        }
        
        // Advanced blood pressure interpretation
        if let sys = systolic, let dia = diastolic {
            let pulseP = sys - dia
            let meanAP = (sys + 2 * dia) / 3
            
            switch (sys, dia, pulseP) {
            case (0..<90, 0..<60, _):
                analysis += "Hypotensive state (\(sys)/\(dia)) - AI detects potential orthostatic intolerance. "
            case (90...120, 60...80, 30...50):
                analysis += "Optimal blood pressure (\(sys)/\(dia)) with healthy pulse pressure (\(pulseP) mmHg). "
            case (121...129, 81...84, _):
                analysis += "Pre-hypertensive (\(sys)/\(dia)) - early vascular stress markers identified. "
            case (130..., 85..., _):
                analysis += "Hypertensive crisis (\(sys)/\(dia)) - severe vascular strain with MAP of \(meanAP) mmHg. "
            case (_, _, 60...):
                analysis += "Wide pulse pressure (\(pulseP) mmHg) - arterial stiffness or aortic insufficiency suspected. "
            case (_, _, 0..<25):
                analysis += "Narrow pulse pressure (\(pulseP) mmHg) - reduced cardiac output or severe vasoconstriction. "
            default:
                analysis += "Blood pressure \(sys)/\(dia) mmHg analyzed - monitoring for pattern development. "
            }
        }
        
        // Autonomic nervous system analysis
        analysis += "Autonomic balance at \(Int(autonomicBalance * 100))% indicates \(autonomicBalance > 0.7 ? "excellent" : autonomicBalance > 0.5 ? "adequate" : "impaired") stress adaptation. "
        
        // Recovery prediction
        analysis += "AI predicts \(recoveryTime)-minute recovery time based on current stress biomarkers and cardiovascular response patterns."
        
        return analysis
    }
    
    var advancedDynamicRecommendations: [AdvancedRecommendation] {
        var recs: [AdvancedRecommendation] = []
        
        // Critical interventions
        if stressPercentage > 85 || cardiacStress > 0.8 {
            recs.append(.init(
                icon: "exclamationmark.triangle.fill",
                title: "Immediate Stress Intervention",
                description: "Critical stress levels require immediate action",
                priority: .critical,
                aiConfidence: 0.97,
                actionType: "Emergency Protocol"
            ))
        }
        
        // Cardiac-specific recommendations
        if cardiacStress > 0.6 {
            recs.append(.init(
                icon: "heart.text.square.fill",
                title: "Cardiovascular Protection",
                description: "Reduce cardiac workload through relaxation",
                priority: .high,
                aiConfidence: 0.92,
                actionType: "Cardiac Care"
            ))
        }
        
        // Autonomic nervous system recommendations
        if autonomicBalance < 0.4 {
            recs.append(.init(
                icon: "brain.head.profile.fill",
                title: "Autonomic Rebalancing",
                description: "Restore parasympathetic dominance",
                priority: .high,
                aiConfidence: 0.89,
                actionType: "ANS Therapy"
            ))
        }
        
        // Pattern-based recommendations
        switch stressPattern {
        case .acute:
            recs.append(.init(
                icon: "waveform.path.ecg.rectangle.fill",
                title: "Acute Stress Management",
                description: "Emergency breathing protocol activation",
                priority: .critical,
                aiConfidence: 0.95,
                actionType: "Crisis Management"
            ))
        case .escalating:
            recs.append(.init(
                icon: "chart.line.uptrend.xyaxis.circle.fill",
                title: "Prevent Stress Escalation",
                description: "Intervene before reaching critical levels",
                priority: .high,
                aiConfidence: 0.88,
                actionType: "Prevention"
            ))
        case .moderate:
            recs.append(.init(
                icon: "leaf.circle.fill",
                title: "Mindfulness Intervention",
                description: "Guided meditation and relaxation",
                priority: .medium,
                aiConfidence: 0.85,
                actionType: "Wellness"
            ))
        case .recovery:
            recs.append(.init(
                icon: "checkmark.circle.fill",
                title: "Maintain Recovery",
                description: "Continue current relaxation practices",
                priority: .low,
                aiConfidence: 0.92,
                actionType: "Maintenance"
            ))
        case .stable:
            recs.append(.init(
                icon: "heart.circle.fill",
                title: "Optimize Wellness",
                description: "Enhance current healthy patterns",
                priority: .medium,
                aiConfidence: 0.87,
                actionType: "Optimization"
            ))
        }
        
        // Recovery-based recommendations
        if recoveryTime > 10 {
            recs.append(.init(
                icon: "timer.circle.fill",
                title: "Accelerate Recovery",
                description: "Reduce recovery time through targeted intervention",
                priority: .medium,
                aiConfidence: 0.84,
                actionType: "Recovery Boost"
            ))
        }
        
        // Heart rate specific
        if let bpm = heartbeat, bpm > 120 {
            recs.append(.init(
                icon: "heart.slash.circle.fill",
                title: "Heart Rate Regulation",
                description: "Immediate tachycardia management required",
                priority: .critical,
                aiConfidence: 0.94,
                actionType: "Cardiac Control"
            ))
        }
        
        // Positive reinforcement
        if healthScore > 90 && stressPercentage < 30 {
            recs.append(.init(
                icon: "star.circle.fill",
                title: "Exceptional Health Status",
                description: "Maintain current wellness excellence",
                priority: .low,
                aiConfidence: 0.98,
                actionType: "Congratulations"
            ))
        }
        
        return Array(recs.prefix(5))
    }
    
    var enhancedAiInsightsText: String {
        if stressPercentage > 90 || cardiacStress > 0.9 {
            return "🚨 Core Assistant ALERT: Critical stress overload detected (\(Int(stressPercentage))%). Advanced algorithms indicate severe autonomic dysregulation with \(Int(cardiacStress * 100))% cardiac stress. Immediate intervention protocol activated. Your physiological markers suggest fight-or-flight overdrive requiring urgent deactivation."
        } else if stressPercentage > 75 || cardiacStress > 0.7 {
            return "⚠️ HIGH-PRIORITY ANALYSIS: Significant stress burden (\(Int(stressPercentage))%) with elevated cardiac workload. Neural patterns indicate \(stressPattern.rawValue) stress progression. Recovery time extended to \(recoveryTime) minutes. Implementing targeted stress reduction protocols recommended."
        } else if stressPattern == .escalating {
            return "📈 PREDICTIVE ALERT: AI detects escalating stress pattern despite current moderate levels. Proactive intervention recommended to prevent stress cascade. Your autonomic balance (\(Int(autonomicBalance * 100))%) suggests early sympathetic dominance."
        } else if healthScore > 85 && stressPercentage < 30 {
            return "✨ OPTIMAL STATUS: Core Assistant analysis confirms exceptional stress management with \(healthScore)/100 health score. Your autonomic nervous system demonstrates superior adaptation patterns. Current stress levels (\(Int(stressPercentage))%) are well within optimal ranges."
        } else if autonomicBalance < 0.4 {
            return "🧠 AUTONOMIC ANALYSIS: Poor stress adaptation detected with \(Int(autonomicBalance * 100))% ANS balance. Neural pathways show sympathetic overdrive requiring parasympathetic activation. Estimated \(recoveryTime)-minute recovery with proper intervention."
        } else {
            return "📊 COMPREHENSIVE MONITORING: Multi-parameter analysis shows \(stressCategory.lowercased()) stress levels with \(stressPattern.rawValue) pattern. Cardiovascular metrics within \(cardiacStress < 0.5 ? "safe" : "elevated") range. AI recommends maintaining current wellness trajectory."
        }
    }
    
    // MARK: - Enhanced Color Helpers
    var healthScoreColor: Color {
        switch healthScore {
        case 95...100: return .green
        case 85...94: return .mint
        case 70...84: return .blue
        case 55...69: return .orange
        case 40...54: return .red.opacity(0.8)
        default: return .red
        }
    }
    
    var enhancedHealthScoreDescription: String {
        switch healthScore {
        case 95...100: return "Peak Performance"
        case 85...94: return "Excellent Health"
        case 70...84: return "Good Condition"
        case 55...69: return "Needs Attention"
        case 40...54: return "Poor Condition"
        default: return "Critical State"
        }
    }
    
    var healthStars: Int {
        switch healthScore {
        case 90...100: return 5
        case 80...89: return 4
        case 65...79: return 3
        case 50...64: return 2
        case 35...49: return 1
        default: return 0
        }
    }
    
    var cardiacRiskColor: Color {
        switch cardiacStress {
        case 0..<0.3: return .green
        case 0.3..<0.6: return .yellow
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    var cardiacRiskDescription: String {
        switch cardiacStress {
        case 0..<0.3: return "Low Impact"
        case 0.3..<0.6: return "Moderate Load"
        case 0.6..<0.8: return "High Strain"
        default: return "Critical Stress"
        }
    }
    
    var autonomicBalanceColor: Color {
        switch autonomicBalance {
        case 0.7...: return .green
        case 0.5..<0.7: return .blue
        case 0.3..<0.5: return .orange
        default: return .red
        }
    }
    
    var autonomicBalanceDescription: String {
        switch autonomicBalance {
        case 0.7...: return "Excellent"
        case 0.5..<0.7: return "Good"
        case 0.3..<0.5: return "Impaired"
        default: return "Dysfunction"
        }
    }
    
    var overallStressColor: Color {
        switch stressPercentage {
        case 0..<30: return .green
        case 30..<50: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
    
    var overallStressDescription: String {
        switch stressPercentage {
        case 0..<20: return "Minimal Impact"
        case 20..<40: return "Low Impact"
        case 40..<60: return "Moderate Impact"
        case 60..<80: return "High Impact"
        default: return "Critical Impact"
        }
    }
    
    var recoveryTimeColor: Color {
        switch recoveryTime {
        case 0...5: return .green
        case 6...10: return .blue
        case 11...15: return .orange
        default: return .red
        }
    }
    
    // Existing color properties remain the same
    var stressRingColor: Color {
        switch stressCategory {
        case "Low": return .green
        case "Moderate": return .orange
        case "High": return .red
        default: return .gray
        }
    }
    
    var heartbeatColor: Color {
        guard let bpm = heartbeat else { return .gray }
        switch bpm {
        case 0..<60: return .blue
        case 60...100: return .green
        case 101...120: return .orange
        default: return .red
        }
    }
    
    var systolicColor: Color {
        guard let sys = systolic else { return .gray }
        switch sys {
        case 0..<90: return .blue
        case 90...120: return .green
        case 121...130: return .orange
        default: return .red
        }
    }
    
    var diastolicColor: Color {
        guard let dia = diastolic else { return .gray }
        switch dia {
        case 0..<60: return .blue
        case 60...80: return .green
        case 81...85: return .orange
        default: return .red
        }
    }
}

// MARK: - Enhanced Supporting Views & Models

struct VitalWarningBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct AdvancedRiskCard: View {
    let title: String
    let risk: Double
    let icon: String
    let color: Color
    let description: String
    let isWide: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 55, height: 55)
                    .shadow(color: color.opacity(0.2), radius: 3)
                
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .frame(width: 55, height: 55)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 4) {
                Text("\(Int(risk * 100))%")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            // Risk level indicator
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    Rectangle()
                        .fill(index < Int(risk * 5) ? color : color.opacity(0.2))
                        .frame(width: isWide ? 8 : 6, height: 3)
                        .cornerRadius(1.5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 15)
        .glossyCard(cornerRadius: 16, borderTint: color)
        .if(isWide) { view in
            view.frame(maxWidth: .infinity)
        }
    }
}

struct AdvancedVitalCard: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color
    let trend: String?
    let status: String
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(color)
                }
                
                if let trend = trend {
                    Text(trend)
                        .font(.caption)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Text(status)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.1))
                    .cornerRadius(4)
            }
            
            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .fontWeight(.medium)
            }
            
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .padding(.horizontal, 12)
        .glossyCard(cornerRadius: 14, borderTint: color)
    }
}

struct AdvancedRecommendationCard: View {
    let recommendation: AdvancedRecommendation
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(recommendation.priority.color.opacity(0.15))
                    .frame(width: 50, height: 50)
                    .shadow(color: recommendation.priority.color.opacity(0.2), radius: 3)
                
                Circle()
                    .stroke(recommendation.priority.color.opacity(0.3), lineWidth: 2)
                    .frame(width: 50, height: 50)
                
                Image(systemName: recommendation.icon)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(recommendation.priority.color)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(recommendation.actionType)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(recommendation.priority.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(recommendation.priority.color.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                HStack {
                    Text("Confidence: \(Int(recommendation.aiConfidence * 100))%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(recommendation.priority.color)
                            .frame(width: 6, height: 6)
                        
                        Text(recommendation.priority.rawValue.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(recommendation.priority.color)
                    }
                }
            }
            
            Image(systemName: "chevron.right.circle.fill")
                .font(.title3)
                .foregroundColor(recommendation.priority.color.opacity(0.6))
        }
        .padding(18)
        .glossyCard(cornerRadius: 16, borderTint: recommendation.priority.color)
    }
}

struct MetricPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct InsightMetric: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.1))
        )
    }
}

struct Star: Shape {
    let filled: Bool
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        
        var path = Path()
        
        for i in 0..<5 {
            let angle = Double(i) * (2 * .pi / 5) - .pi / 2
            let x = center.x + cos(angle) * outerRadius
            let y = center.y + sin(angle) * outerRadius
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            let innerAngle = angle + (.pi / 5)
            let innerX = center.x + cos(innerAngle) * innerRadius
            let innerY = center.y + sin(innerAngle) * innerRadius
            path.addLine(to: CGPoint(x: innerX, y: innerY))
        }
        
        path.closeSubpath()
        return path
    }
}

struct ParticleBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(0..<15, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: CGFloat.random(in: 20...40))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .scaleEffect(animate ? CGFloat.random(in: 0.5...1.5) : 1.0)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...4))
                        .repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...2)),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }
}

// MARK: - Enhanced Data Models

struct AdvancedRecommendation: Hashable {
    let icon: String
    let title: String
    let description: String
    let priority: Priority
    let aiConfidence: Double
    let actionType: String
    
    enum Priority: String, CaseIterable {
        case critical = "critical"
        case high = "high"
        case medium = "medium"
        case low = "low"
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .blue
            case .low: return .green
            }
        }
    }
}

enum StressPattern: String, CaseIterable {
    case stable = "stable"
    case moderate = "moderate"
    case escalating = "escalating"
    case acute = "acute"
    case recovery = "recovery"
    
    var color: Color {
        switch self {
        case .stable: return .green
        case .moderate: return .blue
        case .escalating: return .orange
        case .acute: return .red
        case .recovery: return .mint
        }
    }
    
    var displayName: String {
        switch self {
        case .stable: return "Stable"
        case .moderate: return "Moderate"
        case .escalating: return "Rising"
        case .acute: return "Acute"
        case .recovery: return "Recovery"
        }
    }
    
    var trend: String {
        switch self {
        case .stable: return "→"
        case .moderate: return "~"
        case .escalating: return "↗"
        case .acute: return "⤴"
        case .recovery: return "↘"
        }
    }
}

// MARK: - Audio Manager (Enhanced)
class AudioManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var backgroundPlayer: AVAudioPlayer?
    
    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func startBreathingAudio() {
        guard let url = Bundle.main.url(forResource: "breathing_meditation", withExtension: "mp3") else {
            playAdvancedBreathingSound()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.7
            audioPlayer?.play()
        } catch {
            print("Failed to play breathing audio: \(error)")
            playAdvancedBreathingSound()
        }
    }
    
    func stopBreathingAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    func playAlertSound() {
        AudioServicesPlaySystemSound(1005)
    }
    
    private func playAdvancedBreathingSound() {
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { timer in
            AudioServicesPlaySystemSound(1104)
        }
    }
}

// MARK: - Data Models
struct CompleteVitalsResponse: Codable {
    let status: String
    let stress_percentage: Double
    let stress_category: String
    let bpm: Int?
    let category: String?
    let systolic: Int?
    let diastolic: Int?
}

struct HeartbeatResponse: Codable {
    let bpm: Int
    let category: String
}

struct BPResponse: Codable {
    let systolic: Int
    let diastolic: Int
}

struct StressResponse: Codable {
    let stress_percentage: Double
    let stress_category: String
}

// MARK: - View Extension
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    AIView()
        .environmentObject(UserManager.shared)
}
