import Foundation

/**
 * Singleton storing the configs needed to initialize an MediaPipe Tasks object and run inference.
 * Controllers can observe the `InferenceConfigurationManager.notificationName` for any changes made by the user.
 */

class InferenceConfigurationManager: NSObject {
    
    var model: Model = DefaultConstants.model {
        didSet { postConfigChangedNotification() }
    }
    
    var delegate: PoseLandmarkerDelegate = DefaultConstants.delegate {
        didSet { postConfigChangedNotification() }
    }
    
    var numPoses: Int = DefaultConstants.numPoses {
        didSet { postConfigChangedNotification() }
    }
    
    var minPoseDetectionConfidence: Float = DefaultConstants.minPoseDetectionConfidence {
        didSet { postConfigChangedNotification() }
    }
    
    var minPosePresenceConfidence: Float = DefaultConstants.minPosePresenceConfidence {
        didSet { postConfigChangedNotification() }
    }
    
    var minTrackingConfidence: Float = DefaultConstants.minTrackingConfidence {
        didSet { postConfigChangedNotification() }
    }
    
    static let sharedInstance = InferenceConfigurationManager()
    
    static let notificationName = Notification.Name.init(rawValue: "com.google.mediapipe.inferenceConfigChanged")
    
    private func postConfigChangedNotification() {
        NotificationCenter.default
            .post(name: InferenceConfigurationManager.notificationName, object: nil)
    }
    
}
