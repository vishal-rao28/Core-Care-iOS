import SwiftUI

struct BPView: View {
    @EnvironmentObject var userManager: UserManager

    @State private var systolic: Int = 0
    @State private var diastolic: Int = 0
    @State private var bpCategory: String = "--"
    @State private var toHome: Bool = false
    @State private var latestBPM: Int = 0
    @State private var isLoading: Bool = false
    @State private var errorMessage: String = ""
    @State private var showError: Bool = false
    @State private var animationOffset: CGFloat = 0
    @State private var rotationAngle: Double = 0
    @State private var isLoadingHR: Bool = false  // Separate loading state for HR
    @State private var showBPCitation = false
    
    private var currentUserId: Int {
        guard let userId = userManager.currentUserId, userId > 0 else {
            return 0
        }
        return userId
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if toHome {
                    HomePageView(userId: currentUserId)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                        .environmentObject(userManager)
                } else {
                    mainContent(geometry: geometry)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                }
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: toHome)
        .onAppear {
            validateUserAndFetch()
            startAnimations()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func validateUserAndFetch() {
        guard currentUserId > 0 else {
            showError(message: "Invalid user session. Please log in again.")
            return
        }
        
        print("BPView: Fetching BP data for user ID: \(currentUserId)")
        fetchLatestBPData()
        fetchLatestHRFromHomePageEndpoint()  // Using HomePageView's HR endpoint
    }
    
    private func startAnimations() {
        withAnimation(
            Animation.linear(duration: 20)
                .repeatForever(autoreverses: false)
        ) {
            rotationAngle = 360
        }
        
        withAnimation(
            Animation.easeInOut(duration: 3)
                .repeatForever(autoreverses: true)
        ) {
            animationOffset = 10
        }
    }

    private func mainContent(geometry: GeometryProxy) -> some View {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let safeTop = max(geometry.safeAreaInsets.top, 44)
        let safeBottom = max(geometry.safeAreaInsets.bottom, 20)
        
        return ZStack {
            // Adaptive background
            Color.appBackground2
            .ignoresSafeArea()
            
            // Subtle animated background elements
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.02),
                                Color.purple.opacity(0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: screenWidth * 0.4, height: screenWidth * 0.4)
                    .position(
                        x: screenWidth * CGFloat.random(in: 0...1),
                        y: screenHeight * CGFloat.random(in: 0...1)
                    )
                    .rotationEffect(.degrees(rotationAngle + Double(index * 60)))
                    .animation(
                        Animation.linear(duration: Double.random(in: 15...25))
                            .repeatForever(autoreverses: false)
                            .delay(Double(index)),
                        value: rotationAngle
                    )
            }
            
            VStack(spacing: 0) {
                // Header Section pinned at top
                headerSection(screenWidth: screenWidth, safeTop: safeTop)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: screenHeight * 0.025) {
                        // BP Metrics Cards
                        bpMetricsSection(screenWidth: screenWidth)
                        
                        // Dynamic Health Insights
                        healthInsightsSection(screenWidth: screenWidth)
                        
                        // Bottom spacing for safe area
                        Spacer()
                            .frame(height: safeBottom + 20)
                    }
                    .padding(.horizontal, screenWidth * 0.05)
                    .padding(.top, 10)
                }
            }
            
            // Enhanced loading overlay
            if isLoading || isLoadingHR {
                loadingOverlay()
            }
        }
    }
    
    // MARK: - Header Section
    private func headerSection(screenWidth: CGFloat, safeTop: CGFloat) -> some View {
        HStack {
            // Back button
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
            
            Spacer()
            
            // Title
            VStack(spacing: 4) {
                Text("Blood Pressure")
                    .font(.system(size: min(screenWidth * 0.06, 24), weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.3, blue: 0.8),
                                Color(red: 0.4, green: 0.2, blue: 0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: screenWidth * 0.2, height: 2)
                    .cornerRadius(1)
            }
            
            Spacer()
            
            // Refresh button
            Button {
                validateUserAndFetch()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.horizontal, screenWidth * 0.05)
        .padding(.top, safeTop + 8)
        .padding(.bottom, 12)
    }
    
    // MARK: - BP Metrics Section
    private func bpMetricsSection(screenWidth: CGFloat) -> some View {
        VStack(spacing: screenWidth * 0.04) {
            // Main BP reading card
            mainBPCard(screenWidth: screenWidth)
            
            // Category and details
            HStack(spacing: screenWidth * 0.03) {
                categoryCard(screenWidth: screenWidth)
                bpmCard(screenWidth: screenWidth)
            }
        }
    }
    
    private func mainBPCard(screenWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Reading")
                    .font(.system(size: screenWidth * 0.038, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Circle()
                    .fill(getBPStatusColor().opacity(0.8))
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationOffset > 5 ? 1.2 : 1.0)
            }
            
            HStack(alignment: .center, spacing: screenWidth * 0.08) {
                // Systolic
                VStack(spacing: 8) {
                    Text("\(systolic)")
                        .font(.system(size: screenWidth * 0.12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3))
                    
                    Text("SYSTOLIC")
                        .font(.system(size: screenWidth * 0.028, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(1)
                }
                
                // Separator
                VStack {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 1, height: 20)
                    
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
                
                // Diastolic
                VStack(spacing: 8) {
                    Text("\(diastolic)")
                        .font(.system(size: screenWidth * 0.12, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.8))
                    
                    Text("DIASTOLIC")
                        .font(.system(size: screenWidth * 0.028, weight: .medium))
                        .foregroundColor(.secondary)
                        .tracking(1)
                }
            }
            
            Text("mmHg")
                .font(.system(size: screenWidth * 0.032, weight: .medium))
                .foregroundColor(.red)
        }
        .padding(screenWidth * 0.06)
        .frame(maxWidth: .infinity)
        .glossyCard(cornerRadius: 20, borderTint: Color.red)
    }
    
    private func categoryCard(screenWidth: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Category")
                    .font(.system(size: screenWidth * 0.032, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // NEW: Add citation info button
                Button(action: {
                    showBPCitation = true
                }) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
            }
            
            Text(bpCategory)
                .font(.system(size: screenWidth * 0.038, weight: .semibold, design: .rounded))
                .foregroundColor(getBPStatusColor())
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(screenWidth * 0.04)
        .frame(maxWidth: .infinity)
        .glossyCard(cornerRadius: 16, borderTint: getBPStatusColor())
        .sheet(isPresented: $showBPCitation) {
            MedicalCitationView(
                title: "Blood Pressure Categories",
                citation: "American Heart Association. (2025). Understanding Blood Pressure Readings. Categories based on ACC/AHA Blood Pressure Guidelines (2017).",
                url: "https://www.heart.org/en/health-topics/high-blood-pressure/understanding-blood-pressure-readings"
            )
        }
    }
    // MARK: - Heart Rate Card (fetching from HomePageView endpoint)
    private func bpmCard(screenWidth: CGFloat) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Heart Rate")
                    .font(.system(size: screenWidth * 0.032, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if isLoadingHR {
                    ProgressView()
                        .scaleEffect(0.6)
                        .progressViewStyle(CircularProgressViewStyle(tint: .red))
                }
            }
            
            if latestBPM > 0 {
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(latestBPM)")
                        .font(.system(size: screenWidth * 0.055, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("bpm")
                        .font(.system(size: screenWidth * 0.028, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Heart rate category
                Text("\(getHRCategory(bpm: latestBPM))")
                    .font(.system(size: screenWidth * 0.026, weight: .medium))
                    .foregroundColor(getHRColor(bpm: latestBPM))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(getHRColor(bpm: latestBPM).opacity(0.1))
                    .cornerRadius(6)
            } else {
                VStack(spacing: 4) {
                    Text("--")
                        .font(.system(size: screenWidth * 0.055, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Text("No data")
                        .font(.system(size: screenWidth * 0.026, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(screenWidth * 0.04)
        .frame(maxWidth: .infinity, minHeight: screenWidth * 0.25)
        .glossyCard(cornerRadius: 16, borderTint: Color.red)
    }
    
    // MARK: - Health Insights Section
    private func healthInsightsSection(screenWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: screenWidth * 0.04) {
            HStack {
                Text("Health Insights")
                    .font(.system(size: screenWidth * 0.05, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Personalized")
                    .font(.system(size: screenWidth * 0.028, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background {
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    }
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: screenWidth * 0.03),
                GridItem(.flexible(), spacing: screenWidth * 0.03)
            ], spacing: screenWidth * 0.03) {
                
                ForEach(getDynamicSuggestions(), id: \.id) { suggestion in
                    suggestionCard(
                        suggestion: suggestion,
                        screenWidth: screenWidth
                    )
                }
            }
        }
    }
    
    private func suggestionCard(suggestion: HealthSuggestion, screenWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: suggestion.icon)
                    .font(.system(size: screenWidth * 0.05, weight: .medium))
                    .foregroundColor(suggestion.color)
                    .frame(width: screenWidth * 0.08, height: screenWidth * 0.08)
                    .background {
                        Circle()
                            .fill(suggestion.color.opacity(0.1))
                    }
                
                Spacer()
                
                Circle()
                    .fill(suggestion.priority == .high ? Color.red.opacity(0.8) :
                          suggestion.priority == .medium ? Color.orange.opacity(0.8) :
                          Color.green.opacity(0.8))
                    .frame(width: 6, height: 6)
            }
            
            Text(suggestion.title)
                .font(.system(size: screenWidth * 0.036, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(suggestion.description)
                .font(.system(size: screenWidth * 0.03, weight: .regular))
                .foregroundColor(.secondary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
        }
        .padding(screenWidth * 0.04)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: screenWidth * 0.45)
        .glossyCard(cornerRadius: 16, borderTint: suggestion.color)
    }
    
    // MARK: - Loading Overlay
    private func loadingOverlay() -> some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                Text(isLoading ? "Loading BP..." : "Loading Heart Rate...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(30)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThickMaterial)
            }
            .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        }
    }
    
    // MARK: - Helper Functions
    private func getBPStatusColor() -> Color {
        switch bpCategory.lowercased() {
        case let cat where cat.contains("normal"):
            return Color.green
        case let cat where cat.contains("elevated"):
            return Color.yellow
        case let cat where cat.contains("high"), let cat where cat.contains("hypertension"):
            return Color.red
        default:
            return Color.gray
        }
    }
    
    private func getHRCategory(bpm: Int) -> String {
        if bpm < 60 {
            return "Low"
        } else if bpm <= 100 {
            return "Normal"
        } else {
            return "High"
        }
    }
    
    private func getHRColor(bpm: Int) -> Color {
        if bpm < 60 {
            return Color.blue
        } else if bpm <= 100 {
            return Color.green
        } else {
            return Color.red
        }
    }
    
    private func getDynamicSuggestions() -> [HealthSuggestion] {
        var suggestions: [HealthSuggestion] = []
        
        // BP-specific suggestion
        let bpStatus = getBPStatus()
        suggestions.append(HealthSuggestion(
            id: "bp_status",
            title: "BP Status",
            description: "Your blood pressure is \(systolic)/\(diastolic) (\(bpCategory)). \(bpStatus.advice)",
            icon: "heart.fill",
            color: bpStatus.color,
            priority: bpStatus.priority
        ))
        
        // Dynamic suggestions based on BP category
        if systolic > 140 || diastolic > 90 {
            suggestions.append(HealthSuggestion(
                id: "reduce_sodium",
                title: "Reduce Sodium",
                description: "Limit sodium intake to less than 2,300mg daily. Avoid processed foods and restaurant meals.",
                icon: "minus.circle.fill",
                color: .red,
                priority: .high
            ))
        }
        
        suggestions.append(HealthSuggestion(
            id: "exercise",
            title: "Stay Active",
            description: "Aim for 30 minutes of moderate exercise daily. Walking, swimming, or cycling are excellent choices.",
            icon: "figure.walk",
            color: .blue,
            priority: .medium
        ))
        
        suggestions.append(HealthSuggestion(
            id: "diet",
            title: "Heart-Healthy Diet",
            description: "Focus on fruits, vegetables, whole grains, and lean proteins. Follow the DASH diet principles.",
            icon: "leaf.fill",
            color: .green,
            priority: .medium
        ))
        
        if latestBPM > 100 {
            suggestions.append(HealthSuggestion(
                id: "stress_management",
                title: "Manage Stress",
                description: "Practice deep breathing, meditation, or yoga to help reduce stress and heart rate.",
                icon: "brain.head.profile",
                color: .purple,
                priority: .high
            ))
        }
        
        suggestions.append(HealthSuggestion(
            id: "hydration",
            title: "Stay Hydrated",
            description: "Drink 8-10 glasses of water daily. Proper hydration supports healthy blood pressure.",
            icon: "drop.fill",
            color: .cyan,
            priority: .low
        ))
        
        suggestions.append(HealthSuggestion(
            id: "sleep",
            title: "Quality Sleep",
            description: "Aim for 7-9 hours of quality sleep. Poor sleep can affect blood pressure regulation.",
            icon: "moon.fill",
            color: .indigo,
            priority: .medium
        ))
        
        return suggestions
    }
    
    private func getBPStatus() -> (advice: String, color: Color, priority: Priority) {
        if systolic < 120 && diastolic < 80 {
            return ("Keep up the good work with your healthy lifestyle.", .green, .low)
        } else if systolic < 130 && diastolic < 80 {
            return ("Consider lifestyle changes to prevent progression.", .yellow, .medium)
        } else if systolic < 140 || diastolic < 90 {
            return ("Consult your doctor about lifestyle modifications.", .orange, .medium)
        } else {
            return ("Seek medical attention for proper evaluation and treatment.", .red, .high)
        }
    }
    
    // MARK: - Network Functions
    private func fetchLatestBPData() {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/bp.php?user_id=\(currentUserId)") else {
            showError(message: "Invalid URL or user ID")
            return
        }

        isLoading = true
        errorMessage = ""

        print("BPView: Fetching BP data from: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("BPView: Network error: \(error.localizedDescription)")
                showError(message: "Network error: \(error.localizedDescription)")
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("BPView: HTTP Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 401 {
                    showError(message: "Session expired. Please log in again.")
                    return
                }
            }

            guard let data = data else {
                showError(message: "No data received")
                return
            }

            do {
                let jsonAny = try JSONSerialization.jsonObject(with: data)
                print("BPView: Received response: \(jsonAny)")
                
                guard let json = jsonAny as? [String: Any] else {
                    showError(message: "Invalid response format")
                    return
                }

                if let status = json["status"] as? String, status == "success",
                   let dataObj = json["data"] as? [String: Any] {

                    DispatchQueue.main.async {
                        self.systolic = dataObj["systolic"] as? Int ?? 0
                        self.diastolic = dataObj["diastolic"] as? Int ?? 0
                        self.bpCategory = dataObj["category"] as? String ?? "--"
                        
                        print("BPView: Successfully updated BP data: \(self.systolic)/\(self.diastolic) - \(self.bpCategory)")
                    }
                } else {
                    let msg = json["message"] as? String ?? "Unknown error"
                    print("BPView: API error: \(msg)")
                    showError(message: msg)
                }
            } catch {
                print("BPView: JSON parse error: \(error)")
                showError(message: "JSON parse error: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: - Heart Rate Response Model (from HomePageView)
    struct HeartRateResponse: Codable {
        let status: String
        let bpm: Int
        let timestamp: String?
    }

    // MARK: - Fetch Heart Rate using HomePageView's endpoint
    private func fetchLatestHRFromHomePageEndpoint() {
        guard currentUserId > 0,
              let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/heartbeat.php?user_id=\(currentUserId)&type=latest") else {
            print("BPView: Invalid userId or URL for heartbeat")
            return
        }

        isLoadingHR = true

        print("BPView: Fetching HR data from HomePageView endpoint: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoadingHR = false
            }

            guard let data = data, error == nil else {
                print("BPView: Error loading heartbeat: \(error?.localizedDescription ?? "Unknown")")
                return
            }

            if let result = try? JSONDecoder().decode(HeartRateResponse.self, from: data),
               result.status.lowercased() == "success" {
                DispatchQueue.main.async {
                    self.latestBPM = result.bpm
                    print("BPView: Latest heart rate loaded from HomePageView endpoint: \(result.bpm) BPM")
                }
            } else {
                print("BPView: No heart rate data found or failed to parse from HomePageView endpoint")
                DispatchQueue.main.async {
                    self.latestBPM = 0
                }
            }
        }.resume()
    }

    private func showError(message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
            self.isLoading = false
            self.isLoadingHR = false
        }
    }
}

// Add this struct to BPView.swift
struct MedicalCitationView: View {
    let title: String
    let citation: String
    let url: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Medical Source")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(citation)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    if let websiteURL = URL(string: url) {
                        Link(destination: websiteURL) {
                            HStack {
                                Image(systemName: "link.circle.fill")
                                Text("View Source")
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    Text("Disclaimer")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("This app provides information based on established medical guidelines. Always consult with a qualified healthcare provider for medical advice, diagnosis, or treatment.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding()
            }
            .navigationTitle("Citation")
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
// MARK: - Supporting Models
struct HealthSuggestion {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let priority: Priority
}

enum Priority {
    case high, medium, low
}

#Preview {
    BPView()
        .environmentObject(UserManager.shared)
}




// Add this state variable to BPView struct


// Modify your bpCategory display to include info button
// Replace your existing BP category card with this:

