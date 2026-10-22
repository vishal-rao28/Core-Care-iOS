import SwiftUI
import Charts
import AVFoundation
import Accelerate
import Vision

// MARK: - Enhanced Alert Manager with Audio and State Tracking
class AlertManager: ObservableObject {
    @Published var isShowingAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var alertType: AlertType = .info
    
    private var alertTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private var alertShownInSession: Set<String> = []
    
    enum AlertType {
        case success, error, warning, info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .warning: return .orange
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    func showAlert(
        title: String,
        message: String,
        type: AlertType = .info,
        playBeep: Bool = false,
        autoDismissAfter: TimeInterval = 5.0,
        preventDuplicate: Bool = true
    ) {
        let alertId = "\(title)-\(message)"
        if preventDuplicate && alertShownInSession.contains(alertId) {
            print("⚠️ Alert already shown in this session: \(title)")
            return
        }
        
        alertShownInSession.insert(alertId)
        DispatchQueue.main.async { [weak self] in
            self?.alertTitle = title
            self?.alertMessage = message
            self?.alertType = type
            self?.isShowingAlert = true
            
            if playBeep {
                self?.playBeepSound()
            }
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            self?.startAutoDismissTimer(after: autoDismissAfter)
        }
    }
    
    func dismissAlert() {
        DispatchQueue.main.async { [weak self] in
            self?.isShowingAlert = false
            self?.stopBeepSound()
            self?.alertTimer?.invalidate()
            self?.alertTimer = nil
        }
    }
    
    func clearSession() {
        alertShownInSession.removeAll()
        dismissAlert()
    }
    
    private func startAutoDismissTimer(after interval: TimeInterval) {
        alertTimer?.invalidate()
        alertTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.dismissAlert()
        }
    }
    
    private func playBeepSound() {
        AudioServicesPlaySystemSound(1057)
        DispatchQueue.global(qos: .background).async { [weak self] in
            for _ in 0..<5 {
                Thread.sleep(forTimeInterval: 1.0)
                DispatchQueue.main.async {
                    if self?.isShowingAlert == true {
                        AudioServicesPlaySystemSound(1057)
                    }
                }
            }
        }
    }
    
    private func stopBeepSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// MARK: - Enhanced Alert View Component
struct EnhancedAlertView: View {
    @ObservedObject var alertManager: AlertManager
    
    var body: some View {
        if alertManager.isShowingAlert {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        alertManager.dismissAlert()
                    }
                
                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: alertManager.alertType.icon)
                            .font(.title2)
                            .foregroundColor(alertManager.alertType.color)
                        
                        Text(alertManager.alertTitle)
                            .font(.headline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Button(action: {
                            alertManager.dismissAlert()
                        }) {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if !alertManager.alertMessage.isEmpty {
                        Text(alertManager.alertMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            alertManager.dismissAlert()
                        }
                        .font(.body.weight(.medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        
                        if alertManager.alertType == .success {
                            Button("Continue") {
                                alertManager.dismissAlert()
                            }
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(alertManager.alertType.color)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(radius: 20)
                )
                .padding(.horizontal, 40)
            }
            .transition(.scale.combined(with: .opacity))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: alertManager.isShowingAlert)
        }
    }
}

// MARK: - API Service
class HeartRateAPIService: ObservableObject {
    private let baseURL = "http://14.139.187.229:8081/PDD-2025(9thmonth)/corecare/heartbeat.php"
    private var userId: Int = 1
    
    func updateUserId(_ newUserId: Int) {
        self.userId = newUserId
        print("HeartRateAPIService: Updated userId to \(newUserId)")
    }
    
    func fetchLatestHeartRate() async throws -> Int {
        guard await isServerReachable() else {
            throw APIError.serverError("Server not reachable. Check your network connection.")
        }
        
        guard let url = URL(string: "\(baseURL)?user_id=\(userId)&type=latest") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(httpResponse.statusCode)
            }
            
            let responseData = try JSONDecoder().decode(LatestHeartRateResponse.self, from: data)
            
            if responseData.status == "success" {
                return responseData.bpm ?? 0
            } else {
                throw APIError.serverError(responseData.message ?? "Unknown error")
            }
        } catch {
            print("API Error: \(error)")
            throw error
        }
    }
    
    func storeHeartRate(bpm: Int) async throws {
        guard let url = URL(string: baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let payload = HeartRatePayload(user_id: userId, bpm: bpm)
        request.httpBody = try JSONEncoder().encode(payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(httpResponse.statusCode)
            }
            
            let responseData = try JSONDecoder().decode(StoreHeartRateResponse.self, from: data)
            
            if responseData.status != "success" {
                throw APIError.serverError(responseData.message ?? "Failed to store heart rate")
            }
        } catch {
            print("Store API Error: \(error)")
            throw error
        }
    }
    
    func fetchHeartRateHistory() async throws -> [HeartRateEntry] {
        guard let url = URL(string: "\(baseURL)?user_id=\(userId)&type=history") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                throw APIError.httpError(httpResponse.statusCode)
            }
            
            let responseData = try JSONDecoder().decode(HeartRateHistoryResponse.self, from: data)
            
            if responseData.status == "success" {
                return responseData.records?.compactMap { record in
                    guard let bpm = record.bpm,
                          let timestampString = record.created_at else {
                        return nil
                    }
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    formatter.timeZone = TimeZone.current
                    
                    guard let timestamp = formatter.date(from: timestampString) else {
                        return nil
                    }
                    
                    return HeartRateEntry(timestamp: timestamp, bpm: bpm)
                } ?? []
            } else {
                throw APIError.serverError(responseData.message ?? "Failed to fetch history")
            }
        } catch {
            print("History API Error: \(error)")
            throw error
        }
    }
    
    private func isServerReachable() async -> Bool {
        guard let url = URL(string: "\(baseURL)?user_id=1&type=latest") else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            request.httpMethod = "GET"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            print("Server reachability error: \(error)")
            return false
        }
    }
}

// MARK: - API Models
struct LatestHeartRateResponse: Codable {
    let status: String
    let bpm: Int?
    let category: String?
    let message: String?
    let timestamp: String?
}

struct StoreHeartRateResponse: Codable {
    let status: String
    let message: String?
    let bpm: Int?
    let timestamp: String?
}

struct HeartRateHistoryResponse: Codable {
    let status: String
    let message: String?
    let records: [HeartRateHistoryRecord]?
}

struct HeartRateHistoryRecord: Codable {
    let bpm: Int?
    let created_at: String?
}

struct HeartRatePayload: Codable {
    let user_id: Int
    let bpm: Int
}

enum APIError: Error, LocalizedError {
    case serverError(String)
    case invalidResponse
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .serverError(let message):
            return message
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        }
    }
}

