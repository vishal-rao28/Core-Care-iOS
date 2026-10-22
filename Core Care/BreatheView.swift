import SwiftUI
import AVFoundation

// MARK: - Breathing Phase Definition
enum BreathPhaseType: String, Equatable {
    case inhale = "Inhale"
    case holdFull = "Hold"
    case exhale = "Exhale"
    case holdEmpty = "Rest"
}

struct BreathPhase: Identifiable, Equatable {
    let id = UUID()
    let type: BreathPhaseType
    let duration: Double
    let instruction: String
    let subInstruction: String
}

// MARK: - Advanced Breathing Technique Model
enum BreathingTechnique: String, CaseIterable, Identifiable {
    case box = "Box Breathing"
    case relax478 = "4-7-8 Relax"
    case coherence = "Resonance Coherence"
    case quickReset = "Vagal Calm"
    
    var id: String { rawValue }
    
    var subtitle: String {
        switch self {
        case .box: return "4s • 4s • 4s • 4s"
        case .relax478: return "4s • 7s • 8s"
        case .coherence: return "5.5s • 5.5s"
        case .quickReset: return "4s • 6s"
        }
    }
    
    var tag: String {
        switch self {
        case .box: return "Autonomic Reset"
        case .relax478: return "Deep Calm"
        case .coherence: return "Peak HRV"
        case .quickReset: return "Acute Relief"
        }
    }
    
    var clinicalDescription: String {
        switch self {
        case .box:
            return "Equal-ratio breathing used by cardiologists and tactical athletes to balance the sympathetic and parasympathetic nervous systems, lower cortisol, and stabilize acute heart rate fluctuations."
        case .relax478:
            return "Dr. Andrew Weil's clinical relaxation protocol. Extended exhalation stimulates the vagus nerve, rapidly reducing sympathetic nervous activity, lowering blood pressure, and quieting racing thoughts."
        case .coherence:
            return "Resonant frequency breathing (~5.5 breaths per minute) that synchronizes heart rate variability (HRV) with respiration, maximizing baroreceptor sensitivity and cardiovascular rhythm efficiency."
        case .quickReset:
            return "Extended exhalation triggers the baroreflex mechanism, sending immediate inhibitory signals to the heart's sinoatrial (SA) node to calm an elevated heart rate rapidly."
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .box: return Color(red: 0.18, green: 0.65, blue: 0.85) // Crisp Aqua
        case .relax478: return Color(red: 0.45, green: 0.38, blue: 0.92) // Calming Purple
        case .coherence: return Color(red: 0.12, green: 0.72, blue: 0.62) // Healing Teal
        case .quickReset: return Color(red: 0.22, green: 0.68, blue: 0.45) // Soothing Emerald
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .box: return Color(red: 0.30, green: 0.50, blue: 0.95)
        case .relax478: return Color(red: 0.68, green: 0.35, blue: 0.85)
        case .coherence: return Color(red: 0.10, green: 0.55, blue: 0.80)
        case .quickReset: return Color(red: 0.15, green: 0.55, blue: 0.50)
        }
    }
    
    var phases: [BreathPhase] {
        switch self {
        case .box:
            return [
                BreathPhase(type: .inhale, duration: 4.0, instruction: "Inhale deeply", subInstruction: "Expand your chest smoothly through your nose"),
                BreathPhase(type: .holdFull, duration: 4.0, instruction: "Hold breath", subInstruction: "Keep throat relaxed, feel your heart steady"),
                BreathPhase(type: .exhale, duration: 4.0, instruction: "Exhale slowly", subInstruction: "Release all air through parted lips"),
                BreathPhase(type: .holdEmpty, duration: 4.0, instruction: "Rest & center", subInstruction: "Pause naturally before the next cycle")
            ]
        case .relax478:
            return [
                BreathPhase(type: .inhale, duration: 4.0, instruction: "Inhale quietly", subInstruction: "Breathe in through nose for 4 seconds"),
                BreathPhase(type: .holdFull, duration: 7.0, instruction: "Hold gently", subInstruction: "Retain air comfortably for 7 seconds"),
                BreathPhase(type: .exhale, duration: 8.0, instruction: "Exhale completely", subInstruction: "Whoosh exhale through mouth for 8 seconds")
            ]
        case .coherence:
            return [
                BreathPhase(type: .inhale, duration: 5.5, instruction: "Smooth inhale", subInstruction: "Slow 5.5s breath to synchronize HRV rhythm"),
                BreathPhase(type: .exhale, duration: 5.5, instruction: "Effortless exhale", subInstruction: "Slow 5.5s release to stimulate vagal resonance")
            ]
        case .quickReset:
            return [
                BreathPhase(type: .inhale, duration: 4.0, instruction: "Inhale steadily", subInstruction: "Gentle 4s intake of calm air"),
                BreathPhase(type: .exhale, duration: 6.0, instruction: "Long slow exhale", subInstruction: "6s prolonged exhalation to lower heart rate")
            ]
        }
    }
    
