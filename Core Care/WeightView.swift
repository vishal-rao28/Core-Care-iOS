import SwiftUI

struct WeightView: View {
    @EnvironmentObject var userManager: UserManager
    @AppStorage("userId") private var userId: Int = 0
    @AppStorage("userName") private var userName: String = "User"

    var onDismiss: (() -> Void)? = nil
    var onSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var goToHome = false
    @State private var weight: String = ""
    @State private var height: String = ""
    @State private var weightError = false
    @State private var heightError = false

    @State private var showMedicalReferences = false
    
    @State private var bmi: Double?
    @State private var bmiCategory: String = ""

    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccessMessage: Bool = false
    
    // Animation states
    @State private var showSuggestions = false
    @State private var pulseEffect = false
    @State private var dataSaved = false
    @State private var animateCards = false
    @State private var floatingOffset: CGFloat = 0
    
    private var currentUserId: Int {
        if let managerId = userManager.currentUserId, managerId > 0 {
            return managerId
        } else if userId > 0 {
            return userId
        } else {
            return 0
        }
    }

    var body: some View {
        ZStack {
            if goToHome {
                HomePageView(userId: currentUserId)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            } else {
                mainContent
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
            }

            if isLoading {
                ModernLoadingOverlay()
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: goToHome)
        .alert("Success", isPresented: $showSuccessMessage) {
            Button("Continue", role: .cancel) {}
        } message: {
            Text("Your health data has been saved successfully!")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .environmentObject(userManager)
    }

    private var mainContent: some View {
        GeometryReader { geo in
            ZStack {
                // Adaptive background
                Color.appBackground
                .ignoresSafeArea()
                
                // Enhanced background pattern
                ZStack {
                    // Large background circles
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.red.opacity(0.1), Color.clear],
                                center: .topLeading,
                                startRadius: 50,
                                endRadius: 200
                            )
                        )
                        .frame(width: 300, height: 300)
                        .position(x: geo.size.width * 0.2, y: geo.size.height * 0.1)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.pink.opacity(0.08), Color.clear],
                                center: .center,
                                startRadius: 30,
                                endRadius: 150
                            )
                        )
                        .frame(width: 200, height: 200)
                        .position(x: geo.size.width * 0.8, y: geo.size.height * 0.3)
                        .offset(y: floatingOffset)
                    
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.orange.opacity(0.06), Color.clear],
                                center: .bottomTrailing,
                                startRadius: 40,
                                endRadius: 180
                            )
                        )
                        .frame(width: 250, height: 250)
                        .position(x: geo.size.width * 0.1, y: geo.size.height * 0.7)
                        .offset(y: -floatingOffset)
                }
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: floatingOffset)

                VStack(spacing: 0) {
                    headerView(geo: geo)
                        .padding(.horizontal, 20)
                        .padding(.top, max(geo.safeAreaInsets.top, 44) + 8)
                        .padding(.bottom, 12)

                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: geo.size.height * 0.02) {
                        
                        // Glassmorphism main card with neumorphism elements
                        ZStack {
                            // Background blur effect
                            RoundedRectangle(cornerRadius: 32)
                                .fill(.ultraThinMaterial)
                                .background(
                                    RoundedRectangle(cornerRadius: 32)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.9),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 32)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.8),
                                                    Color.clear,
                                                    Color.red.opacity(0.2)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(color: .black.opacity(0.1), radius: 30, x: 0, y: 15)
                                .shadow(color: .red.opacity(0.1), radius: 5, x: 0, y: 5)
                            
                            VStack(spacing: geo.size.height * 0.025) {
                                weightInputView(geo: geo)
                                heightInputView(geo: geo)
                                calculateButton(geo: geo)
                            }
                            .padding(.vertical, geo.size.height * 0.04)
                            .padding(.horizontal, 24)
                        }
                        .padding(.horizontal, 20)
                        .scaleEffect(animateCards ? 1 : 0.9)
                        .opacity(animateCards ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2), value: animateCards)

                        if let bmi = bmi {
                            modernSuggestionsPanel(bmi: bmi, geo: geo)
                        }

                        Spacer(minLength: max(geo.safeAreaInsets.bottom, 20) + 20)
                    }
                    .frame(width: geo.size.width)
                    .padding(.top, 8)
                }
            }
            }
        }
        .onAppear {
            loadSavedData()
            withAnimation {
                animateCards = true
                floatingOffset = 30
            }
            fetchLatestFromBackend()
        }
    }

    // MARK: Modern Header with Floating Elements (Updated - removed home icon)
    // MARK: Modern Header with Floating Elements (Updated - corrected button order)
    // MARK: Modern Header with Floating Elements (Updated - proper left-right positioning)
    private func headerView(geo: GeometryProxy) -> some View {
        HStack(spacing: 12) {
            // Back button: LEFTMOST position
            Button {
                if let onDismiss = onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        goToHome = true
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(ModernButtonStyle())
            
            Spacer()
            
            VStack(spacing: 4) {
                Text("Health Metrics")
                    .font(.system(size: min(geo.size.width * 0.06, 22), weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .pink, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(dataSaved ? .green : .orange)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulseEffect ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: pulseEffect)
                    
                    Text(dataSaved ? "Data saved" : "Weight & BMI")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(dataSaved ? .green : .secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if showSuggestions && dataSaved {
                    FloatingActionButton(
                        icon: "arrow.clockwise",
                        color: .blue,
                        action: { resetForm() }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
                
                Button(action: {
                    showMedicalReferences = true
                }) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "book.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(ModernButtonStyle())
                .sheet(isPresented: $showMedicalReferences) {
                    MedicalReferencesView()
                }
            }
        }
        .onAppear {
            pulseEffect = true
        }
    }




    // MARK: Modern Neumorphic Input Views
    private func weightInputView(geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Weight")
                        .font(.system(size: geo.size.width * 0.045, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Enter your current weight")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Neumorphic input field
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                weightError ?
                                LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.white.opacity(0.5), Color.gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: weightError ? 2 : 1
                            )
                    )
                    .shadow(color: Color.cardShadow, radius: 8, x: 0, y: 4)
                
                HStack {
                    TextField("0.0", text: $weight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: geo.size.width * 0.05, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .onChange(of: weight) { _, _ in
                            dataSaved = false
                        }
                    
                    Spacer()
                    
                    Text("kg")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            
            if weightError {
                ModernErrorView(message: "Please enter a valid weight")
            }
        }
    }

    private func heightInputView(geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Height")
                        .font(.system(size: geo.size.width * 0.045, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Enter your current height")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Neumorphic input field
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                heightError ?
                                LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.white.opacity(0.5), Color.gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: heightError ? 2 : 1
                            )
                    )
                    .shadow(color: Color.cardShadow, radius: 8, x: 0, y: 4)
                
                HStack {
                    TextField("0.0", text: $height)
                        .keyboardType(.decimalPad)
                        .font(.system(size: geo.size.width * 0.05, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .onChange(of: height) { _, _ in
                            dataSaved = false
                        }
                    
                    Spacer()
                    
                    Text("cm")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            
            if heightError {
                ModernErrorView(message: "Please enter a valid height")
            }
        }
    }

    // MARK: Modern 3D Button
    private func calculateButton(geo: GeometryProxy) -> some View {
        Button {
            if validateFields() {
                calculateBMI()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showSuggestions = true
                    dataSaved = true
                }
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                saveToUserDefaults()
                submitToBackend()
            }
        } label: {
            ZStack {
                // 3D Shadow effect
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: dataSaved ?
                            [Color.green.opacity(0.3), Color.mint.opacity(0.3)] :
                            [Color.red.opacity(0.3), Color.pink.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .offset(x: 2, y: 6)
                
                // Main button
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: dataSaved ?
                            [.green, .mint, .green] :
                            [.red, .pink, .orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.6), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: dataSaved ? .green.opacity(0.4) : .red.opacity(0.4), radius: 20, x: 0, y: 10)
                
                HStack(spacing: 12) {
                    Image(systemName: dataSaved ? "checkmark.circle.fill" : "heart.text.square.fill")
                        .font(.system(size: 22, weight: .bold))
                    
                    Text(dataSaved ? "Recalculate & Save" : "Calculate BMI & Save")
                        .font(.system(size: geo.size.width * 0.042, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
        }
        .buttonStyle(Modern3DButtonStyle())
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dataSaved)
    }

    // MARK: Ultra-Modern Suggestions Panel (Updated - removed "AI" from headline)
    @ViewBuilder
    private func modernSuggestionsPanel(bmi: Double, geo: GeometryProxy) -> some View {
        LazyVStack(spacing: 20) {
            // Header with floating elements (Updated text)
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.orange.opacity(0.2), .clear],
                                center: .center,
                                startRadius: 5,
                                endRadius: 25
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Insights")
                        .font(.system(size: geo.size.width * 0.05, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Personalized recommendations")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // BMI Result Card - Holographic Style
            holographicBMICard(bmi: bmi, geo: geo)
            
            // Suggestion Cards with Modern Design
            LazyVStack(spacing: 16) {
                ForEach(Array(getDynamicSuggestions(for: bmi).enumerated()), id: \.element.title) { index, suggestion in
                    ModernSuggestionCard(
                        suggestion: suggestion,
                        index: index,
                        geo: geo
                    )
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1), value: showSuggestions)
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                // Glassmorphic background
                RoundedRectangle(cornerRadius: 32)
                    .fill(.ultraThinMaterial)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.blue.opacity(0.02),
                                        Color.purple.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.clear,
                                        Color.blue.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                
                // Animated gradient overlay
                RoundedRectangle(cornerRadius: 32)
                    .fill(
                        AngularGradient(
                            colors: [
                                .clear, .red.opacity(0.05), .clear,
                                .pink.opacity(0.05), .clear, .orange.opacity(0.05), .clear
                            ],
                            center: .center
                        )
                    )
                    .rotationEffect(.degrees(pulseEffect ? 180 : 0))
                    .animation(.easeInOut(duration: 8).repeatForever(autoreverses: false), value: pulseEffect)
            }
        )
        .shadow(color: .black.opacity(0.1), radius: 30, x: 0, y: 15)
        .shadow(color: .blue.opacity(0.1), radius: 5, x: 0, y: 5)
        .padding(.horizontal, 20)
        .scaleEffect(showSuggestions ? 1 : 0.8)
        .opacity(showSuggestions ? 1 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: showSuggestions)
    }
    
    // MARK: Holographic BMI Card
    private func holographicBMICard(bmi: Double, geo: GeometryProxy) -> some View {
        ZStack {
            // Holographic background
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.8),
                            Color.purple.opacity(0.3),
                            Color.blue.opacity(0.3),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan.opacity(0.8), .purple.opacity(0.8), .pink.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BMI ANALYSIS")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                        .tracking(2)
                    
                    Text("\(String(format: "%.1f", bmi))")
                        .font(.system(size: geo.size.width * 0.12, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .cyan.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    Text(bmiCategory.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(getBMICategoryColor(bmi))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(getBMICategoryColor(bmi).opacity(0.2))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(getBMICategoryColor(bmi), lineWidth: 1)
                        )
                }
                
                Spacer()
                
                // 3D BMI Visualization
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: min(bmi / 40, 1.0))
                        .stroke(
                            AngularGradient(
                                colors: [.cyan, .blue, .purple, .pink, .cyan],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: .cyan.opacity(0.6), radius: 10, x: 0, y: 0)
                        .animation(.easeOut(duration: 2).delay(0.5), value: bmi)
                    
                    Text("BMI")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(24)
        }
        .shadow(color: .purple.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    // Reset and other functions
    private func resetForm() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            dataSaved = false
            showSuggestions = false
            bmi = nil
            bmiCategory = ""
            weight = ""
            height = ""
            weightError = false
            heightError = false
        }
        let uId = currentUserId
        UserDefaults.standard.removeObject(forKey: "saved_weight_\(uId)")
        UserDefaults.standard.removeObject(forKey: "saved_height_\(uId)")
        UserDefaults.standard.removeObject(forKey: "saved_bmi_\(uId)")
        UserDefaults.standard.removeObject(forKey: "saved_bmi_category_\(uId)")
        UserDefaults.standard.removeObject(forKey: "saved_weight")
        UserDefaults.standard.removeObject(forKey: "saved_height")
        UserDefaults.standard.removeObject(forKey: "saved_bmi")
        UserDefaults.standard.removeObject(forKey: "saved_bmi_category")
        NotificationCenter.default.post(name: NSNotification.Name("WeightUpdated"), object: nil)
    }

    private func saveToUserDefaults() {
        let uId = currentUserId
        UserDefaults.standard.set(weight, forKey: "saved_weight_\(uId)")
        UserDefaults.standard.set(height, forKey: "saved_height_\(uId)")
        if let b = bmi {
            UserDefaults.standard.set(b, forKey: "saved_bmi_\(uId)")
            UserDefaults.standard.set(b, forKey: "saved_bmi")
        }
        UserDefaults.standard.set(bmiCategory, forKey: "saved_bmi_category_\(uId)")
        
        UserDefaults.standard.set(weight, forKey: "saved_weight")
        UserDefaults.standard.set(height, forKey: "saved_height")
        UserDefaults.standard.set(bmiCategory, forKey: "saved_bmi_category")
        
        NotificationCenter.default.post(name: NSNotification.Name("WeightUpdated"), object: nil)
    }

    private func loadSavedData() {
        let uId = currentUserId
        let savedW = UserDefaults.standard.string(forKey: "saved_weight_\(uId)") ?? UserDefaults.standard.string(forKey: "saved_weight")
        let savedH = UserDefaults.standard.string(forKey: "saved_height_\(uId)") ?? UserDefaults.standard.string(forKey: "saved_height")
        
        if let w = savedW, !w.isEmpty {
            self.weight = w
        }
        if let h = savedH, !h.isEmpty {
            self.height = h
        }
        
        if let wStr = savedW, let hStr = savedH,
           let wVal = Double(wStr), let hVal = Double(hStr), hVal > 0 {
            let heightM = hVal / 100
            let computed = wVal / (heightM * heightM)
            self.bmi = computed
            self.bmiCategory = categorizeBMI(computed)
            self.showSuggestions = true
            self.dataSaved = true
        } else {
            let savedBMI = UserDefaults.standard.double(forKey: "saved_bmi_\(uId)")
            if savedBMI > 0 {
                self.bmi = savedBMI
                self.bmiCategory = UserDefaults.standard.string(forKey: "saved_bmi_category_\(uId)") ?? categorizeBMI(savedBMI)
                self.showSuggestions = true
                self.dataSaved = true
            }
        }
    }

    private func fetchLatestFromBackend() {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/weight.php?user_id=\(currentUserId)") else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String,
               status.lowercased() == "success",
               let weightData = json["data"] as? [String: Any] {
                
                DispatchQueue.main.async {
                    if let w = weightData["weight"] as? Double, self.weight.isEmpty {
                        self.weight = String(format: "%.1f", w)
                    }
                    if let h = weightData["height"] as? Double, self.height.isEmpty {
                        self.height = String(format: "%.1f", h)
                    }
                    if let b = weightData["bmi"] as? Double {
                        self.bmi = b
                        self.bmiCategory = weightData["bmi_category"] as? String ?? self.categorizeBMI(b)
                        self.showSuggestions = true
                        self.dataSaved = true
                        self.saveToUserDefaults()
                    }
                }
            }
        }.resume()
    }

    // MARK: Dynamic Suggestions Logic (unchanged)
    private func getDynamicSuggestions(for bmi: Double) -> [SuggestionItem] {
        switch bmi {
        case ..<18.5:
            return [
                SuggestionItem(title: "Increase Calorie Intake", description: "Focus on nutrient-dense, high-calorie foods like nuts, avocados, and healthy oils.", icon: "leaf.fill", color: .green),
                SuggestionItem(title: "Strength Training", description: "Build muscle mass with resistance exercises 3-4 times per week.", icon: "dumbbell.fill", color: .blue),
                SuggestionItem(title: "Frequent Meals", description: "Eat 5-6 smaller meals throughout the day to increase total calories.", icon: "clock.fill", color: .orange),
                SuggestionItem(title: "Consult Nutritionist", description: "Consider professional guidance for healthy weight gain strategies.", icon: "person.badge.plus", color: .purple)
            ]
        case 18.5..<25:
            return [
                SuggestionItem(title: "Maintain Balance", description: "Keep up your current lifestyle with balanced nutrition and regular activity.", icon: "checkmark.seal.fill", color: .green),
                SuggestionItem(title: "Stay Active", description: "Continue with 150 minutes of moderate exercise per week.", icon: "figure.walk", color: .blue),
                SuggestionItem(title: "Monitor Progress", description: "Regular check-ups help maintain your healthy weight range.", icon: "chart.line.uptrend.xyaxis", color: .mint),
                SuggestionItem(title: "Hydrate Well", description: "Maintain 8-10 glasses of water daily for optimal health.", icon: "drop.fill", color: .cyan)
            ]
        case 25..<30:
            return [
                SuggestionItem(title: "Calorie Deficit", description: "Create a moderate calorie deficit through diet and exercise.", icon: "minus.circle.fill", color: .orange),
                SuggestionItem(title: "Cardio Exercise", description: "Include 30-45 minutes of cardio activities 4-5 times per week.", icon: "heart.fill", color: .red),
                SuggestionItem(title: "Portion Control", description: "Use smaller plates and be mindful of portion sizes.", icon: "scalemass.fill", color: .brown),
                SuggestionItem(title: "Reduce Processed Foods", description: "Focus on whole foods and limit processed and sugary items.", icon: "xmark.circle.fill", color: .pink)
            ]
        default:
            return [
                SuggestionItem(title: "Medical Consultation", description: "Consult healthcare professionals for a comprehensive weight management plan.", icon: "cross.case.fill", color: .red),
                SuggestionItem(title: "Gradual Changes", description: "Start with small, sustainable changes to diet and activity levels.", icon: "tortoise.fill", color: .green),
                SuggestionItem(title: "Low-Impact Exercise", description: "Begin with walking, swimming, or chair exercises to protect joints.", icon: "figure.pool.swim", color: .blue),
                SuggestionItem(title: "Support System", description: "Join support groups or work with professionals for motivation.", icon: "person.2.fill", color: .purple)
            ]
        }
    }
    
    private func getBMICategoryColor(_ bmi: Double) -> Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }

    // MARK: Original Logic Functions (Unchanged)
    private func calculateBMI() {
        guard let w = Double(weight), let h = Double(height), h > 0 else { return }
        let heightMeters = h / 100
        let computedBMI = w / (heightMeters * heightMeters)
        bmi = computedBMI
        bmiCategory = categorizeBMI(computedBMI)
        saveToUserDefaults()
    }

    private func categorizeBMI(_ bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    private func validateFields() -> Bool {
        weightError = weight.trimmingCharacters(in: .whitespaces).isEmpty || Double(weight) == nil
        heightError = height.trimmingCharacters(in: .whitespaces).isEmpty || Double(height) == nil
        return !weightError && !heightError
    }

    // MARK: API (unchanged)
    private func submitToBackend() {
        guard currentUserId != 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/weight.php") else {
            DispatchQueue.main.async {
                self.showError = true
                self.errorMessage = "Invalid URL or User ID"
            }
            return
        }

        isLoading = true

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0

        let params = [
            "user_id": String(currentUserId),
            "weight": weight.trimmingCharacters(in: .whitespaces),
            "height": height.trimmingCharacters(in: .whitespaces)
        ]
        
        let bodyString = params.compactMap { key, value in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async { self.isLoading = false }

            if let error = error {
                DispatchQueue.main.async {
                    self.showError = true
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                DispatchQueue.main.async {
                    self.showError = true
                    self.errorMessage = "Server error: HTTP \(httpResponse.statusCode)"
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.showError = true
                    self.errorMessage = "No data received from server"
                }
                return
            }

            do {
                let result = try JSONDecoder().decode(BackendResponse.self, from: data)
                if result.status == "success" {
                    DispatchQueue.main.async {
                        self.onSave()
                        self.dataSaved = true
                        self.showSuccessMessage = true
                    }
                } else {
                    DispatchQueue.main.async {
                        self.showError = true
                        self.errorMessage = result.message ?? "Server returned error status"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.showError = true
                    self.errorMessage = "Invalid JSON response from server"
                }
            }
        }.resume()
    }

    struct BackendResponse: Codable {
        let status: String
        let data: WeightData?
        let message: String?
    }

    struct WeightData: Codable {
        let weight: Double
        let height: Double
        let bmi: Double
        let category: String
    }
}

// MARK: Modern Supporting Views and Components
struct ModernSuggestionCard: View {
    let suggestion: SuggestionItem
    let index: Int
    let geo: GeometryProxy
    @State private var isHovered = false
    
    var body: some View {
        Button {
            // Add haptic feedback or action
        } label: {
            HStack(spacing: 16) {
                // 3D Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    suggestion.color.opacity(0.1),
                                    suggestion.color.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(suggestion.color.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: suggestion.color.opacity(0.2), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [suggestion.color, suggestion.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(suggestion.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    Text(suggestion.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(suggestion.color)
                    .scaleEffect(isHovered ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.15 : 0.08), radius: isHovered ? 15 : 8, x: 0, y: isHovered ? 8 : 4)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.8), color.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 5)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .buttonStyle(ModernButtonStyle())
    }
}

struct ModernErrorView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
    }
}

struct ModernLoadingOverlay: View {
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(
                                colors: [.red, .pink, .orange, .red],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(rotationAngle))
                }
                
                Text("Calculating BMI...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .shadow(radius: 20)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
        }
    }
}

struct ModernButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct Modern3DButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .offset(x: configuration.isPressed ? 1 : 0, y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MedicalReferencesView: View {
    @Environment(\.dismiss) private var dismiss
    
    let references: [(title: String, citation: String, url: String)] = [
        (
            title: "BMI Calculation Formula",
            citation: "World Health Organization. (2020). Body Mass Index (BMI). WHO Global Database on Body Mass Index.",
            url: "https://www.who.int/data/gho/data/themes/topics/topic-details/GHO/body-mass-index"
        ),
        (
            title: "BMI Categories",
            citation: "Centers for Disease Control and Prevention. (2024). About Body Mass Index (BMI).",
            url: "https://www.cdc.gov/bmi/about/index.html"
        ),
        (
            title: "Weight Management Recommendations",
            citation: "U.S. National Heart, Lung, and Blood Institute. (2022). Heart-Healthy Living - Aim for a Healthy Weight.",
            url: "https://www.nhlbi.nih.gov/health/heart-healthy-living/healthy-weight"
        ),
        (
            title: "Diet and Nutrition Guidelines",
            citation: "American Heart Association. (2024). Healthy Eating.",
            url: "https://www.heart.org/en/healthy-living/healthy-eating"
        ),
        (
            title: "Exercise Recommendations",
            citation: "American College of Sports Medicine. (2025). Physical Activity Guidelines.",
            url: "https://acsm.org/education-resources/trending-topics-resources/physical-activity-guidelines/"
        )
    ]

    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Medical Sources")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("All health information and recommendations in this app are based on the following authoritative medical sources:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // References List
                    ForEach(references.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(references[index].title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(references[index].citation)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    if let url = URL(string: references[index].url) {
                                        Link(destination: url) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.up.right.square")
                                                    .font(.caption)
                                                Text("View Source")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            }
                                            .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.05))
                        )
                        .padding(.horizontal)
                    }
                    
                    // Disclaimer
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Important Disclaimer")
                            .font(.headline)
                        
                        Text("This app provides general health information based on established medical guidelines. It is not intended to replace professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                    )
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Medical References")
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
}
// MARK: Supporting Types
struct SuggestionItem {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

struct WeightView_Previews: PreviewProvider {
    static var previews: some View {
        WeightView()
            .environmentObject(UserManager.shared)
    }
}


