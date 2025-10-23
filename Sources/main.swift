import Foundation
import AVFoundation
import CoreGraphics
import AppKit

// MARK: - Configuration

struct Config {
    static var idleThresholdSeconds: TimeInterval = 10.0
    static let captureDirectory = "images"
    static let tempDirectory = "/tmp/whosthere"
}

// MARK: - State Management

enum ActivityState {
    case active
    case idle
}

class ActivityMonitor {
    private var lastActivityTime: Date = Date()
    private var state: ActivityState = .active
    private let camera = CameraCapture()
    private var checkTimer: Timer?
    
    init() {
        setupEventTap()
        setupIdleCheckTimer()
        createDirectories()
        
        print("WhosThere started - monitoring for idle periods of \(Int(Config.idleThresholdSeconds))s")
        print("Images will be saved to: ./\(Config.captureDirectory)/ and \(Config.tempDirectory)/")
    }
    
    private func createDirectories() {
        let fileManager = FileManager.default
        
        // Create local images directory
        try? fileManager.createDirectory(atPath: Config.captureDirectory, 
                                         withIntermediateDirectories: true)
        
        // Create temp directory
        try? fileManager.createDirectory(atPath: Config.tempDirectory, 
                                         withIntermediateDirectories: true)
    }
    
    private func setupEventTap() {
        // Event mask for keyboard and mouse/trackpad activity
        let keyboardMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let mouseMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        let eventMask = keyboardMask | mouseMask
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let monitor = Unmanaged<ActivityMonitor>.fromOpaque(refcon!).takeUnretainedValue()
                monitor.handleActivity()
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("ERROR: Failed to create event tap. Make sure the app has Accessibility permissions.")
            print("Go to: System Settings > Privacy & Security > Accessibility")
            exit(1)
        }
        
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    private func setupIdleCheckTimer() {
        // Check every 5 seconds if we've crossed the idle threshold
        checkTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }
    
    private func handleActivity() {
        let now = Date()
        let wasIdle = state == .idle

        if wasIdle {
            // Transition from idle to active - CAPTURE!
            let idleDuration = now.timeIntervalSince(lastActivityTime)
            print("Activity detected after \(Int(idleDuration))s idle - capturing image...")
            // Wait briefly for camera to be ready, then capture
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.captureImage(idleDuration: idleDuration)
            }
        }

        state = .active
        lastActivityTime = now
    }

    private func checkIdleState() {
        let now = Date()
        let timeSinceActivity = now.timeIntervalSince(lastActivityTime)

        if state == .active && timeSinceActivity >= Config.idleThresholdSeconds {
            state = .idle
            print("System idle for \(Int(timeSinceActivity))s - starting camera...")
            camera.startSession()
        }
    }
    
    private func captureImage(idleDuration: TimeInterval) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let filename = "capture_\(dateString)_idle\(Int(idleDuration))s.jpg"
        let localPath = "\(Config.captureDirectory)/\(filename)"
        let tempPath = "\(Config.tempDirectory)/\(filename)"

        camera.capturePhoto(saveTo: [localPath, tempPath]) { [weak self] success in
            if success {
                print("Image saved: \(filename)")
            } else {
                print("Failed to capture image")
            }
            // Stop camera after capture attempt
            self?.camera.stopSession()
        }
    }
}

// MARK: - Camera Capture

class CameraCapture: NSObject {
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var completionHandler: ((Bool) -> Void)?
    private var savePaths: [String] = []
    private var isSessionConfigured = false

    private func setupCamera() {
        guard !isSessionConfigured else { return }

        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }

        captureSession.sessionPreset = .photo

        // Find front camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else {
            print("ERROR: No front camera found")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }

            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }

            isSessionConfigured = true
        } catch {
            print("ERROR: Failed to setup camera: \(error)")
        }
    }

    func startSession() {
        setupCamera()
        guard let captureSession = captureSession, !captureSession.isRunning else { return }
        DispatchQueue.global(qos: .background).async {
            captureSession.startRunning()
            if !captureSession.isRunning {
                DispatchQueue.main.async {
                    print("WARNING: Camera session failed to start (may be in use by another app)")
                }
            }
        }
    }

    func stopSession() {
        guard let captureSession = captureSession, captureSession.isRunning else { return }
        DispatchQueue.global(qos: .background).async {
            captureSession.stopRunning()
        }
    }

    func capturePhoto(saveTo paths: [String], completion: @escaping (Bool) -> Void) {
        guard let captureSession = captureSession, captureSession.isRunning else {
            print("WARNING: Cannot capture - camera session not running")
            completion(false)
            return
        }
        guard let photoOutput = photoOutput else {
            completion(false)
            return
        }

        self.savePaths = paths
        self.completionHandler = completion

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off

        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraCapture: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                    didFinishProcessingPhoto photo: AVCapturePhoto,
                    error: Error?) {
        if let error = error {
            print("ERROR: Photo capture failed: \(error)")
            completionHandler?(false)
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            print("ERROR: Failed to get image data from photo")
            completionHandler?(false)
            return
        }

        var allSucceeded = true
        for path in savePaths {
            do {
                try imageData.write(to: URL(fileURLWithPath: path))
            } catch {
                print("ERROR: Failed to save to \(path): \(error)")
                allSucceeded = false
            }
        }

        completionHandler?(allSucceeded)
    }
}

// MARK: - Main Entry Point

func parseArguments() {
    let args = CommandLine.arguments
    for i in 0..<args.count {
        if args[i] == "--idle-threshold" && i + 1 < args.count {
            if let threshold = Double(args[i + 1]) {
                Config.idleThresholdSeconds = threshold
            }
        }
    }
}

parseArguments()

let monitor = ActivityMonitor()
RunLoop.main.run()