    var cycleDuration: Double {
        phases.reduce(0) { $0 + $1.duration }
    }
}

// MARK: - Main BreatheView
struct BreatheView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismissEnvironment
    @EnvironmentObject var userManager: UserManager
    
    // Optional callbacks & configuration
    var initialTechnique: BreathingTechnique = .coherence
    var onSessionComplete: ((Bool) -> Void)? = nil
    var onSessionEnd: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    
    // Session state
    @State private var selectedTechnique: BreathingTechnique = .coherence
    @State private var sessionTargetMinutes: Int = 5 // 2, 5, 10
    @State private var sessionSecondsRemaining: Double = 300
    @State private var currentPhaseIndex: Int = 0
    @State private var phaseElapsedSeconds: Double = 0.0
    @State private var isPaused: Bool = false
    @State private var isMuted: Bool = false
    @State private var hapticsEnabled: Bool = true
    @State private var completedCycles: Int = 0
    
    // UI animations & modals
    @State private var breathingScale: CGFloat = 1.0
    @State private var showInfoSheet: Bool = false
    @State private var showCompletionSummary: Bool = false
    @State private var auraAngle: Double = 0
    
    // Navigation routes
    @State private var goToAI: Bool = false
    @State private var goToHome: Bool = false
    @State private var goToHRCheck: Bool = false
    
    // Timers & Audio
    @State private var tickerTimer: Timer?
    @State private var audioPlayer: AVAudioPlayer?
    
    // Haptic engines
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let notifyHaptic = UINotificationFeedbackGenerator()
    
    private var currentUserId: Int {
        userManager.currentUserId ?? 0
    }
    
    private var currentPhase: BreathPhase {
        let phases = selectedTechnique.phases
        guard currentPhaseIndex < phases.count else { return phases[0] }
        return phases[currentPhaseIndex]
    }
    
    private var totalSessionSeconds: Double {
        Double(sessionTargetMinutes * 60)
    }
    
    private var overallProgress: Double {
        guard totalSessionSeconds > 0 else { return 0 }
        return min(1.0, max(0.0, (totalSessionSeconds - sessionSecondsRemaining) / totalSessionSeconds))
    }
    
    private var phaseProgress: Double {
        guard currentPhase.duration > 0 else { return 0 }
        return min(1.0, max(0.0, phaseElapsedSeconds / currentPhase.duration))
    }
    
    private var phaseSecondsRemaining: Double {
        max(0.0, currentPhase.duration - phaseElapsedSeconds)
    }
    
    var body: some View {
        ZStack {
            // Adaptive ambient canvas
            Color.appBackground
                .ignoresSafeArea()
            
            // Subtle glowing ambient orbs
            ambientAuraBackground
            
            if goToHRCheck {
                HRCheckView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .environmentObject(userManager)
            } else if goToAI {
                AIView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .environmentObject(userManager)
            } else if goToHome {
                HomePageView(userId: currentUserId)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    .environmentObject(userManager)
            } else {
                mainContent
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .slide
                    ))
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            selectedTechnique = initialTechnique
            sessionSecondsRemaining = Double(sessionTargetMinutes * 60)
            setupAudio()
            startSessionEngine()
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: true)) {
                auraAngle = 360
            }
        }
        .onDisappear {
            teardownEngine()
        }
        .sheet(isPresented: $showInfoSheet) {
            techniqueInfoSheet
        }
        .sheet(isPresented: $showCompletionSummary) {
            completionSummaryView
        }
    }
    
    // MARK: - Ambient Background
    private var ambientAuraBackground: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            
            ZStack {
                // Top-right glowing gradient orb
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                selectedTechnique.primaryColor.opacity(colorScheme == .dark ? 0.22 : 0.15),
                                selectedTechnique.secondaryColor.opacity(colorScheme == .dark ? 0.12 : 0.05),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: w * 0.55
                        )
                    )
                    .frame(width: w * 0.9, height: w * 0.9)
                    .position(x: w * 0.85, y: h * 0.25)
                    .blur(radius: 50)
                
                // Bottom-left complementary orb
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                selectedTechnique.secondaryColor.opacity(colorScheme == .dark ? 0.20 : 0.12),
                                selectedTechnique.primaryColor.opacity(colorScheme == .dark ? 0.10 : 0.04),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: w * 0.6
                        )
                    )
                    .frame(width: w * 0.95, height: w * 0.95)
                    .position(x: w * 0.15, y: h * 0.75)
                    .blur(radius: 60)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Main Content Layout
    private var mainContent: some View {
        GeometryReader { geo in
            let safeTop = max(geo.safeAreaInsets.top, 44)
            let safeBottom = max(geo.safeAreaInsets.bottom, 20)
            
            VStack(spacing: 0) {
                // Pinned Top Navigation Bar
                topNavigationBar(safeTop: safeTop)
                
                // Scrollable Body
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Technique Selector Pills
                        techniqueSelectorBar
                        
                        // Technique Subtitle & Ratio Badge
                        techniqueHeaderBadge
                        
                        // Central Interactive Visualizer
                        centralBreathingVisualizer(size: min(geo.size.width * 0.78, 290))
                            .padding(.vertical, 8)
                        
                        // Phase Instruction Typography
                        phaseInstructionCard
                        
                        // Live Session Metrics (Time remaining, cycles, coherence)
                        liveSessionMetricsCard
                        
                        // Primary Session Controls (Reset, Play/Pause, Duration)
                        primaryControlsSection
                            .padding(.top, 4)
                            .padding(.bottom, safeBottom + 24)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - Top Navigation Bar
    private func topNavigationBar(safeTop: CGFloat) -> some View {
        HStack(spacing: 12) {
            // Back / Close Button
            Button {
                handleDismissAction()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 42, height: 42)
                        .overlay(
                            Circle()
                                .stroke(Color.cardBorder, lineWidth: 1)
                        )
                        .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.textPrimary)
                }
            }
            
            Spacer()
            
            // Screen Title & Tag
            VStack(spacing: 2) {
                Text("Advanced Breathing")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textPrimary)
                
                Text("VAGAL & CARDIAC REGULATION")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundColor(selectedTechnique.primaryColor)
                    .tracking(1.2)
            }
            
            Spacer()
            
            // Right Action Controls: Haptics & Audio Mute
            HStack(spacing: 8) {
                // Haptics Toggle
                Button {
                    hapticsEnabled.toggle()
                    if hapticsEnabled {
                        mediumHaptic.impactOccurred()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.cardBackground)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(hapticsEnabled ? selectedTechnique.primaryColor.opacity(0.4) : Color.cardBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 2)
                        
                        Image(systemName: hapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(hapticsEnabled ? selectedTechnique.primaryColor : Color.textSecondary)
                    }
                }
                
                // Audio Toggle
                Button {
                    isMuted.toggle()
                    if isMuted {
                        audioPlayer?.pause()
                    } else {
                        audioPlayer?.play()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.cardBackground)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(!isMuted ? selectedTechnique.primaryColor.opacity(0.4) : Color.cardBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 2)
                        
                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(!isMuted ? selectedTechnique.primaryColor : Color.textSecondary)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, safeTop + 4)
        .padding(.bottom, 10)
        .background(
            Color.appBackground.opacity(0.85)
                .background(.ultraThinMaterial)
        )
    }
    
    // MARK: - Technique Selector Bar
    private var techniqueSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BreathingTechnique.allCases) { technique in
                    let isSelected = (technique == selectedTechnique)
                    
                    Button {
                        switchTechnique(to: technique)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(technique.primaryColor)
                                .frame(width: 8, height: 8)
                                .opacity(isSelected ? 1.0 : 0.6)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(technique.rawValue)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundColor(isSelected ? (colorScheme == .dark ? .white : Color.textPrimary) : Color.textSecondary)
                                
                                Text(technique.subtitle)
                                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                                    .foregroundColor(isSelected ? selectedTechnique.primaryColor : Color.textTertiary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(isSelected ? selectedTechnique.primaryColor.opacity(colorScheme == .dark ? 0.22 : 0.12) : Color.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? selectedTechnique.primaryColor.opacity(0.7) : Color.cardBorder, lineWidth: isSelected ? 1.5 : 1)
                        )
                        .shadow(color: isSelected ? selectedTechnique.primaryColor.opacity(0.2) : Color.cardShadow, radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Technique Header Badge & Info
    private var techniqueHeaderBadge: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(selectedTechnique.primaryColor)
                
                Text(selectedTechnique.tag)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(selectedTechnique.primaryColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(selectedTechnique.primaryColor.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(selectedTechnique.primaryColor.opacity(0.3), lineWidth: 1)
            )
            
            Text("•  \(selectedTechnique.subtitle)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color.textSecondary)
            
            Spacer()
            
            Button {
                showInfoSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text("Protocol Info")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                }
                .foregroundColor(selectedTechnique.primaryColor)
            }
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Central Breathing Visualizer
    private func centralBreathingVisualizer(size: CGFloat) -> some View {
        ZStack {
            // Concentric Harmonic Rings (expanding with breath scale)
            ForEach(1...3, id: \.self) { ringIndex in
                let factor = CGFloat(ringIndex) * 0.22
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                selectedTechnique.primaryColor.opacity(Double(4 - ringIndex) * 0.12),
                                selectedTechnique.secondaryColor.opacity(Double(4 - ringIndex) * 0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: size * (0.8 + factor), height: size * (0.8 + factor))
                    .scaleEffect(breathingScale)
                    .opacity(isPaused ? 0.35 : 1.0)
            }
            
            // Ambient Aura Halo behind core
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            selectedTechnique.primaryColor.opacity(colorScheme == .dark ? 0.35 : 0.22),
                            selectedTechnique.secondaryColor.opacity(0.0)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size * 1.05, height: size * 1.05)
                .scaleEffect(breathingScale)
                .blur(radius: 12)
            
            // Phase Progress Circular Track
            Circle()
                .stroke(
                    Color.appFill,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: size * 0.88, height: size * 0.88)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(phaseProgress))
                .stroke(
                    AngularGradient(
                        colors: [
                            selectedTechnique.primaryColor.opacity(0.6),
                            selectedTechnique.primaryColor,
                            selectedTechnique.secondaryColor
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .frame(width: size * 0.88, height: size * 0.88)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: phaseProgress)
            
            // Central Frosted Core Orb
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            selectedTechnique.primaryColor.opacity(colorScheme == .dark ? 0.25 : 0.15),
                            Color.cardBackground.opacity(0.95)
                        ]),
                        center: .topLeading,
                        startRadius: 10,
                        endRadius: size * 0.45
                    )
                )
                .frame(width: size * 0.74, height: size * 0.74)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(colorScheme == .dark ? 0.25 : 0.6),
                                    selectedTechnique.primaryColor.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: selectedTechnique.primaryColor.opacity(0.2), radius: 14, x: 0, y: 6)
                .scaleEffect(breathingScale)
            
            // Central Typography & Animated Phase Countdown
            VStack(spacing: 4) {
                // Phase Tag
                Text(currentPhase.type.rawValue.uppercased())
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(selectedTechnique.primaryColor)
                    .tracking(2.5)
                
                // Countdown Seconds
                Text(String(format: "%.0fs", ceil(phaseSecondsRemaining)))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textPrimary)
                    .monospacedDigit()
                
                // Technique Name Subtitle
                HStack(spacing: 4) {
                    Circle()
                        .fill(isPaused ? Color.orange : selectedTechnique.primaryColor)
                        .frame(width: 6, height: 6)
                    
                    Text(isPaused ? "Paused" : "Cycle \(completedCycles + 1)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                }
            }
        }
        .frame(width: size * 1.25, height: size * 1.25)
    }
    
    // MARK: - Phase Instruction Card
    private var phaseInstructionCard: some View {
        VStack(spacing: 4) {
            Text(currentPhase.instruction)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Color.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(currentPhase.subInstruction)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Live Session Metrics Card
    private var liveSessionMetricsCard: some View {
        VStack(spacing: 12) {
            // Metric Pills Grid
            HStack(spacing: 12) {
                // Time Remaining
                VStack(alignment: .leading, spacing: 3) {
                    Text("TIME REMAINING")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textTertiary)
                        .tracking(0.8)
                    
                    Text(timeString(from: Int(sessionSecondsRemaining)))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textPrimary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                
                // Completed Cycles
                VStack(alignment: .leading, spacing: 3) {
                    Text("COMPLETED CYCLES")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textTertiary)
                        .tracking(0.8)
                    
                    Text("\(completedCycles)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(selectedTechnique.primaryColor)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                
                // Coherence / Vagal Indicator
                VStack(alignment: .leading, spacing: 3) {
                    Text("VAGAL TONE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textTertiary)
                        .tracking(0.8)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(vagalToneColor)
                        
                        Text(vagalToneStatus)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(vagalToneColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
            }
            
            // Overall Session Progress Bar
            VStack(spacing: 6) {
                GeometryReader { barProxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.appFill)
                            .frame(height: 7)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [selectedTechnique.primaryColor, selectedTechnique.secondaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(7, barProxy.size.width * CGFloat(overallProgress)), height: 7)
                            .animation(.linear(duration: 0.1), value: overallProgress)
                    }
                }
                .frame(height: 7)
                
                HStack {
                    Text("Session Progress")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color.textTertiary)
                    
                    Spacer()
                    
                    Text("\(Int(overallProgress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(selectedTechnique.primaryColor)
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    private var vagalToneStatus: String {
        if completedCycles < 2 {
            return "Init"
        } else if completedCycles < 5 {
            return "Active"
        } else if completedCycles < 10 {
            return "Resonant"
        } else {
            return "Peak"
        }
    }
    
    private var vagalToneColor: Color {
        if completedCycles < 2 {
            return Color.textSecondary
        } else if completedCycles < 5 {
            return Color.statusInfo
        } else {
            return Color.statusSuccess
        }
    }
    
    // MARK: - Primary Controls Section
    private var primaryControlsSection: some View {
        VStack(spacing: 16) {
            // Main Control Buttons: Reset, Play/Pause, Finish
            HStack(spacing: 24) {
                // Reset / Rewind Button
                Button {
                    resetSession()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.cardBackground)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.cardBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.textPrimary)
                    }
                }
                
                // Play / Pause Master Button
                Button {
                    togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        selectedTechnique.primaryColor,
                                        selectedTechnique.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.3 : 0.6), lineWidth: 2)
                            )
                            .shadow(color: selectedTechnique.primaryColor.opacity(0.4), radius: 12, x: 0, y: 6)
                        
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(isPaused ? 0.96 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                
                // End / Complete Button
                Button {
                    handleSessionEndManual()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.cardBackground)
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.cardBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.cardShadow, radius: 4, x: 0, y: 2)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(selectedTechnique.primaryColor)
                    }
                }
            }
            
            // Duration Target Chips (2m, 5m, 10m)
            HStack(spacing: 10) {
                Text("Target:")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.textTertiary)
                
                ForEach([2, 5, 10], id: \.self) { minutes in
                    let isTarget = (minutes == sessionTargetMinutes)
                    
                    Button {
                        setTargetDuration(minutes: minutes)
                    } label: {
                        Text("\(minutes) min")
                            .font(.system(size: 11, weight: isTarget ? .bold : .medium, design: .rounded))
                            .foregroundColor(isTarget ? (colorScheme == .dark ? .white : Color.textPrimary) : Color.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(isTarget ? selectedTechnique.primaryColor.opacity(colorScheme == .dark ? 0.25 : 0.15) : Color.cardBackground)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isTarget ? selectedTechnique.primaryColor : Color.cardBorder, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - Engine & State Management
    
    private func startSessionEngine() {
        tickerTimer?.invalidate()
        tickerTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard !isPaused else { return }
            
            // Update phase progression
            phaseElapsedSeconds += 0.05
            
            // Compute animated breathing scale based on current phase progress
            updateBreathingScale()
            
            // Decrement session timer
            if sessionSecondsRemaining > 0.05 {
                sessionSecondsRemaining -= 0.05
            } else {
                sessionSecondsRemaining = 0
                handleNaturalSessionCompletion()
                return
            }
            
            // Check if phase boundary reached
            if phaseElapsedSeconds >= currentPhase.duration {
                advanceToNextPhase()
            }
        }
    }
    
    private func updateBreathingScale() {
        let t = phaseProgress
        let targetScale: CGFloat
        
        switch currentPhase.type {
        case .inhale:
            // Smooth expansion from 0.85 to 1.25
            targetScale = 0.85 + CGFloat(easeInOut(t)) * 0.40
        case .holdFull:
            // Gentle subtle micro-shimmer at peak
            targetScale = 1.25 + CGFloat(sin(phaseElapsedSeconds * 2.0)) * 0.015
        case .exhale:
            // Smooth contraction from 1.25 down to 0.85
            targetScale = 1.25 - CGFloat(easeInOut(t)) * 0.40
        case .holdEmpty:
            // Steady rested baseline
            targetScale = 0.85
        }
        
        breathingScale = targetScale
    }
    
    private func easeInOut(_ t: Double) -> Double {
        return t * t * (3.0 - 2.0 * t)
    }
    
    private func advanceToNextPhase() {
        phaseElapsedSeconds = 0.0
        let phases = selectedTechnique.phases
        let nextIndex = currentPhaseIndex + 1
        
        if nextIndex >= phases.count {
            currentPhaseIndex = 0
            completedCycles += 1
            triggerHaptic(for: .inhale)
        } else {
            currentPhaseIndex = nextIndex
            triggerHaptic(for: currentPhase.type)
        }
    }
    
    private func triggerHaptic(for phaseType: BreathPhaseType) {
        guard hapticsEnabled else { return }
        switch phaseType {
        case .inhale:
            mediumHaptic.impactOccurred(intensity: 0.8)
        case .holdFull:
            softHaptic.impactOccurred(intensity: 0.5)
        case .exhale:
            mediumHaptic.impactOccurred(intensity: 0.9)
        case .holdEmpty:
            softHaptic.impactOccurred(intensity: 0.4)
        }
    }
    
    private func switchTechnique(to newTechnique: BreathingTechnique) {
        selectedTechnique = newTechnique
        currentPhaseIndex = 0
        phaseElapsedSeconds = 0.0
        breathingScale = 0.85
        if hapticsEnabled {
            mediumHaptic.impactOccurred()
        }
    }
    
    private func togglePlayPause() {
        isPaused.toggle()
        if hapticsEnabled {
            softHaptic.impactOccurred()
        }
        if isPaused {
            audioPlayer?.pause()
        } else {
            if !isMuted {
                audioPlayer?.play()
            }
        }
    }
    
    private func resetSession() {
        isPaused = true
        currentPhaseIndex = 0
        phaseElapsedSeconds = 0.0
        sessionSecondsRemaining = Double(sessionTargetMinutes * 60)
        completedCycles = 0
        breathingScale = 0.85
        if hapticsEnabled {
            softHaptic.impactOccurred()
        }
    }
    
    private func setTargetDuration(minutes: Int) {
        sessionTargetMinutes = minutes
        sessionSecondsRemaining = Double(minutes * 60)
        currentPhaseIndex = 0
        phaseElapsedSeconds = 0.0
        completedCycles = 0
        if hapticsEnabled {
            softHaptic.impactOccurred()
        }
    }
    
    private func handleNaturalSessionCompletion() {
        tickerTimer?.invalidate()
        tickerTimer = nil
        stopAudio()
        if hapticsEnabled {
            notifyHaptic.notificationOccurred(.success)
        }
        onSessionComplete?(true)
        showCompletionSummary = true
    }
    
    private func handleSessionEndManual() {
        tickerTimer?.invalidate()
        tickerTimer = nil
        stopAudio()
        onSessionEnd?()
        showCompletionSummary = true
    }
    
    private func handleDismissAction() {
        teardownEngine()
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismissEnvironment()
            goToAI = true
        }
    }
    
    private func teardownEngine() {
        tickerTimer?.invalidate()
        tickerTimer = nil
        stopAudio()
    }
    
    // MARK: - Audio Handling
    private func setupAudio() {
        if let path = Bundle.main.path(forResource: "breathing_music", ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.volume = 0.4
                if !isMuted && !isPaused {
                    audioPlayer?.play()
                }
            } catch {
                print("Error setting up breathing audio: \(error)")
            }
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    private func timeString(from totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Protocol Info Sheet
    private var techniqueInfoSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(selectedTechnique.rawValue)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Color.textPrimary)
                            
                            Spacer()
                            
                            Text(selectedTechnique.subtitle)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(selectedTechnique.primaryColor)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(selectedTechnique.primaryColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        
                        Text(selectedTechnique.tag.uppercased())
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(selectedTechnique.primaryColor)
                            .tracking(1.0)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cardBorder, lineWidth: 1)
                    )
                    
                    // Physiological Mechanism
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cardiovascular Mechanism")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textPrimary)
                        
                        Text(selectedTechnique.clinicalDescription)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color.textSecondary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cardBorder, lineWidth: 1)
                    )
                    
                    // Phase breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Phase Breakdown")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textPrimary)
                        
                        ForEach(selectedTechnique.phases) { phase in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(selectedTechnique.primaryColor)
                                    .frame(width: 8, height: 8)
                                
                                Text(phase.type.rawValue)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.textPrimary)
                                    .frame(width: 70, alignment: .leading)
                                
                                Text("\(Int(phase.duration))s")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(selectedTechnique.primaryColor)
                                    .frame(width: 32, alignment: .leading)
                                
                                Text(phase.instruction)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.textSecondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.cardBorder, lineWidth: 1)
                    )
                }
                .padding(20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Clinical Protocol")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showInfoSheet = false
                    }
                    .foregroundColor(selectedTechnique.primaryColor)
                }
            }
        }
    }
    
    // MARK: - Completion Summary Modal
    private var completionSummaryView: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Celebration Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [selectedTechnique.primaryColor, selectedTechnique.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)
                        .shadow(color: selectedTechnique.primaryColor.opacity(0.4), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 38))
                        .foregroundColor(.white)
                }
                .padding(.top, 16)
                
                // Titles
                VStack(spacing: 4) {
                    Text("Session Completed 🎉")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color.textPrimary)
                    
                    Text("Your parasympathetic nervous system is now engaged.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                // Metrics summary card
                HStack(spacing: 12) {
                    summaryTile(title: "DURATION", value: "\(Int((totalSessionSeconds - sessionSecondsRemaining) / 60))m \(Int((totalSessionSeconds - sessionSecondsRemaining).truncatingRemainder(dividingBy: 60)))s")
                    summaryTile(title: "CYCLES", value: "\(completedCycles)")
                    summaryTile(title: "EST. HRV BOOST", value: "+24%")
                }
                .padding(.horizontal, 20)
                
                // Next action recommendation
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(selectedTechnique.primaryColor)
                        Text("Recommended Clinical Follow-up")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.textPrimary)
                    }
                    Text("Measure your heart rate now to verify vagal slowing and record your post-breathing recovery metrics.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(14)
                .background(Color.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 10) {
                    // Check Heart Rate Now
                    Button {
                        showCompletionSummary = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            goToHRCheck = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                            Text("Check Heart Rate Now")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.statusError, Color.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.statusError.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                    
                    // Return to AI Stress Analysis
                    Button {
                        showCompletionSummary = false
                        handleDismissAction()
                    } label: {
                        Text("Return to Health Analysis")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Color.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.cardBorder, lineWidth: 1)
                            )
                    }
                    
                    // Go to Home
                    Button {
                        showCompletionSummary = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            goToHome = true
                        }
                    } label: {
                        Text("Go to Dashboard")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.textSecondary)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func summaryTile(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(Color.textTertiary)
                .tracking(0.6)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(selectedTechnique.primaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Backward Compatibility Wrapper
struct EnhancedBreatheView: View {
    @EnvironmentObject var userManager: UserManager
    
    var onSessionComplete: ((Bool) -> Void)? = nil
    var onSessionEnd: (() -> Void)? = nil
    
    var body: some View {
        BreatheView(
            onSessionComplete: onSessionComplete,
            onSessionEnd: onSessionEnd
        )
        .environmentObject(userManager)
    }
}

#Preview {
    BreatheView()
        .environmentObject(UserManager.shared)
}