// MARK: - PRODUCTION-READY PPG CAMERA CONTROLLER WITH ENHANCED ACCURACY
class PPGCameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var onBPMDetectedHandler: AnyObject?
    weak var onFingerDetectedHandler: AnyObject?
    weak var onFingerPlacementQualityHandler: AnyObject?
    
    private var bpmCallback: ((Int) -> Void)?
    private var fingerCallback: ((Bool) -> Void)?
    private var qualityCallback: ((Float) -> Void)?
    
    private var videoFrameCounter: Int = 0
    private var lastFrameTimestamp: Date = Date()
    private let frameDropThreshold: TimeInterval = 3.0
    
    var onBPMDetected: ((Int) -> Void)? {
        get { return bpmCallback }
        set { bpmCallback = newValue }
    }
    
    var onFingerDetected: ((Bool) -> Void)? {
        get { return fingerCallback }
        set { fingerCallback = newValue }
    }
    
    var onFingerPlacementQuality: ((Float) -> Void)? {
        get { return qualityCallback }
        set { qualityCallback = newValue }
    }
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // ENHANCED: Buffer for 15-second measurement window at 30 FPS
    private var frameBuffer: [Float] = []
    private let bufferSize = 600  // Up to 20 seconds at 30 FPS
    
    private var isMeasuring = false
    private var fingerDetected = false
    private var torchLevel: Float = 1.0
    private var measurementStartTime: Date?
    private var currentDevice: AVCaptureDevice?
    private var isConfiguring = false
    private var isCleaningUp = false
    
    private var brightnessHistory: [Float] = []
    private let brightnessHistorySize = 30
    
    private let fingerDetectionBrightnessMin: Float = 0.05
    private let fingerDetectionStability: Float = 0.05
    private let minRedChannelValue: Float = 35.0
    
    private func getAdaptiveFingerThreshold(brightness: Float) -> Float {
        if brightness > 0.6 { return 0.04 }
        if brightness > 0.3 { return 0.05 }
        if brightness > 0.15 { return 0.06 }
        return 0.08
    }
    
    private var measurementTimeout: Timer?
    private let maxMeasurementTime: TimeInterval = 90  // 90 seconds timeout
    
    private let cameraQueue = DispatchQueue(label: "camera.ppg.queue", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "processing.ppg.queue", qos: .userInitiated)
    
    // ENHANCED: Robust validation
    private var consecutiveValidSamples = 0
    private let requiredConsecutiveValidSamples = 3
    private var bpmAlreadySent = false
    
    // ENHANCED: Signal quality tracking
    private var lastCalculatedBPM = 0
    private var bpmHistory: [Int] = []
    private let maxBPMHistorySize = 10
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        print("🔧 PRODUCTION-READY PPG Controller with ENHANCED ACCURACY")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async { [weak self] in
            self?.previewLayer?.frame = self?.view.bounds ?? .zero
        }
    }
    
    func startMeasurement() {
        print("🚀 Starting ENHANCED PPG measurement (30-second window)...")
        cameraQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            guard !strongSelf.isMeasuring && !strongSelf.isCleaningUp else {
                print("Already measuring or cleaning up")
                return
            }
            
            strongSelf.isMeasuring = true
            strongSelf.frameBuffer.removeAll()
            strongSelf.brightnessHistory.removeAll()
            strongSelf.bpmHistory.removeAll()
            strongSelf.consecutiveValidSamples = 0
            strongSelf.bpmAlreadySent = false
            strongSelf.measurementStartTime = Date()
            
            DispatchQueue.main.async { [weak self] in
                self?.startMeasurementTimeout()
            }
            
            strongSelf.checkCameraPermission { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ Camera permission granted")
                        self?.startCamera()
                    } else {
                        print("❌ Camera permission denied")
                        self?.safeCallBPMCallback(0)
                    }
                }
            }
        }
    }
    
    private func safeCallBPMCallback(_ bpm: Int) {
        guard !isCleaningUp else { return }
        guard !bpmAlreadySent else {
            print("⚠️ BPM already sent, ignoring duplicate")
            return
        }
        
        bpmAlreadySent = true
        print("📞 Calling BPM callback with: \(bpm) BPM")
        
        DispatchQueue.main.async { [weak self] in
            self?.bpmCallback?(bpm)
            self?.stopMeasurement()
        }
    }
    
    private func safeCallFingerCallback(_ detected: Bool) {
        guard !isCleaningUp else { return }
        fingerCallback?(detected)
    }
    
    private func safeCallQualityCallback(_ quality: Float) {
        guard !isCleaningUp else { return }
        qualityCallback?(quality)
    }
    
    private func startMeasurementTimeout() {
        measurementTimeout?.invalidate()
        measurementTimeout = Timer.scheduledTimer(withTimeInterval: maxMeasurementTime, repeats: false) { [weak self] _ in
            print("⏰ Measurement timeout reached")
            DispatchQueue.main.async {
                self?.safeCallBPMCallback(0)
            }
        }
    }
    
    private func stopMeasurementTimeout() {
        measurementTimeout?.invalidate()
        measurementTimeout = nil
    }
    
    func stopMeasurement() {
        print("🛑 Stopping ENHANCED PPG measurement...")
        bpmCallback = nil
        fingerCallback = nil
        qualityCallback = nil
        
        cameraQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            guard !strongSelf.isCleaningUp else { return }
            
            strongSelf.isCleaningUp = true
            strongSelf.isMeasuring = false
            strongSelf.fingerDetected = false
            
            DispatchQueue.main.async { [weak self] in
                self?.stopMeasurementTimeout()
            }
            
            strongSelf.turnOffTorchSync()
            
            if let session = strongSelf.captureSession, session.isRunning {
                while strongSelf.isConfiguring {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                session.stopRunning()
                print("✅ Capture session stopped")
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.previewLayer?.removeFromSuperlayer()
                self?.previewLayer = nil
                self?.captureSession = nil
                self?.currentDevice = nil
                self?.frameBuffer.removeAll()
                self?.brightnessHistory.removeAll()
                self?.bpmHistory.removeAll()
                self?.consecutiveValidSamples = 0
                self?.isCleaningUp = false
            }
        }
    }
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }
    
    private func startCamera() {
        cameraQueue.async { [weak self] in
            self?.setupCameraSession()
        }
    }
    
    private func setupCameraSession() {
        print("📹 Setting up enhanced camera session...")
        guard isMeasuring && !isCleaningUp else {
            print("❌ Measurement stopped before camera setup")
            return
        }
        
        let session = AVCaptureSession()
        isConfiguring = true
        session.beginConfiguration()
        session.sessionPreset = .high
        
        var device: AVCaptureDevice?
        device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
        if device == nil {
            device = AVCaptureDevice.default(for: .video)
        }
        
        if device == nil {
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        
        if device == nil {
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
                mediaType: .video,
                position: .unspecified
            )
            device = discoverySession.devices.first
        }
        
        guard let finalDevice = device else {
            print("❌ No camera available")
            isConfiguring = false
            DispatchQueue.main.async { [weak self] in
                self?.safeCallBPMCallback(0)
            }
            return
        }
        
        currentDevice = finalDevice
        print("📱 Camera device found: \(finalDevice.localizedName)")
        
        do {
            let input = try AVCaptureDeviceInput(device: finalDevice)
            if session.canAddInput(input) {
                session.addInput(input)
                print("✅ Camera input added successfully")
            } else {
                print("❌ Cannot add camera input to session")
                isConfiguring = false
                DispatchQueue.main.async { [weak self] in
                    self?.safeCallBPMCallback(0)
                }
                return
            }
        } catch {
            print("❌ Camera input error: \(error)")
            isConfiguring = false
            DispatchQueue.main.async { [weak self] in
                self?.safeCallBPMCallback(0)
            }
            return
        }
        
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: processingQueue)
        output.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(output) {
            session.addOutput(output)
            print("✅ Video output added successfully")
        } else {
            print("❌ Cannot add video output to session")
            isConfiguring = false
            DispatchQueue.main.async { [weak self] in
                self?.safeCallBPMCallback(0)
            }
            return
        }
        
        configureCameraForPPG(device: finalDevice)
        session.commitConfiguration()
        isConfiguring = false
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, strongSelf.isMeasuring && !strongSelf.isCleaningUp else { return }
            
            strongSelf.captureSession = session
            strongSelf.previewLayer = AVCaptureVideoPreviewLayer(session: session)
            strongSelf.previewLayer?.videoGravity = .resizeAspectFill
            strongSelf.previewLayer?.frame = strongSelf.view.bounds
            strongSelf.view.layer.addSublayer(strongSelf.previewLayer!)
            
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                print("📹 Capture session running: \(session.isRunning)")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let device = strongSelf.currentDevice, strongSelf.isMeasuring {
                        strongSelf.configureTorch(device: device)
                    }
                }
            }
        }
    }
    
    private func configureCameraForPPG(device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            if device.activeFormat.videoSupportedFrameRateRanges.first != nil {
                device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: 30)
                print("📊 Frame rate set to 30 FPS")
            }
            
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
                print("🔒 Exposure locked")
            }
            
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
                print("🎯 Focus locked")
            }
            
            if device.isWhiteBalanceModeSupported(.locked) {
                device.whiteBalanceMode = .locked
                print("🌡️ White balance locked")
            }
            
            device.unlockForConfiguration()
            print("✅ Camera configured for PPG")
        } catch {
            print("❌ Camera configuration error: \(error)")
        }
    }
    
    private func configureTorch(device: AVCaptureDevice) {
        print("🔦 Configuring torch with maximum brightness...")
        cameraQueue.async {
            guard device.isTorchAvailable else {
                print("❌ Torch not available")
                DispatchQueue.main.async { [weak self] in
                    self?.safeCallBPMCallback(0)
                }
                return
            }
            
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                
                if device.isTorchModeSupported(.on) {
                    try device.setTorchModeOn(level: self.torchLevel)
                    
                    if device.torchMode != .on {
                        print("❌ Torch command failed")
                        DispatchQueue.main.async { [weak self] in
                            self?.safeCallBPMCallback(0)
                        }
                        return
                    }
                    
                    print("✅ Torch ON at level \(self.torchLevel)")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self] in
                        if let device = self?.currentDevice, device.torchMode == .on {
                            do {
                                try device.lockForConfiguration()
                                device.torchMode = .off
                                device.unlockForConfiguration()
                                print("⚠️ Auto-disabled torch after 90 seconds")
                            } catch {
                                print("Error disabling torch: \(error)")
                            }
                        }
                    }
                } else {
                    print("❌ Torch mode .on not supported")
                    DispatchQueue.main.async { [weak self] in
                        self?.safeCallBPMCallback(0)
                    }
                }
            } catch {
                print("❌ Torch lock error: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.safeCallBPMCallback(0)
                }
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                      didOutput sampleBuffer: CMSampleBuffer,
                      from connection: AVCaptureConnection) {
        guard isMeasuring && !isCleaningUp && !bpmAlreadySent else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        videoFrameCounter += 1
        let timeSinceLastFrame = Date().timeIntervalSince(lastFrameTimestamp)
        
        if timeSinceLastFrame > frameDropThreshold {
            print("❌ No video frames for \(String(format: "%.1f", timeSinceLastFrame))s")
            DispatchQueue.main.async { [weak self] in
                self?.safeCallBPMCallback(0)
            }
            stopMeasurement()
            return
        }
        
        lastFrameTimestamp = Date()
        
        let (isFingerDetected, _, quality) = detectFingerPlacement(in: pixelBuffer)
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, !strongSelf.isCleaningUp else { return }
            
            if strongSelf.fingerDetected != isFingerDetected {
                strongSelf.fingerDetected = isFingerDetected
                strongSelf.safeCallFingerCallback(isFingerDetected)
            }
            
            strongSelf.safeCallQualityCallback(quality)
        }
        
        guard isFingerDetected && quality >= 0.15 else { return }
        
        if let signalSample = extractPPGSignal(from: pixelBuffer) {
            processingQueue.async {
                self.processPPGSample(signalSample)
            }
        }
    }
    
    private func detectFingerPlacement(in pixelBuffer: CVPixelBuffer) -> (Bool, Float, Float) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return (false, 0.0, 0.0)
        }
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        var totalRed: Float = 0
        var totalGreen: Float = 0
        var totalBlue: Float = 0
        var count: Int = 0
        
        let sampleSize = min(120, min(width, height))
        let startX = (width - sampleSize) / 2
        let startY = (height - sampleSize) / 2
        
        for y in startY..<(startY + sampleSize) {
            for x in startX..<(startX + sampleSize) {
                let offset = y * bytesPerRow + x * 4
                if offset + 2 < bytesPerRow * height {
                    let b = Float(buffer[offset + 0])
                    let g = Float(buffer[offset + 1])
                    let r = Float(buffer[offset + 2])
                    
                    totalRed += r
                    totalGreen += g
                    totalBlue += b
                    count += 1
                }
            }
        }
        
        guard count > 0 else { return (false, 0.0, 0.0) }
        
        let avgRed = totalRed / Float(count)
        let avgGreen = totalGreen / Float(count)
        let avgBlue = totalBlue / Float(count)
        
        let brightness = (avgRed + avgGreen + avgBlue) / (3.0 * 255.0)
        
        brightnessHistory.append(brightness)
        if brightnessHistory.count > brightnessHistorySize {
            brightnessHistory.removeFirst()
        }
        
        // Biological finger placement characteristics with camera torch:
        // 1. Red channel is high due to torch light passing through blood-perfused skin tissue (>= 45.0)
        // 2. Green and Blue are strongly absorbed by hemoglobin, making Red clearly dominant
        // 3. Red ratio: avgRed / (avgGreen + avgBlue) >= 0.75 without any artificial upper limit
        let redRatio = avgRed / max(avgGreen + avgBlue, 1.0)
        let isRedDominant = (avgRed > avgGreen * 1.12) && (avgRed > avgBlue * 1.25)
        let isFingerPresent = (avgRed >= 45.0) && isRedDominant && (redRatio >= 0.75) && (brightness >= 0.05)
        
        var quality: Float = 0.0
        if isFingerPresent {
            // Stability based on brightness variance
            var stability: Float = 0.8
            if brightnessHistory.count >= 5 {
                let mean = brightnessHistory.reduce(0, +) / Float(brightnessHistory.count)
                let variance = brightnessHistory.map { pow($0 - mean, 2) }.reduce(0, +) / Float(brightnessHistory.count)
                stability = max(0.0, min(1.0, 1.0 - (variance / 0.01)))
            }
            // Signal strength based on red dominance ratio
            let ratioQuality = min(redRatio / 1.5, 1.0)
            quality = min(max(stability * 0.4 + ratioQuality * 0.6, 0.2), 1.0)
        }
        
        return (isFingerPresent, brightness, quality)
    }
    
    private func extractPPGSignal(from pixelBuffer: CVPixelBuffer) -> Float? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        var totalRed: Float = 0
        var totalGreen: Float = 0
        var count: Int = 0
        
        let sampleSize = min(120, min(width, height))
        let startX = (width - sampleSize) / 2
        let startY = (height - sampleSize) / 2
        
        for y in startY..<(startY + sampleSize) {
            for x in startX..<(startX + sampleSize) {
                let offset = y * bytesPerRow + x * 4
                if offset + 2 < bytesPerRow * height {
                    let g = Float(buffer[offset + 1])
                    let r = Float(buffer[offset + 2])
                    totalRed += r
                    totalGreen += g
                    count += 1
                }
            }
        }
        
        guard count > 0 else { return nil }
        
        let avgRed = totalRed / Float(count)
        let avgGreen = totalGreen / Float(count)
        guard avgRed > minRedChannelValue else { return nil }
        
        // If red channel saturates (> 220), use green channel which has high hemoglobin
        // absorption pulsatility without clipping
        if avgRed > 220.0 {
            return 255.0 - avgGreen
        } else {
            return avgRed
        }
    }
    
    private func processPPGSample(_ sampleValue: Float) {
        guard isMeasuring && !isCleaningUp && !bpmAlreadySent else { return }
        
        frameBuffer.append(sampleValue)
        
        if frameBuffer.count > bufferSize {
            frameBuffer.removeFirst()
        }
        
        // Intermediate calculation after ~7 seconds (210 frames at 30 FPS)
        if frameBuffer.count >= 210 && frameBuffer.count % 15 == 0 {
            let bpm = calculateAccurateHeartRate(from: frameBuffer)
            print("💓 Intermediate Calculated BPM: \(bpm) from \(frameBuffer.count) samples")
            
            if bpm >= 45 && bpm <= 190 {
                bpmHistory.append(bpm)
                if bpmHistory.count > maxBPMHistorySize {
                    bpmHistory.removeFirst()
                }
                
                consecutiveValidSamples += 1
                print("✅ Valid BPM reading (\(consecutiveValidSamples)/\(requiredConsecutiveValidSamples))")
                
                // If we have high confidence (3 consecutive matching samples) and at least 300 samples (10s)
                if consecutiveValidSamples >= 3 && frameBuffer.count >= 300 {
                    let finalBPM = calculateMedianBPM()
                    print("🎉 EARLY SUCCESS: Got steady readings! Final BPM: \(finalBPM)")
                    DispatchQueue.main.async { [weak self] in
                        self?.stopMeasurementTimeout()
                        self?.safeCallBPMCallback(finalBPM)
                    }
                }
            } else {
                consecutiveValidSamples = 0
            }
        }
    }
    
    @discardableResult
    func finishMeasurementAndDeliver() -> Int {
        guard !bpmAlreadySent else { return lastCalculatedBPM }
        print("🏁 Finishing measurement with \(frameBuffer.count) samples in buffer")
        
        var finalBPM = 0
        if frameBuffer.count >= 150 { // At least 5 seconds of signal data
            let computed = calculateAccurateHeartRate(from: frameBuffer)
            if computed >= 45 && computed <= 195 {
                bpmHistory.append(computed)
            }
        }
        
        if !bpmHistory.isEmpty {
            finalBPM = calculateMedianBPM()
        }
        
        if finalBPM >= 45 && finalBPM <= 195 {
            print("🎉 Final Measurement Delivered: \(finalBPM) BPM")
            DispatchQueue.main.async { [weak self] in
                self?.stopMeasurementTimeout()
                self?.safeCallBPMCallback(finalBPM)
            }
            return finalBPM
        } else {
            print("⚠️ Could not determine reliable BPM from buffer")
            return 0
        }
    }
    
    private func calculateMedianBPM() -> Int {
        guard !bpmHistory.isEmpty else { return lastCalculatedBPM }
        let sorted = bpmHistory.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }
    
    private func calculateAccurateHeartRate(from signal: [Float]) -> Int {
        let n = signal.count
        guard n >= 150 else { return 0 }
        
        // FFT needs Hamming window + detrending to prevent spectral leakage
        let fftSignal = preprocessPPGSignalForFFT(signal)
        let fftBPM = performFFTHeartRateAnalysis(fftSignal)
        
        // Time domain and Autocorrelation need non-windowed smoothed signal
        let timeSignal = preprocessPPGSignalForTimeDomain(signal)
        let timeDomainBPM = calculateTimeDomainHeartRate(from: timeSignal)
        let autocorrBPM = performAutocorrelationAnalysis(timeSignal)
        
        print("📊 Method Results - FFT: \(fftBPM), Time Domain: \(timeDomainBPM), Autocorr: \(autocorrBPM)")
        
        let bestBPM = selectBestMethodRobust(fft: fftBPM, timeDomain: timeDomainBPM, autocorr: autocorrBPM)
        if bestBPM > 0 {
            lastCalculatedBPM = bestBPM
        }
        return bestBPM
    }

    private func preprocessPPGSignalForFFT(_ signal: [Float]) -> [Float] {
        let n = signal.count
        guard n >= 64 else { return signal }
        
        // Step 1: Remove DC component
        var mean: Float = 0
        vDSP_meanv(signal, 1, &mean, vDSP_Length(n))
        var detrended = [Float](repeating: 0, count: n)
        var negMean = -mean
        vDSP_vsadd(signal, 1, &negMean, &detrended, 1, vDSP_Length(n))
        
        // Step 2: Apply Hamming window
        var window = [Float](repeating: 0, count: n)
        vDSP_hamm_window(&window, vDSP_Length(n), 0)
        var windowedSignal = [Float](repeating: 0, count: n)
        vDSP_vmul(detrended, 1, window, 1, &windowedSignal, 1, vDSP_Length(n))
        
        // Step 3: Apply high-pass filter
        let filtered = applyHighPassFilter(windowedSignal)
        
        // Step 4: Normalize
        var maxVal: Float = 0
        vDSP_maxv(filtered.map { abs($0) }, 1, &maxVal, vDSP_Length(n))
        
        if maxVal > 0 {
            var normalized = [Float](repeating: 0, count: n)
            var divisor = maxVal
            vDSP_vsdiv(filtered, 1, &divisor, &normalized, 1, vDSP_Length(n))
            return normalized
        }
        
        return filtered
    }

    private func preprocessPPGSignalForTimeDomain(_ signal: [Float]) -> [Float] {
        let n = signal.count
        guard n >= 16 else { return signal }
        
        // Step 1: Remove DC baseline
        var mean: Float = 0
        vDSP_meanv(signal, 1, &mean, vDSP_Length(n))
        var detrended = [Float](repeating: 0, count: n)
        var negMean = -mean
        vDSP_vsadd(signal, 1, &negMean, &detrended, 1, vDSP_Length(n))
        
        // Step 2: High pass filter (cutoff ~0.6 Hz) to eliminate slow baseline drift without differentiating
        let hpFiltered = applyHighPassFilter(detrended)
        
        // Step 3: 5-point weighted moving average smoothing to eliminate camera sensor noise
        var smoothed = hpFiltered
        for i in 2..<(n - 2) {
            smoothed[i] = (hpFiltered[i - 2] + 2.0 * hpFiltered[i - 1] + 3.0 * hpFiltered[i] + 2.0 * hpFiltered[i + 1] + hpFiltered[i + 2]) / 9.0
        }
        return smoothed
    }

    private func applyHighPassFilter(_ signal: [Float]) -> [Float] {
        let n = signal.count
        guard n >= 10 else { return signal }
        
        // Standard discrete 1-pole high-pass filter: y[n] = alpha * (y[n-1] + x[n] - x[n-1])
        // With alpha = 0.92, cutoff is ~0.6 Hz at 30 FPS. This preserves the cardiac wave while removing baseline wander.
        var output = [Float](repeating: 0, count: n)
        let alpha: Float = 0.92
        output[0] = 0
        
        for i in 1..<n {
            output[i] = alpha * (output[i - 1] + signal[i] - signal[i - 1])
        }
        
        return output
    }

    private func performFFTHeartRateAnalysis(_ signal: [Float]) -> Int {
        let n = signal.count
        let log2n = vDSP_Length(floor(log2(Float(n))))
        let fftLength = 1 << log2n
        guard fftLength >= 64 else { return 0 }
        
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return 0 }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var real = Array(signal.prefix(fftLength))
        var imag = [Float](repeating: 0, count: fftLength)
        var bpmResult = 0
        
        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                guard let realBaseAddress = realPtr.baseAddress,
                      let imagBaseAddress = imagPtr.baseAddress else { return }
                
                var splitComplex = DSPSplitComplex(
                    realp: realBaseAddress,
                    imagp: imagBaseAddress
                )
                
                vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, Int32(kFFTDirection_Forward))
                
                var magnitudes = [Float](repeating: 0, count: fftLength / 2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftLength / 2))
                
                let samplingRate: Float = 30.0
                let freqResolution = samplingRate / Float(fftLength)
                
                // Physiological frequency range: 0.75 Hz (45 BPM) to 3.0 Hz (180 BPM)
                let lowIndex = max(Int(0.75 / freqResolution), 1)
                let highIndex = min(Int(3.0 / freqResolution), magnitudes.count - 1)
                
                guard lowIndex < highIndex else { return }
                
                // Collect all local peaks in the physiological band
                var peaks: [(index: Int, magnitude: Float)] = []
                for i in lowIndex...highIndex {
                    let isPeak = (i > lowIndex && i < highIndex) ? 
                        (magnitudes[i] >= magnitudes[i - 1] && magnitudes[i] >= magnitudes[i + 1]) : true
                    if isPeak && magnitudes[i] > 0 {
                        peaks.append((index: i, magnitude: magnitudes[i]))
                    }
                }
                
                guard let topPeak = peaks.max(by: { $0.magnitude < $1.magnitude }) else { return }
                var selectedIndex = topPeak.index
                
                let rawFreq = Float(topPeak.index) * freqResolution
                let rawBPM = rawFreq * 60.0
                
                // Anti-doubling harmonic correction:
                // If top peak is > 100 BPM (e.g., 129, 154 BPM), check if there is a fundamental peak at half frequency (~50-80 BPM)
                if rawBPM > 100.0 {
                    let halfIndex = Int(round(Float(topPeak.index) / 2.0))
                    if let fundPeak = peaks.first(where: { abs($0.index - halfIndex) <= 1 && $0.magnitude >= topPeak.magnitude * 0.20 }) {
                        print("🔄 FFT: Detected 2nd harmonic at \(Int(round(rawBPM))) BPM, selecting fundamental peak at index \(fundPeak.index)")
                        selectedIndex = fundPeak.index
                    }
                }
                
                let refinedPeakIndex = refineFrequencyPeak(magnitudes, selectedIndex)
                let frequency = refinedPeakIndex * freqResolution
                bpmResult = Int(round(frequency * 60))
                bpmResult = validateAndSmoothBPM(bpmResult)
            }
        }
        
        return bpmResult
    }

    private func refineFrequencyPeak(_ magnitudes: [Float], _ peakIndex: Int) -> Float {
        guard peakIndex > 0 && peakIndex < magnitudes.count - 1 else { return Float(peakIndex) }
        
        let y1 = magnitudes[peakIndex - 1]
        let y2 = magnitudes[peakIndex]
        let y3 = magnitudes[peakIndex + 1]
        
        let a = (y1 - 2 * y2 + y3) / 2
        let b = (y3 - y1) / 2
        
        if abs(a) > 0.001 {
            let xOffset = -b / (2 * a)
            return Float(peakIndex) + xOffset
        }
        
        return Float(peakIndex)
    }

    private func calculateTimeDomainHeartRate(from signal: [Float]) -> Int {
        let n = signal.count
        guard n >= 90 else { return 0 }
        
        var mean: Float = 0
        vDSP_meanv(signal, 1, &mean, vDSP_Length(n))
        
        var variance: Float = 0
        let dev = signal.map { ($0 - mean) * ($0 - mean) }
        vDSP_meanv(dev, 1, &variance, vDSP_Length(n))
        let stdDev = sqrt(variance)
        
        // Threshold for systolic peak
        let threshold = mean + 0.30 * stdDev
        
        // Step 1: Detect all local maxima above threshold
        var candidatePeaks: [(index: Int, value: Float)] = []
        for i in 2..<(n - 2) {
            if signal[i] > threshold && 
               signal[i] > signal[i - 1] && signal[i] >= signal[i + 1] &&
               signal[i] > signal[i - 2] && signal[i] >= signal[i + 2] {
                candidatePeaks.append((index: i, value: signal[i]))
            }
        }
        
        guard candidatePeaks.count >= 3 else { return 0 }
        
        // Step 2: Dicrotic notch suppression
        // A dicrotic notch is smaller than the systolic peak and occurs within 16 frames (< 112 BPM).
        // Suppress any smaller secondary peak that occurs within 16 frames of a dominant peak.
        var filteredPeaks: [Int] = []
        var lastPeakIndex = -100
        var lastPeakValue: Float = -1000
        
        for peak in candidatePeaks {
            if peak.index - lastPeakIndex < 16 {
                if peak.value > lastPeakValue {
                    if !filteredPeaks.isEmpty {
                        filteredPeaks.removeLast()
                    }
                    filteredPeaks.append(peak.index)
                    lastPeakIndex = peak.index
                    lastPeakValue = peak.value
                }
            } else {
                filteredPeaks.append(peak.index)
                lastPeakIndex = peak.index
                lastPeakValue = peak.value
            }
        }
        
        guard filteredPeaks.count >= 3 else { return 0 }
        
        var intervals: [Float] = []
        for i in 1..<filteredPeaks.count {
            let diff = Float(filteredPeaks[i] - filteredPeaks[i - 1])
            // Plausible beat-to-beat intervals: 13 frames (138 BPM) to 42 frames (43 BPM)
            if diff >= 13 && diff <= 42 {
                intervals.append(diff)
            }
        }
        
        guard intervals.count >= 2 else { return 0 }
        
        let sortedIntervals = intervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]
        
        let bpm = Int(round(30.0 * 60.0 / medianInterval))
        print("⏱️ Time domain - \(filteredPeaks.count) peaks, median interval: \(String(format: "%.1f", medianInterval)) frames = \(bpm) BPM")
        return (bpm >= 45 && bpm <= 180) ? bpm : 0
    }

    private func performAutocorrelationAnalysis(_ signal: [Float]) -> Int {
        let n = signal.count
        guard n >= 90 else { return 0 }
        
        // At 30 FPS:
        // Lag 13 = 138 BPM
        // Lag 42 = 43 BPM
        let minLag = 13
        let maxLag = min(42, n / 2)
        guard maxLag > minLag else { return 0 }
        
        var normalizer: Float = 0
        vDSP_dotpr(signal, 1, signal, 1, &normalizer, vDSP_Length(n))
        guard normalizer > 0 else { return 0 }
        
        var autocorr = [Float](repeating: 0, count: maxLag + 1)
        for lag in minLag...maxLag {
            var sum: Float = 0
            let len = vDSP_Length(n - lag)
            signal.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                vDSP_dotpr(base, 1, base.advanced(by: lag), 1, &sum, len)
            }
            autocorr[lag] = sum / normalizer
        }
        
        // Find local correlation peaks
        var peaks: [(lag: Int, corr: Float)] = []
        for lag in (minLag + 1)..<maxLag {
            if autocorr[lag] > autocorr[lag - 1] && autocorr[lag] >= autocorr[lag + 1] && autocorr[lag] > 0.15 {
                peaks.append((lag: lag, corr: autocorr[lag]))
            }
        }
        
        guard !peaks.isEmpty else { return 0 }
        
        let bestPeak = peaks.max(by: { $0.corr < $1.corr })!
        var chosenLag = bestPeak.lag
        
        // Anti-doubling: if chosenLag is fast (< 18 frames, i.e. > 100 BPM),
        // check if there is a fundamental period peak around 2 * chosenLag
        if chosenLag < 18 {
            let doubleLag = chosenLag * 2
            if let fundPeak = peaks.first(where: { abs($0.lag - doubleLag) <= 2 && $0.corr >= bestPeak.corr * 0.40 }) {
                print("🔄 Autocorr: detected subharmonic lag \(chosenLag), selecting fundamental lag \(fundPeak.lag)")
                chosenLag = fundPeak.lag
            }
        }
        
        let bpm = Int(round(30.0 * 60.0 / Float(chosenLag)))
        print("🔄 Autocorrelation - lag: \(chosenLag), correlation: \(String(format: "%.2f", bestPeak.corr)) = \(bpm) BPM")
        return (bpm >= 45 && bpm <= 180) ? bpm : 0
    }

    private func selectBestMethodRobust(fft: Int, timeDomain: Int, autocorr: Int) -> Int {
        var values = [fft, timeDomain, autocorr].filter { $0 >= 45 && $0 <= 180 }
        guard !values.isEmpty else { return 0 }
        
        // Harmonic reconciliation: if any method produced double (~2x) of another, normalize it down
        for i in 0..<values.count {
            for j in 0..<values.count {
                if i != j && values[i] > 100 {
                    let halved = values[i] / 2
                    if abs(halved - values[j]) <= 6 {
                        print("🔄 Harmonically reconciling doubled reading \(values[i]) -> \(halved) to match \(values[j])")
                        values[i] = halved
                    }
                }
            }
        }
        
        if values.count == 1 { return values[0] }
        
        // Check pairwise closeness within 8 BPM
        for i in 0..<values.count {
            for j in (i + 1)..<values.count {
                if abs(values[i] - values[j]) <= 8 {
                    let avg = (values[i] + values[j]) / 2
                    print("✅ Consensus BPM: \(avg)")
                    return avg
                }
            }
        }
        
        let sorted = values.sorted()
        let median = sorted[sorted.count / 2]
        print("ℹ️ Median of valid methods: \(median) BPM")
        return median
    }

    private func validateAndSmoothBPM(_ bpm: Int) -> Int {
        let minValid = 45
        let maxValid = 195
        
        guard bpm >= minValid && bpm <= maxValid else {
            print("⚠️ BPM \(bpm) invalid, returning 0")
            return 0
        }
        
        return bpm
    }
    
    private func turnOffTorchSync() {
        guard let device = currentDevice, device.hasTorch else {
            print("❌ No current device or torch not available")
            return
        }
        
        do {
            try device.lockForConfiguration()
            if device.torchMode == .on {
                device.torchMode = .off
                print("✅ Torch turned OFF")
            }
            device.unlockForConfiguration()
        } catch {
            print("❌ Error turning off torch: \(error)")
        }
    }
    
    deinit {
        print("💀 PPGCameraViewController deinit")
        bpmCallback = nil
        fingerCallback = nil
        qualityCallback = nil
        
        isCleaningUp = true
        isMeasuring = false
        measurementTimeout?.invalidate()
        measurementTimeout = nil
        
        let captureSessionToCleanup = captureSession
        let deviceToCleanup = currentDevice
        
        captureSession = nil
        currentDevice = nil
        
        DispatchQueue.global(qos: .background).async {
            if let device = deviceToCleanup, device.hasTorch {
                do {
                    try device.lockForConfiguration()
                    if device.torchMode == .on {
                        device.torchMode = .off
                        print("✅ Torch turned OFF in deinit")
                    }
                    device.unlockForConfiguration()
                } catch {
                    print("❌ Error turning off torch in deinit: \(error)")
                }
            }
            
            if let session = captureSessionToCleanup, session.isRunning {
                session.stopRunning()
                print("✅ Capture session stopped in deinit")
            }
        }
        
        print("💀 PPGCameraViewController deinit completed safely")
    }
}

