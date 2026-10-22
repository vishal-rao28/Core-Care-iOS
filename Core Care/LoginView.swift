import SwiftUI

// MARK: - User Manager (Singleton for managing user data across the app)
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var userData: LoginData?
    @Published var isLoggedIn: Bool = false
    
    private init() {
        // Load user data from UserDefaults on app launch
        loadUserData()
    }
    
    func setUserData(_ data: LoginData) {
        self.userData = data
        self.isLoggedIn = true
        
        // Save to UserDefaults for persistence
        UserDefaults.standard.set(data.user_id, forKey: "userId")
        UserDefaults.standard.set(data.emailOrPhone, forKey: "userEmailOrPhone")
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        
        // Save the entire user data as JSON for complex data
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "userData")
        }
        
        // Debug print to verify data is set
        print("UserManager: Set user data - ID: \(data.user_id), Email: \(data.emailOrPhone)")
    }
    
    func loadUserData() {
        if let userData = UserDefaults.standard.data(forKey: "userData"),
           let decodedData = try? JSONDecoder().decode(LoginData.self, from: userData) {
            self.userData = decodedData
            self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            print("UserManager: Loaded user data - ID: \(decodedData.user_id)")
        } else {
            print("UserManager: No saved user data found")
        }
    }
    
    func logout() {
        self.userData = nil
        self.isLoggedIn = false
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "userEmailOrPhone")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "userData")
        
        print("UserManager: User logged out")
    }
    
    var currentUserId: Int? {
        return userData?.user_id
    }
    
    var isUserDataValid: Bool {
        return userData != nil && isLoggedIn
    }
    
    // MARK: - Enhanced Methods (NEW)
    
    func validateSession() -> Bool {
        print("UserManager: Validating session...")
        print("- isLoggedIn: \(isLoggedIn)")
        print("- userData exists: \(userData != nil)")
        print("- userId: \(userData?.user_id ?? -1)")
        
        // Check if UserDefaults still has the data
        let storedUserId = UserDefaults.standard.integer(forKey: "userId")
        let storedIsLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        
        print("- UserDefaults userId: \(storedUserId)")
        print("- UserDefaults isLoggedIn: \(storedIsLoggedIn)")
        
        return isUserDataValid && storedIsLoggedIn && storedUserId > 0
    }
    
    func refreshFromUserDefaults() {
        print("UserManager: Refreshing from UserDefaults...")
        loadUserData()
        print("UserManager: After refresh - isLoggedIn: \(isLoggedIn), userId: \(currentUserId ?? -1)")
    }
    
    func printCurrentState() {
        print("=== UserManager Current State ===")
        print("isLoggedIn: \(isLoggedIn)")
        print("userData: \(userData?.emailOrPhone ?? "nil")")
        print("currentUserId: \(currentUserId ?? -1)")
        print("isUserDataValid: \(isUserDataValid)")
        print("================================")
    }
    
    func checkSessionIntegrity() -> Bool {
        // Verify that UserDefaults data matches in-memory data
        guard let userData = userData else {
            print("UserManager: No user data in memory")
            return false
        }
        
        let storedUserId = UserDefaults.standard.integer(forKey: "userId")
        let storedIsLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        
        let isValid = userData.user_id == storedUserId &&
                     isLoggedIn == storedIsLoggedIn &&
                     storedIsLoggedIn == true &&
                     storedUserId > 0
        
        if !isValid {
            print("UserManager: Session integrity check failed")
            print("- Memory userId: \(userData.user_id), Stored userId: \(storedUserId)")
            print("- Memory isLoggedIn: \(isLoggedIn), Stored isLoggedIn: \(storedIsLoggedIn)")
        }
        
        return isValid
    }
}

// MARK: - LoginView

struct LoginView: View {
    @State private var emailOrPhone = ""
    @State private var password = ""
    @State private var navigateTo: Destination? = nil
    @State private var warningMessage = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var emailFocused = false
    @State private var passwordFocused = false
    
    // Use the shared instance consistently
    @ObservedObject private var userManager = UserManager.shared

    enum Destination {
        case forgotPassword, home, content, register
    }