// MARK: - SwiftUI Wrapper
struct PPGCameraView: UIViewControllerRepresentable {
    var onBPMDetected: (Int) -> Void
    var onFingerDetected: (Bool) -> Void
    var onFingerPlacementQuality: (Float) -> Void
    var onControllerReady: ((PPGCameraViewController) -> Void)? = nil
    
    func makeUIViewController(context: Context) -> PPGCameraViewController {
        let vc = PPGCameraViewController()
        vc.onBPMDetected = onBPMDetected
        vc.onFingerDetected = onFingerDetected
        vc.onFingerPlacementQuality = onFingerPlacementQuality
        onControllerReady?(vc)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: PPGCameraViewController, context: Context) {
        if !uiViewController.view.isHidden {
            uiViewController.startMeasurement()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {}
}

struct HRCheckView: View {
    @EnvironmentObject var userManager: UserManager
    @StateObject private var apiService = HeartRateAPIService()
    @StateObject private var alertManager = AlertManager()
    
    @State private var isMeasuring = false
    @State private var heartRate = "--"
    @State private var hrvData: [HeartRateEntry] = []
    @State private var pulseAnimation = false
    @State private var progress: CGFloat = 0
    @State private var measurementProgress: CGFloat = 0
    @State private var showHomePage = false
    @State private var fadeIn = false
    @State private var timer: Timer?
    @State private var fingerOverCamera = false
    @State private var scanningAnimation = false
    @State private var heartBeatPoints: [CGPoint] = []
    @State private var liveWaveformPoints: [Double] = []
    @State private var waveformOffset: CGFloat = 0
    @State private var fingerDetected = false
    @State private var fingerPlacementQuality: Float = 0.0
    @State private var isLoading = false
    @State private var connectionStatus = "Checking..."
    
    // Enhanced: Auto-refresh functionality
    @State private var autoRefreshTimer: Timer?
    @State private var refreshInterval: TimeInterval = 30
    @State private var lastRefreshTime = Date()
    @State private var realtimeMode = true
    
    // Enhanced: Chart scrolling states
    @State private var chartScrollPosition: CGFloat = 0
    @State private var showingAllData = false
    
    // Enhanced: Graphics states
    @State private var rotatingRings = false
    @State private var floatingParticles: [ParticleModel] = []
    @State private var heartPulseScale: CGFloat = 1.0
    @State private var backgroundGradientOffset: CGFloat = 0.0
    
    // Enhanced: Session tracking to prevent repeated alerts
    @State private var measurementSession = UUID()
    
    private var currentUserId: Int {
        let managerId = userManager.currentUserId
        print("HRCheckView - UserManager ID: \(managerId ?? -1)")
        if let managerId = managerId, managerId > 0 {
            return managerId
        } else {
            print("WARNING: No valid user ID available in HRCheckView!")
            return 1
        }
    }
    
    var body: some View {
        ZStack {
            enhancedBackgroundGradient
            
            mainContent
                .opacity(fadeIn ? 1 : 0)
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6)) { fadeIn = true }
                    generateInitialHeartBeatPoints()
                    validateUserSession()
                    loadDataImmediately()
                    startAutoRefresh()
                    initializeGraphics()
                }
                .onDisappear {
                    cleanupTimers()
                    alertManager.clearSession()
                }
            
            // Enhanced Alert Overlay
            EnhancedAlertView(alertManager: alertManager)
        }
        .fullScreenCover(isPresented: $showHomePage) {
            HomePageView(userId: -1)
        }
        .sheet(isPresented: $isMeasuring) {
            FixedMeasurementView(
                isMeasuring: $isMeasuring,
                progress: $measurementProgress,
                fingerOverCamera: $fingerOverCamera,
                scanningAnimation: $scanningAnimation,
                liveWaveformPoints: $liveWaveformPoints,
                waveformOffset: $waveformOffset,
                fingerDetected: $fingerDetected,
                fingerPlacementQuality: $fingerPlacementQuality,
                onComplete: { result in
                    handleMeasurementResult(result)
                }
            )
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
    
    private func validateUserSession() {
        print("Validating user session in HRCheckView...")
        print("UserManager isLoggedIn: \(userManager.isLoggedIn)")
        print("UserManager userData: \(userManager.userData?.user_id ?? -1)")
        print("Computed currentUserId: \(currentUserId)")
        apiService.updateUserId(currentUserId)
    }
    
    // Enhanced: Beautiful animated gradient background with floating elements
    private var enhancedBackgroundGradient: some View {
        ZStack {
            Color.appBackground2
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: backgroundGradientOffset)
            
            // Floating particles effect
            ForEach(floatingParticles, id: \.id) { particle in
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                particle.color.opacity(0.6),
                                particle.color.opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: particle.size
                        )
                    )
                    .frame(width: particle.size * 2, height: particle.size * 2)
                    .position(particle.position)
                    .opacity(particle.opacity)
                    .scaleEffect(particle.scale)
                    .blur(radius: particle.blur)
            }
            