    var body: some View {
        ZStack {
            if navigateTo == nil {
                mainLoginView
                    .transition(
    .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
)

            }

            if navigateTo == .forgotPassword {
                ForgotPasswordView()
                    .transition(
    .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
)

            }

            if navigateTo == .home {
                // Pass the actual user ID from UserManager, with fallback
                HomePageView(userId: userManager.currentUserId ?? 0)
                    .transition(
    .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
)

                    .environmentObject(userManager)
            }

            if navigateTo == .content {
                ContentView()
                    .transition(
    .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
)

            }

            if navigateTo == .register {
                RegistrationView()
                    .transition(
    .asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
)

            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: navigateTo)
        .id(navigateTo) // Forces full view update
    }

    var mainLoginView: some View {
        GeometryReader { geometry in
            ZStack {
                // Adaptive background
                LinearGradient.appSplash
                .ignoresSafeArea()
                
                // Enhanced Logo with subtle animation
                Image("corecarelogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 280, height: 280)
                    .opacity(0.08)
                    .scaleEffect(emailFocused || passwordFocused ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: emailFocused || passwordFocused)
                    .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.35)

                ScrollView {
                    VStack(spacing: 0) {
                        // Enhanced Top Bar with better spacing
                        HStack {
                            Button {
                                navigateTo = .content
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                    Text("Back")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(Color("coreblue"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color("coreblue").opacity(0.1))
                                )
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, max(geometry.safeAreaInsets.top, 44) + 8)
                        
                        // Enhanced Header Section
                        VStack(spacing: 12) {
                            Text("Welcome Back")
                                .font(.custom("Iceland", size: 42))
                                .fontWeight(.bold)
                                .foregroundColor(Color("coreblue"))
                                .multilineTextAlignment(.center)
                            
                            Text("Sign in to continue your care journey")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 40)
                        .padding(.horizontal, 24)
                        
                        // Enhanced Form Container
                        VStack(spacing: 24) {
                            // Enhanced Email/Phone Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(Color("coreblue"))
                                        .font(.caption)
                                    Text("Email or Phone")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            emailFocused ? Color("coreblue") : Color.gray.opacity(0.3),
                                            lineWidth: emailFocused ? 2 : 1
                                        )
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.cardBackground)
                                                .shadow(
                                                    color: emailFocused ? Color.appAccent.opacity(0.15) : Color.appSeparator.opacity(0.3),
                                                    radius: emailFocused ? 8 : 2,
                                                    x: 0,
                                                    y: emailFocused ? 4 : 1
                                                )
                                        )
                                    
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(Color("coreblue").opacity(0.6))
                                            .font(.title3)
                                        
                                        TextField("Enter your email or phone", text: $emailOrPhone, onEditingChanged: { focused in
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                emailFocused = focused
                                            }
                                        })
                                        .font(.body)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .textContentType(.username)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                }
                            }
                            
                            // Enhanced Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(Color("coreblue"))
                                        .font(.caption)
                                    Text("Password")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                }
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(
                                            passwordFocused ? Color("coreblue") : Color.gray.opacity(0.3),
                                            lineWidth: passwordFocused ? 2 : 1
                                        )
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.cardBackground)
                                                .shadow(
                                                    color: passwordFocused ? Color.appAccent.opacity(0.15) : Color.appSeparator.opacity(0.3),
                                                    radius: passwordFocused ? 8 : 2,
                                                    x: 0,
                                                    y: passwordFocused ? 4 : 1
                                                )
                                        )
                                    
                                    HStack {
                                        Image(systemName: "key.fill")
                                            .foregroundColor(Color("coreblue").opacity(0.6))
                                            .font(.title3)
                                        
                                        Group {
                                            if isPasswordVisible {
                                                TextField("Enter your password", text: $password, onEditingChanged: { focused in
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        passwordFocused = focused
                                                    }
                                                })
                                            } else {
                                                SecureField("Enter your password", text: $password, onCommit: {
                                                    passwordFocused = false
                                                })
                                                .onTapGesture {
                                                    withAnimation(.easeInOut(duration: 0.2)) {
                                                        passwordFocused = true
                                                    }
                                                }
                                            }
                                        }
                                        .font(.body)
                                        .textContentType(.password)
                                        
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                isPasswordVisible.toggle()
                                            }
                                        } label: {
                                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                                .foregroundColor(Color("coreblue").opacity(0.6))
                                                .font(.title3)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                }
                            }
                            
                            // Enhanced Warning Message with better styling
                            if !warningMessage.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                        .font(.caption)
                                    
                                    Text(warningMessage)
                                        .foregroundColor(.red)
                                        .font(.footnote)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                                    removal: .scale(scale: 0.8).combined(with: .opacity)
                                ))
                            }
                            
                            // Enhanced Sign In Button with loading state
                            Button {
                                validateFields()
                            } label: {
                                HStack(spacing: 12) {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .font(.title3)
                                    }
                                    
                                    Text(isLoading ? "Signing In..." : "Sign In")
                                        .fontWeight(.semibold)
                                        .font(.body)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color("coreblue"),
                                            Color("coreblue").opacity(0.8)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(
                                    color: Color("coreblue").opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                                .scaleEffect(isLoading ? 0.98 : 1.0)
                            }
                            .disabled(isLoading)
                            .animation(.easeInOut(duration: 0.2), value: isLoading)
                            
                            // Enhanced Forgot Password Button
                            Button {
                                navigateTo = .forgotPassword
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "questionmark.circle")
                                        .font(.caption)
                                    Text("Forgot password?")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(Color("coreblue"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color("coreblue").opacity(0.08))
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 50)
                        
                        // Enhanced Divider
                        HStack {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("OR")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                            
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 30)
                        
                        // Enhanced Sign Up Section
                        VStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .font(.body)
                                    .foregroundColor(.secondary)

                                Button {
                                    navigateTo = .register
                                } label: {
                                    Text("Sign up")
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color("coreblue"))
                                }
                            }
                            
                            // Enhanced Sign Up Button
                            Button {
                                navigateTo = .register
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.badge.plus")
                                        .font(.title3)
                                    Text("Create New Account")
                                        .fontWeight(.medium)
                                        .font(.body)
                                }
                                .foregroundColor(Color("coreblue"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color("coreblue"), lineWidth: 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.cardBackground)
                                        )
                                )
                                .shadow(
                                    color: Color("coreblue").opacity(0.1),
                                    radius: 4,
                                    x: 0,
                                    y: 2
                                )
                            }
                            .padding(.horizontal, 24)
                        }
                        
                        Spacer(minLength: max(geometry.safeAreaInsets.bottom, 20) + 20)
                    }
                }
                .frame(width: geometry.size.width, alignment: .topLeading)
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onTapGesture {
            // Dismiss keyboard when tapping outside
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            emailFocused = false
            passwordFocused = false
        }
    }

    // MARK: - Validation (Enhanced with loading state)

    func validateFields() {
        // Clear previous warnings
        warningMessage = ""
        
        guard !emailOrPhone.trimmingCharacters(in: .whitespaces).isEmpty else {
            warningMessage = "Please enter your email or phone number."
            return
        }

        guard isValidEmail(emailOrPhone) || isValidPhone(emailOrPhone) else {
            warningMessage = "Please enter a valid email or phone number."
            return
        }

        guard isValidPassword(password) else {
            warningMessage = "Password must be at least 8 characters with uppercase, lowercase, number, and symbol."
            return
        }

        performLogin()
    }
    
    // MARK: - Network Login Request (Enhanced with loading state and better debugging)
    func performLogin() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoading = true
        }
        
        guard let url = URL(string: "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/login.php") else {
            warningMessage = "Invalid server URL."
            isLoading = false
            return
        }

        let parameters: [String: String] = [
            "emailOrPhone": emailOrPhone,
            "password": password
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
            warningMessage = "Failed to encode JSON."
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLoading = false
                }
                
                if let error = error {
                    warningMessage = "Network error: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    warningMessage = "No response data from server."
                    return
                }

                do {
                    let response = try JSONDecoder().decode(LoginResponse.self, from: data)
                    
                    if response.status == "success", let userData = response.data {
                        print("Login API Response - User ID: \(userData.user_id), Email: \(userData.emailOrPhone)")
                        
                        // Set user data in UserManager first
                        userManager.setUserData(userData)
                        
                        // Use enhanced validation methods
                        userManager.printCurrentState()
                        let isValid = userManager.validateSession()
                        
                        if isValid {
                            print("UserManager validation: SUCCESS - User ID: \(userManager.currentUserId ?? -1)")
                            
                            // Clear any warning messages
                            warningMessage = ""
                            
                            // Small delay to ensure UserManager state is updated
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    navigateTo = .home
                                }
                            }
                        } else {
                            warningMessage = "Failed to save user session."
                            print("UserManager validation: FAILED")
                        }
                        
                    } else {
                        warningMessage = response.message
                        print("Login failed: \(response.message)")
                    }
                } catch {
                    warningMessage = "Failed to parse server response: \(error.localizedDescription)"
                    print("JSON parsing error: \(error)")
                }
            }
        }.resume()
    }

    // MARK: - Validation Helper Functions
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluate(with: email)
    }

    func isValidPhone(_ phone: String) -> Bool {
        let phoneRegEx = #"^\+?[0-9 ]{7,15}$"#
        return NSPredicate(format: "SELF MATCHES %@", phoneRegEx).evaluate(with: phone)
    }

    func isValidPassword(_ password: String) -> Bool {
        let passwordRegEx = #"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^\da-zA-Z]).{8,}$"#
        return NSPredicate(format: "SELF MATCHES %@", passwordRegEx).evaluate(with: password)
    }
}

// MARK: - Data Models
struct LoginResponse: Codable {
    let status: String
    let message: String
    let data: LoginData?
}

struct LoginData: Codable {
    let user_id: Int
    let emailOrPhone: String
}
#Preview {
    LoginView()
}