            // Subtle animated mesh pattern
            GeometryReader { geometry in
                Path { path in
                    let spacing: CGFloat = 60
                    for i in stride(from: 0, through: geometry.size.width, by: spacing) {
                        path.move(to: CGPoint(x: i, y: 0))
                        path.addLine(to: CGPoint(x: i, y: geometry.size.height))
                    }
                    for i in stride(from: 0, through: geometry.size.height, by: spacing) {
                        path.move(to: CGPoint(x: 0, y: i))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: i))
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
                .opacity(0.3)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            backgroundGradientOffset = 1.0
        }
    }
    
    private var mainContent: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                enhancedHeaderView(geo: geo)
                
                ScrollView {
                    VStack(spacing: 32) {
                        enhancedHeartRateDisplay(geo: geo)
                        enhancedMeasureButton
                        enhancedHrvChartView(geo: geo)
                        
                        Spacer(minLength: geo.safeAreaInsets.bottom + 20)
                    }
                    .padding(.vertical)
                }
                .refreshable {
                    await refreshData()
                }
            }
        }
    }
    
    // Enhanced: Modern header with real-time status
    private func enhancedHeaderView(geo: GeometryProxy) -> some View {
        HStack {
            Button { fadeOutToHome() } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(Color.cardBackground)
                            .shadow(color: Color.cardShadow, radius: 8, x: 0, y: 4)
                    )
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                        .scaleEffect(heartPulseScale)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: heartPulseScale)
                    
                    Text("HeartScope Pro")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(connectionStatus == "Online" ? .green : .orange)
                            .frame(width: 8, height: 8)
                            .scaleEffect(connectionStatus == "Online" ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                     value: connectionStatus == "Online")
                        
                        Text(connectionStatus)
                            .font(.caption.weight(.medium))
                            .foregroundColor(connectionStatus == "Online" ? .green : .orange)
                    }
                    
                    if realtimeMode {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .rotationEffect(.degrees(isLoading ? 360 : 0))
                                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isLoading)
                            
                            Text("Live")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.blue.opacity(0.1))
                        )
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button {
                    realtimeMode.toggle()
                    if realtimeMode {
                        startAutoRefresh()
                    } else {
                        stopAutoRefresh()
                    }
                } label: {
                    Image(systemName: realtimeMode ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: realtimeMode ? [.orange, .red] : [.green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Button {
                    Task {
                        await refreshData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
                }
                .disabled(isLoading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, max(geo.safeAreaInsets.top, 44) + 8)
        .padding(.bottom, 16)
    }
    
    // Enhanced: Beautiful heart rate display with rich graphics and animations
    private func enhancedHeartRateDisplay(geo: GeometryProxy) -> some View {
        ZStack {
            // Animated background rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.red.opacity(0.3 - Double(index) * 0.1),
                                Color.pink.opacity(0.2 - Double(index) * 0.07),
                                Color.purple.opacity(0.1 - Double(index) * 0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4 - CGFloat(index)
                    )
                    .frame(width: geo.size.width * (0.8 + CGFloat(index) * 0.05))
                    .scaleEffect(rotatingRings ? 1.1 + CGFloat(index) * 0.05 : 1.0 - CGFloat(index) * 0.02)
                    .opacity(rotatingRings ? 0.8 - Double(index) * 0.2 : 0.4 - Double(index) * 0.1)
                    .rotationEffect(.degrees(rotatingRings ? Double(index * 120) : 0))
                    .animation(
                        .easeInOut(duration: 3 + Double(index))
                        .repeatForever(autoreverses: true),
                        value: rotatingRings
                    )
            }
            
            // Main circle with gradient and shadow effects
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.red.opacity(0.4),
                                Color.red.opacity(0.2),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.4
                        )
                    )
                    .scaleEffect(pulseAnimation ? 1.4 : 1.2)
                    .opacity(pulseAnimation ? 0.6 : 0.3)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: pulseAnimation
                    )
                
                // Inner glow
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.8),
                                Color.white.opacity(0.4),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.25
                        )
                    )
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                
                // Main display circle
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.95), location: 0.0),
                                .init(color: Color.white.opacity(0.85), location: 0.7),
                                .init(color: Color.gray.opacity(0.1), location: 1.0)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: geo.size.width * 0.65, height: geo.size.width * 0.65)
                    .overlay(
                        // Animated border
                        Circle()
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color.red,
                                        Color.pink,
                                        Color.purple,
                                        Color.blue,
                                        Color.red
                                    ]),
                                    center: .center
                                ),
                                lineWidth: 6
                            )
                            .rotationEffect(.degrees(rotatingRings ? 360 : 0))
                            .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: rotatingRings)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                    .animation(.easeInOut(duration: 1.2), value: pulseAnimation)
            }
            
            // Heart rate display content
            VStack(spacing: 16) {
                if isLoading {
                    // Enhanced loading animation
                    ZStack {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 6)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        .red, .pink, .purple, .clear
                                    ]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .rotationEffect(.degrees(isLoading ? 360 : 0))
                            .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isLoading)
                        
                        // Pulsing center dot
                        Circle()
                            .fill(.red)
                            .frame(width: 12, height: 12)
                            .scaleEffect(isLoading ? 1.3 : 0.8)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isLoading)
                    }
                } else {
                    // Heart rate number with enhanced styling
                    ZStack {
                        // Background number effect
                        Text(heartRate)
                            .font(.system(size: geo.size.width * 0.18, weight: .black, design: .rounded))
                            .foregroundStyle(.black.opacity(0.1))
                            .offset(x: 2, y: 2)
                        
                        // Main number
                        Text(heartRate)
                            .font(.system(size: geo.size.width * 0.16, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .contentTransition(.numericText())
                            .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pulseAnimation)
                    }
                    
                    // Last update indicator
                    if realtimeMode {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                            
                            Text("Live")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(.green.opacity(0.1))
                        )
                    }
                    
                    // BPM label with enhanced styling
                    HStack(spacing: 6) {
                        Text("BPM")
                            .font(.system(size: geo.size.width * 0.06, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.secondary, .secondary.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .tracking(4)
                        
                        if !isLoading && heartRate != "--" {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                                .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                        }
                    }
                    
                    // Mini waveform preview
                    if !heartBeatPoints.isEmpty && !isLoading {
                        miniHeartbeatWaveform(geo: geo)
                    }
                }
            }
        }
        .padding(.vertical, 40)
        .onAppear {
            pulseAnimation = true
            rotatingRings = true
            heartPulseScale = 1.1
        }
    }
    
    // Enhanced mini waveform display
    private func miniHeartbeatWaveform(geo: GeometryProxy) -> some View {
        ZStack {
            // Background waveform (dimmed)
            Path { path in
                for (index, point) in heartBeatPoints.enumerated() {
                    let x = point.x * 100
                    let y = 30 - (point.y * 20)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.red.opacity(0.3), lineWidth: 1.5)
            
            // Animated waveform
            Path { path in
                for (index, point) in heartBeatPoints.enumerated() {
                    let x = point.x * 100
                    let y = 30 - (point.y * 20)
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .trim(from: 0, to: pulseAnimation ? 1.0 : 0.7)
            .stroke(
                LinearGradient(
                    colors: [.red, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .animation(.easeInOut(duration: 2).repeatForever(), value: pulseAnimation)
        }
        .frame(width: 100, height: 30)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.05))
        )
    }
    
    // Enhanced: Modern measure button with better animations and graphics
    private var enhancedMeasureButton: some View {
        Button {
            measurementSession = UUID() // New session
            alertManager.clearSession() // Clear previous session alerts
            isMeasuring = true
            startMeasurementAnimation()
        } label: {
            HStack(spacing: 15) {
                ZStack {
                    // Animated background circle
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    .white.opacity(0.3),
                                    .white.opacity(0.1)
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 20
                            )
                        )
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                    
                    // Icon with pulse effect
                    Image(systemName: "waveform.path.ecg")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Measure Heart Rate")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                        
                        if realtimeMode {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                                .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                        }
                    }
                    
                    Text("FIXED: Place finger on camera + flash")
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                // Enhanced arrow with animation
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                        .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Background gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.red.opacity(0.9),
                                    Color.pink.opacity(0.8),
                                    Color.purple.opacity(0.7)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Animated overlay
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .white.opacity(0.1),
                                    .clear,
                                    .white.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(pulseAnimation ? 1.02 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
                }
            )
            .shadow(
                color: Color.red.opacity(0.5),
                radius: 20,
                x: 0,
                y: 10
            )
            .scaleEffect(isMeasuring ? 0.98 : 1.0)
        }
        .padding(.horizontal, 20)
        .disabled(isMeasuring || isLoading)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isMeasuring)
    }
    
    // Enhanced: Scrollable chart view with better design
    private func enhancedHrvChartView(geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "waveform.path.ecg")
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .font(.title3.weight(.semibold))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Heart Rate History")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundColor(.primary)
                            
                            if realtimeMode && !hrvData.isEmpty {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseAnimation)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Text("\(hrvData.count) measurements")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.secondary)
                            
                            if let lastEntry = hrvData.first {
                                Text("• Latest: \(lastEntry.bpm) BPM")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Toggle for showing all data
                    Button(action: {
                        withAnimation(.spring()) {
                            showingAllData.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: showingAllData ? "chart.line.uptrend.xyaxis" : "chart.line.flattrend.xyaxis")
                                .font(.caption.weight(.semibold))
                            Text(showingAllData ? "Recent" : "All")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(showingAllData ? .blue.opacity(0.2) : .gray.opacity(0.2))
                        )
                        .foregroundColor(showingAllData ? .blue : .gray)
                    }
                    
                    Button(action: {
                        Task {
                            await loadHeartRateHistory()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(.blue.opacity(0.1))
                            )
                            .rotationEffect(.degrees(isLoading ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
                    }
                }
            }
            
            if hrvData.isEmpty {
                enhancedNoDataView(geo: geo)
            } else {
                enhancedChartView
            }
        }
        .padding(24)
        .glossyCard(cornerRadius: 24)
        .padding(.horizontal, 20)
    }
    
    // Enhanced: Better no data view with graphics
    private func enhancedNoDataView(geo: GeometryProxy) -> some View {
        VStack(spacing: 24) {
            ZStack {
                // Animated background rings
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.gray.opacity(0.2 - Double(index) * 0.1), .gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 100 + CGFloat(index * 20), height: 100 + CGFloat(index * 20))
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2 + Double(index)).repeatForever(autoreverses: true), value: pulseAnimation)
                }
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.gray.opacity(0.15), .gray.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.gray.opacity(0.6))
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            
            VStack(spacing: 12) {
                Text("No Heart Rate Data Yet")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(.primary)
                
                VStack(spacing: 6) {
                    Text("Start measuring to see your")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Text("heart rate history")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .multilineTextAlignment(.center)
            }
            
            Button("📊 Load History") {
                Task {
                    await loadHeartRateHistory()
                }
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.blue.opacity(0.1))
            )
            .foregroundColor(.blue)
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
    }
    
    // Enhanced: Scrollable chart with better design
    @ViewBuilder
    private var enhancedChartView: some View {
        if #available(iOS 16.0, *) {
            let displayData = showingAllData ? hrvData : Array(hrvData.prefix(10))
            
            VStack(alignment: .leading, spacing: 16) {
                if displayData.count > 10 {
                    Text("← Scroll to see more data →")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Chart(displayData) { entry in
                        // Line mark for connecting points
                        LineMark(
                            x: .value("Time", entry.timestamp),
                            y: .value("BPM", entry.bpm)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.white)
                        .lineStyle(.init(lineWidth: 2))
                        
                        // Add point markers
                        PointMark(
                            x: .value("Time", entry.timestamp),
                            y: .value("BPM", entry.bpm)
                        )
                        .foregroundStyle(.white)
                        .symbolSize(80)
                        
                        // Add area fill
                        AreaMark(
                            x: .value("Time", entry.timestamp),
                            yStart: .value("Zero", yAxisRange().lowerBound),
                            yEnd: .value("BPM", entry.bpm)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            .linearGradient(
                                colors: [
                                    .red.opacity(0.3),
                                    .pink.opacity(0.2),
                                    .purple.opacity(0.1),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.gray.opacity(0.2))
                            
                            // Custom date and time formatting
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    VStack(alignment: .center, spacing: 2) {
                                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.system(.caption2, design: .rounded).weight(.medium))
                                            .foregroundStyle(.secondary)
                                        Text(date.formatted(.dateTime.hour().minute()))
                                            .font(.system(.caption2, design: .rounded).weight(.bold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { value in
                            AxisGridLine()
                                .foregroundStyle(Color.gray.opacity(0.2))
                            AxisValueLabel()
                                .foregroundStyle(.secondary)
                                .font(.system(.caption, design: .rounded).weight(.medium))
                        }
                    }
                    .chartYScale(domain: yAxisRange())
                    .frame(width: max(600, CGFloat(displayData.count * 60)), height: 250)
                    .padding(.horizontal, 16)
                }
                .coordinateSpace(name: "chartScroll")
                
                // Enhanced chart legend with last update time
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(
                                .linearGradient(
                                    colors: [.red, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 12, height: 12)
                        
                        Text("Heart Rate")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if let firstEntry = displayData.first {
                            HStack(spacing: 6) {
                                Text("Latest:")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                
                                Text("\(firstEntry.bpm) BPM")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(
                                        .linearGradient(
                                            colors: [.red, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(.red.opacity(0.1))
                                    )
                            }
                        }
                        
                        if realtimeMode {
                            Text("Updated: \(lastRefreshTime.formatted(.dateTime.hour().minute()))")
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Enhanced: Automatic data loading and refresh functionality
    
    private func loadDataImmediately() {
        print("🚀 Loading heart rate data immediately...")
        Task {
            await loadLatestHeartRate()
            await loadHeartRateHistory()
        }
    }
    
    private func startAutoRefresh() {
        guard realtimeMode else { return }
        print("🔄 Starting auto-refresh with interval: \(refreshInterval) seconds")
        
        stopAutoRefresh() // Stop any existing timer
        
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            print("🔄 Auto-refreshing heart rate data...")
            Task {
                await refreshData()
            }
        }
    }
    
    private func stopAutoRefresh() {
        print("⏸️ Stopping auto-refresh")
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    private func cleanupTimers() {
        print("🧹 Cleaning up all timers")
        timer?.invalidate()
        timer = nil
        autoRefreshTimer?.invalidate()
        autoRefreshTimer = nil
    }
    
    // Enhanced: Graphics initialization
    private func initializeGraphics() {
        print("🎨 Initializing graphics and animations")
        
        // Initialize floating particles
        floatingParticles = (0..<15).map { _ in
            ParticleModel(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                color: [.red, .pink, .purple, .blue].randomElement() ?? .red,
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.2...0.6),
                scale: CGFloat.random(in: 0.5...1.2),
                blur: CGFloat.random(in: 0.5...2.0)
            )
        }
        
        // Start particle animation
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 4)) {
                for index in floatingParticles.indices {
                    floatingParticles[index].position = CGPoint(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    floatingParticles[index].opacity = Double.random(in: 0.1...0.5)
                    floatingParticles[index].scale = CGFloat.random(in: 0.6...1.3)
                }
            }
        }
    }
    
    // FIXED: Handle measurement result with improved alert management
    private func handleMeasurementResult(_ result: MeasurementResult) {
        switch result {
        case .success(let bpm):
            handleMeasurementComplete(bpm: bpm)
        case .noFingerDetected:
            isMeasuring = false
            alertManager.showAlert(
                title: "👆 Finger Placement Fixed",
                message: "FIXED: The detection is now more sensitive. Please place your finger firmly over BOTH the camera lens and flash light. The flash should feel warm on your fingertip. 🔦",
                type: .warning,
                playBeep: true,
                autoDismissAfter: 7.0,
                preventDuplicate: true
            )
        case .timeout:
            isMeasuring = false
            alertManager.showAlert(
                title: "⏰ Measurement Timeout",
                message: "FIXED: Try again with better finger placement. Make sure to cover both camera and flash completely.",
                type: .error,
                playBeep: true,
                autoDismissAfter: 7.0,
                preventDuplicate: true
            )
        }
    }
    
    private func handleMeasurementComplete(bpm: Int) {
        if bpm == 0 {
            alertManager.showAlert(
                title: "❌ Measurement Failed",
                message: "FIXED: Please ensure your finger completely covers BOTH the camera and flash, then try again.",
                type: .error,
                playBeep: true,
                autoDismissAfter: 7.0,
                preventDuplicate: true
            )
            return
        }
        
        heartRate = String(bpm)
        let newEntry = HeartRateEntry(timestamp: Date(), bpm: bpm)
        hrvData.insert(newEntry, at: 0)
        
        if hrvData.count > 50 { // Store more data for scrolling
            hrvData = Array(hrvData.prefix(50))
        }
        
        isMeasuring = false
        
        // Show success alert with beep
        alertManager.showAlert(
            title: "🎉 Measurement Complete",
            message: "FIXED: Your heart rate is \(heartRate) BPM\nGreat job staying healthy! 💪",
            type: .success,
            playBeep: true,
            autoDismissAfter: 5.0,
            preventDuplicate: true
        )
        
        // Add enhanced haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Update last refresh time
        lastRefreshTime = Date()
        
        Task {
            do {
                try await apiService.storeHeartRate(bpm: bpm)
                await MainActor.run {
                    connectionStatus = "Online"
                }
                await loadHeartRateHistory()
            } catch {
                await MainActor.run {
                    connectionStatus = "Offline - Data saved locally"
                    storeOfflineData(bpm: bpm)
                    print("Failed to sync heart rate: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func storeOfflineData(bpm: Int) {
        var offlineData = UserDefaults.standard.array(forKey: "offline_heart_rates") as? [[String: Any]] ?? []
        let measurement: [String: Any] = [
            "bpm": bpm,
            "timestamp": Date().timeIntervalSince1970,
            "user_id": currentUserId
        ]
        
        offlineData.append(measurement)
        UserDefaults.standard.set(offlineData, forKey: "offline_heart_rates")
    }
    
    private func loadLatestHeartRate() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let latestBPM = try await apiService.fetchLatestHeartRate()
            await MainActor.run {
                if latestBPM > 0 {
                    heartRate = String(latestBPM)
                }
                connectionStatus = "Online"
                isLoading = false
                lastRefreshTime = Date()
            }
            print("✅ Latest heart rate loaded: \(latestBPM) BPM")
        } catch {
            await MainActor.run {
                connectionStatus = "Partial Connection"
                isLoading = false
                
                // Use latest from history if available
                if heartRate == "--" && !hrvData.isEmpty {
                    heartRate = String(hrvData.first!.bpm)
                    print("📊 Using latest from history: \(heartRate)")
                }
            }
            print("⚠️ Using history data due to API issue: \(error.localizedDescription)")
        }
    }
    
    private func loadHeartRateHistory() async {
        do {
            let history = try await apiService.fetchHeartRateHistory()
            await MainActor.run {
                hrvData = Array(history.prefix(50)) // Load more data for scrolling
                connectionStatus = "Online"
                lastRefreshTime = Date()
            }
            print("✅ Heart rate history loaded: \(history.count) entries")
        } catch {
            await MainActor.run {
                connectionStatus = "Offline"
                print("❌ Failed to load history: \(error.localizedDescription)")
            }
        }
    }
    
    private func refreshData() async {
        print("🔄 Refreshing heart rate data...")
        await loadLatestHeartRate()
        await loadHeartRateHistory()
    }
    
    private func startMeasurementAnimation() {
        measurementProgress = 0
        withAnimation(.linear(duration: 20)) { // Increased duration for more time
            measurementProgress = 1.0
        }
    }
    
    private func generateInitialHeartBeatPoints() {
        var points: [CGPoint] = []
        for i in 0..<50 {
            let x = CGFloat(i) / 50.0
            let y = 0.5 + 0.3 * sin(CGFloat(i) * 2 * .pi / 10)
            points.append(CGPoint(x: x, y: y))
        }
        heartBeatPoints = points
    }
    
    private func yAxisRange() -> ClosedRange<Int> {
        let bpms = hrvData.map { $0.bpm }
        guard let minBPM = bpms.min(), let maxBPM = bpms.max() else {
            return 60...100
        }
        
        let lower = max(minBPM - 15, 40)
        let upper = min(maxBPM + 15, 160)
        return lower...upper
    }
    
    private func fadeOutToHome() {
        withAnimation(.easeInOut(duration: 0.5)) { fadeIn = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showHomePage = true
        }
    }
}

// MARK: - Particle Model for Graphics

struct ParticleModel: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    var opacity: Double
    var scale: CGFloat
    let blur: CGFloat
}

// MARK: - Measurement Result Enum

enum MeasurementResult {
    case success(Int)
    case noFingerDetected
    case timeout
}

// MARK: - FIXED Measurement View with Proper Timer Animation

struct FixedMeasurementView: View {
    @Binding var isMeasuring: Bool
    @Binding var progress: CGFloat
    @Binding var fingerOverCamera: Bool
    @Binding var scanningAnimation: Bool
    @Binding var liveWaveformPoints: [Double]
    @Binding var waveformOffset: CGFloat
    @Binding var fingerDetected: Bool
    @Binding var fingerPlacementQuality: Float
    var onComplete: (MeasurementResult) -> Void
    
    @State private var countdown: Int = 15
    @State private var timerProgress: Double = 0.0
    @State private var measurementTimer: Timer?
    @State private var totalMeasurementTime: Double = 0.0
    
    @State private var timer: Timer?
    @State private var ppgView: PPGCameraView?
    @State private var ppgController: PPGCameraViewController?
    @State private var consecutiveLostFrames: Int = 0
    @State private var fingerDetectionTimer: Timer?
    @State private var fingerNotDetectedCount = 0
    @State private var cameraPermissionDenied = false
    @State private var flashStatus = "Flash: OFF"
    
    // 20-second finger timeout
    @State private var noFingerTimeout: Timer?
    @State private var noFingerElapsedTime: Int = 0
    @State private var maxWaitTime: Int = 20
    @State private var isWaitingForFinger = true
    @State private var hasFingerBeenDetected = false
    @State private var showExtendedWaitMessage = false
    @State private var measurementStarted = false
    @State private var cameraReady = false
    @State private var animateGradient = false
    
    @Environment(\.dismiss) private var dismiss
    
    private var qualityColor: Color {
        if fingerPlacementQuality > 0.6 { return .green }
        else if fingerPlacementQuality > 0.2 { return .orange }
        else { return .red }
    }
    
    private var qualityText: String {
        if fingerPlacementQuality > 0.6 { return "🎯 Perfect Placement!" }
        else if fingerPlacementQuality > 0.2 { return "👍 Good Placement" }
        else if fingerDetected { return "👆 Adjust Position" }
        else { return "🔦 Place Finger on Camera & Flash" }
    }
    
    var body: some View {
        ZStack {
            enhancedBackground
            
            if cameraPermissionDenied {
                enhancedCameraPermissionView
            } else {
                enhancedContent
            }
            
            if let ppgView = ppgView {
                ppgView
                    .frame(width: 200, height: 200)
                    .offset(x: -1000, y: -1000)
                    .opacity(0.01)
            }
        }
        .onAppear {
            print("🎬 FixedMeasurementView appeared")
            checkCameraPermissionAndStart()
            animateGradient = true
        }
        .onDisappear {
            print("🎬 FixedMeasurementView disappeared")
            cleanupMeasurement()
        }
        .onChange(of: fingerDetected) { _, _ in
            evaluateFingerPlacement()
        }
        .onChange(of: fingerPlacementQuality) { _, _ in
            evaluateFingerPlacement()
        }
    }
    
    // Enhanced: Beautiful animated background
    private var enhancedBackground: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.15, green: 0.1, blue: 0.25)
                ]),
                startPoint: animateGradient ? .topLeading : .bottomTrailing,
                endPoint: animateGradient ? .bottomTrailing : .topLeading
            )
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGradient)
            
            // Animated particles
            ForEach(0..<20, id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: CGFloat.random(in: 2...4), height: CGFloat.random(in: 2...4))
                    .position(
                        x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                        y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                    )
                    .animation(.linear(duration: Double.random(in: 3...8)).repeatForever(autoreverses: false), value: animateGradient)
            }
        }
        .ignoresSafeArea()
    }
    
    // Enhanced: Better camera permission view
    private var enhancedCameraPermissionView: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "camera.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 16) {
                Text("📸 Camera Access Required")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                
                Text("FIXED HeartScope needs camera access to measure your heart rate using the camera flash. This data stays on your device.")
                    .font(.body.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            VStack(spacing: 16) {
                Button("⚙️ Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .padding(.horizontal, 40)
                
                Button("❌ Cancel") {
                    onComplete(.timeout)
                    dismiss()
                }
                .font(.headline.weight(.medium))
                .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    // Enhanced: Better main content with improved UI
    private var enhancedContent: some View {
        VStack(spacing: 40) {
            enhancedHeader
            Spacer()
            enhancedCameraPreview
            enhancedFingerPlacementGuide
            enhancedProgressSection
            Spacer()
        }
    }
    
    // Enhanced: Modern header design
    private var enhancedHeader: some View {
        HStack {
            Button {
                print("❌ User manually cancelled FIXED measurement")
                onComplete(.timeout)
                cleanupMeasurement()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.15))
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            Spacer()
            
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                        .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                    
                    Text("FIXED HeartScope Pro")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(flashStatus.contains("ON") ? .yellow : .gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(flashStatus.contains("ON") ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                                 value: flashStatus.contains("ON"))
                    
                    Text(flashStatus)
                        .font(.caption.weight(.medium))
                        .foregroundColor(flashStatus.contains("ON") ? .yellow : .gray)
                }
            }
            
            Spacer()
            
            Circle()
                .fill(Color.clear)
                .frame(width: 50, height: 50)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // Enhanced: Beautiful camera preview with better animations
    private var enhancedCameraPreview: some View {
        ZStack {
            // Outer glow ring
            RoundedRectangle(cornerRadius: 32)
                .stroke(
                    LinearGradient(
                        colors: [qualityColor.opacity(0.6), qualityColor.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 240, height: 240)
                .scaleEffect(fingerDetected ? 1.05 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: fingerDetected)
            
            // Main camera preview container
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [.black, Color(red: 0.1, green: 0.1, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 220, height: 220)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(qualityColor, lineWidth: fingerDetected ? 4 : 2)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: fingerDetected)
                )
                .shadow(color: qualityColor.opacity(0.5), radius: fingerDetected ? 20 : 10)
                .animation(.easeInOut(duration: 0.3), value: fingerDetected)
            
            // Content inside camera preview
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(qualityColor.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .scaleEffect(fingerDetected ? 1.1 : 0.9)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: fingerDetected)
                    
                    Image(systemName: fingerDetected ? "checkmark.circle.fill" : "camera.macro")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(qualityColor)
                        .symbolEffect(.bounce.up.byLayer, options: .repeating, value: fingerDetected)
                }
                
                VStack(spacing: 8) {
                    Text(qualityText)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    if fingerDetected {
                        // FIXED quality indicator - more lenient
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                Text("Signal Quality:")
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text("\(Int(fingerPlacementQuality * 100))%")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(qualityColor)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(.white.opacity(0.2))
                                        .frame(height: 6)
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [qualityColor.opacity(0.8), qualityColor],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(fingerPlacementQuality), height: 6)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: fingerPlacementQuality)
                                }
                            }
                            .frame(height: 6)
                        }
                        .frame(width: 160)
                    }
                }
            }
        }
    }
    
    // Enhanced: Better finger placement guide
    private var enhancedFingerPlacementGuide: some View {
        VStack(spacing: 20) {
            Text(fingerDetected && fingerPlacementQuality >= 0.20 ?
                "🎯 Good placement! Hold steady while we measure..." :
                "📱 Place your fingertip over BOTH camera and flash")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.3), value: fingerDetected)
            
            VStack(spacing: 12) {
                InstructionRow(icon: "📷", text: "Cover camera lens completely")
                InstructionRow(icon: "🔦", text: "Flash should feel warm on fingertip")
                InstructionRow(icon: "🤏", text: "Press gently but firmly")
                InstructionRow(icon: "⏱️", text: "Hold very still during measurement")
            }
            .padding(.horizontal, 30)
        }
        .padding(.horizontal, 20)
    }
    
    // Helper view for instructions
    struct InstructionRow: View {
        let icon: String
        let text: String
        
        var body: some View {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.title3)
                
                Text(text)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
            }
        }
    }
    
    // FIXED: Enhanced progress section with proper timer animation
    private var enhancedProgressSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("Measurement Time")
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(countdown)s / 15s")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                    
                    Text("of 15 seconds")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            // FIXED: Proper progress bar with smooth animation
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 12)
                    
                    // Progress
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.green, .cyan, .blue, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(timerProgress), height: 12)
                        .animation(.linear(duration: 0.1), value: timerProgress)
                    
                    // Animated pulse effect
                    if timerProgress > 0 && timerProgress < 1.0 {
                        Capsule()
                            .fill(.white.opacity(0.3))
                            .frame(width: 20, height: 12)
                            .offset(x: geometry.size.width * CGFloat(timerProgress) - 10)
                            .animation(.linear(duration: 0.1), value: timerProgress)
                    }
                }
            }
            .frame(height: 12)
            
            // Percentage and status
            HStack(spacing: 8) {
                Text("\(Int(timerProgress * 100))%")
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.cyan)
                    .contentTransition(.numericText())
                
                Spacer()
                
                if timerProgress < 0.3 {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text("Initializing...")
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundColor(.blue)
                } else if timerProgress < 0.7 {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption2)
                        Text("Measuring...")
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundColor(.green)
                } else if timerProgress < 1.0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("Almost done...")
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundColor(.orange)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                        Text("Complete!")
                            .font(.system(.caption2, design: .rounded))
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func checkCameraPermissionAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            print("✅ FIXED camera authorized, starting measurement")
            startMeasurement()
        case .notDetermined:
            print("❓ Requesting FIXED camera permission")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        print("✅ FIXED camera permission granted")
                        startMeasurement()
                    } else {
                        print("❌ FIXED camera permission denied")
                        cameraPermissionDenied = true
                    }
                }
            }
        default:
            print("❌ FIXED camera permission not available")
            cameraPermissionDenied = true
        }
    }
    
    // 20-second measurement start logic
    private func startMeasurement() {
        print("🚀 Starting measurement with 20-second finger timeout")
        measurementStarted = true
        flashStatus = "Flash: STARTING..."
        isWaitingForFinger = true
        noFingerElapsedTime = 0
        hasFingerBeenDetected = false
        showExtendedWaitMessage = false
        scanningAnimation = true
        
        ppgView = PPGCameraView(
            onBPMDetected: { bpm in
                DispatchQueue.main.async {
                    print("✅ BPM detected: \(bpm)")
                    onComplete(.success(bpm))
                    cleanupMeasurement()
                    dismiss()
                }
            },
            onFingerDetected: { detected in
                DispatchQueue.main.async {
                    fingerDetected = detected
                    if detected {
                        hasFingerBeenDetected = true
                        resetNoFingerTimeout()
                    }
                    flashStatus = detected ? "Flash: ON ✅" : "Flash: ON (waiting)"
                }
            },
            onFingerPlacementQuality: { quality in
                DispatchQueue.main.async {
                    fingerPlacementQuality = quality
                }
            },
            onControllerReady: { controller in
                DispatchQueue.main.async {
                    self.ppgController = controller
                }
            }
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            print("📸 Camera should be ready, starting timeout")
            flashStatus = "Flash: ON ✅"
            cameraReady = true
            startNoFingerTimeout()
        }
    }
    
    // 20-second timeout logic
    private func startNoFingerTimeout() {
        guard measurementStarted && cameraReady else {
            print("⚠️ Not starting timeout - measurement not ready")
            return
        }
        
        print("⏰ Starting 20-second finger detection timeout")
        noFingerTimeout?.invalidate()
        
        noFingerTimeout = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard measurementStarted else {
                stopNoFingerTimeout()
                return
            }
            
            // If finger is currently detected, keep resetting timeout
            if fingerDetected {
                noFingerElapsedTime = 0
                return
            }
            
            noFingerElapsedTime += 1
            print("⏱️ No finger timeout: \(noFingerElapsedTime)/\(maxWaitTime) - fingerDetected: \(hasFingerBeenDetected)")
            
            if noFingerElapsedTime == 8 && !hasFingerBeenDetected {
                showExtendedWaitMessage = true
            }
            
            if noFingerElapsedTime >= maxWaitTime {
                if !hasFingerBeenDetected {
                    print("❌ No finger detected within 20 seconds - exiting")
                    DispatchQueue.main.async {
                        onComplete(.noFingerDetected)
                        cleanupMeasurement()
                        dismiss()
                    }
                }
                stopNoFingerTimeout()
            }
        }
    }
    
    private func stopNoFingerTimeout() {
        print("🛑 Stopping no finger timeout")
        noFingerTimeout?.invalidate()
        noFingerTimeout = nil
    }
    
    private func resetNoFingerTimeout() {
        noFingerElapsedTime = 0
        showExtendedWaitMessage = false
    }
    
    // Robust finger placement evaluation combining presence and quality
    private func evaluateFingerPlacement() {
        print("🔄 Finger state: detected=\(fingerDetected), quality=\(fingerPlacementQuality)")
        
        if fingerDetected && fingerPlacementQuality >= 0.20 {
            consecutiveLostFrames = 0
            hasFingerBeenDetected = true
            isWaitingForFinger = false
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                fingerOverCamera = true
            }
            
            if measurementTimer == nil {
                startCountdown()
            }
            stopNoFingerTimeout()
        } else {
            consecutiveLostFrames += 1
            // Debounce: don't immediately reset countdown on a single momentary dropped frame
            if consecutiveLostFrames > 20 { // ~0.66 seconds of missing finger
                pauseCountdown()
                isWaitingForFinger = true
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    fingerOverCamera = false
                }
            }
        }
    }
    
    // Proper countdown timer with smooth animation and final calculation trigger
    private func startCountdown() {
        print("🎬 Starting/Resuming 15-second countdown... remaining: \(countdown)s")
        measurementTimer?.invalidate()
        
        let progressIncrement = 1.0 / 15.0
        
        measurementTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
                totalMeasurementTime += 1.0
                
                withAnimation(.linear(duration: 1.0)) {
                    timerProgress = min(timerProgress + progressIncrement, 1.0)
                }
                
                progress = 1.0 - CGFloat(countdown) / 15.0
                print("⏱️ Countdown: \(countdown)s - progress: \(Int(timerProgress * 100))%")
            }
            
            if countdown <= 0 {
                print("🏁 Countdown finished! Requesting final BPM from camera...")
                timer.invalidate()
                measurementTimer = nil
                
                // Finish measurement and calculate final BPM from accumulated buffer
                if let controller = ppgController {
                    let bpm = controller.finishMeasurementAndDeliver()
                    if bpm >= 45 && bpm <= 195 {
                        DispatchQueue.main.async {
                            onComplete(.success(bpm))
                            cleanupMeasurement()
                            dismiss()
                        }
                        return
                    }
                }
                
                // Fallback check after brief buffer flush
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let controller = ppgController {
                        let bpm = controller.finishMeasurementAndDeliver()
                        if bpm >= 45 && bpm <= 195 {
                            onComplete(.success(bpm))
                        } else {
                            onComplete(.noFingerDetected)
                        }
                    } else {
                        onComplete(.timeout)
                    }
                    cleanupMeasurement()
                    dismiss()
                }
            }
        }
    }
    
    private func pauseCountdown() {
        print("⏸️ Pausing countdown at \(countdown)s")
        measurementTimer?.invalidate()
        measurementTimer = nil
    }
    
    private func stopCountdown() {
        print("🛑 Stopping countdown and resetting...")
        measurementTimer?.invalidate()
        measurementTimer = nil
        timerProgress = 0
        progress = 0
        countdown = 15
        totalMeasurementTime = 0
    }
    
    private func cleanupMeasurement() {
        print("Cleaning up measurement resources")
        // Stop all timers
        timer?.invalidate()
        timer = nil
        measurementTimer?.invalidate()
        measurementTimer = nil
        fingerDetectionTimer?.invalidate()
        fingerDetectionTimer = nil
        stopNoFingerTimeout()
        
        // Reset states
        isMeasuring = false
        flashStatus = "Flash: OFF"
        isWaitingForFinger = false
        measurementStarted = false
        cameraReady = false
        scanningAnimation = false
        timerProgress = 0
        totalMeasurementTime = 0
        
        // Clean up PPG view & controller
        ppgController = nil
        ppgView = nil
    }
}

// MARK: - Heart Rate Entry Model

struct HeartRateEntry: Identifiable, Equatable {
    var id = UUID()
    var timestamp: Date
    var bpm: Int
    
    static func == (lhs: HeartRateEntry, rhs: HeartRateEntry) -> Bool {
        return lhs.id == rhs.id && lhs.timestamp == rhs.timestamp && lhs.bpm == rhs.bpm
    }
}

// MARK: - Preview

#Preview {
    HRCheckView()
        .environmentObject(UserManager.shared)
}
