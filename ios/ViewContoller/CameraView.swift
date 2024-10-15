import AVFoundation
import MediaPipeTasksVision
import UIKit

class CameraView: UIView {
    private struct Constants {
        static let edgeOffset: CGFloat = 2.0
    }
    
    var propDictionary: [String: Bool]? {
        didSet {
        }
    }
    
    var previewView: UIView!
    var cameraUnavailableLabel: UILabel!
    var resumeButton: UIButton!
    var overlayView: OverlayView!
    
    var heightInfo: CGFloat = 0
    var widthInfo: CGFloat = 0
    var frameCount:Int = 0
    var landmarkData: LandmarkData!
    var isPortrait: Bool = true
    var poseStart: Bool = true
    
    private var isSessionRunning = false
    private var isObserving = false
    private let backgroundQueue = DispatchQueue(label: "com.google.mediapipe.cameraController.backgroundQueue")
    
    // MARK: Controllers that manage functionality
    // Handles all the camera related functionality
    private lazy var cameraFeedService = CameraFeedService(previewView: previewView)
    
    private let poseLandmarkerServiceQueue = DispatchQueue(
        label: "com.google.mediapipe.cameraController.poseLandmarkerServiceQueue",
        attributes: .concurrent)
    
    // Queuing reads and writes to poseLandmarkerService using the Apple recommended way
    // as they can be read and written from multiple threads and can result in race conditions.
    private var _poseLandmarkerService: PoseLandmarkerService?
    private var poseLandmarkerService: PoseLandmarkerService? {
        get {
            poseLandmarkerServiceQueue.sync {
                return self._poseLandmarkerService
            }
        }
        set {
            poseLandmarkerServiceQueue.async(flags: .barrier) {
                self._poseLandmarkerService = newValue
            }
        }
    }
    
    
    @objc var height: NSNumber = 0 {
        didSet {
            self.frame.size.height = CGFloat(truncating: height)
            self.heightInfo = CGFloat(truncating: height)
        }
    }
    
    
    // Property for width
    @objc var width: NSNumber = 0 {
        didSet {
            self.frame.size.width = CGFloat(truncating: width)
            self.widthInfo = CGFloat(truncating: width)
        }
    }
    
    @objc var face: Bool = true  {
        didSet {
            updateBodyTrack()
        }
    }
    @objc var leftArm: Bool = true {
        didSet {
            updateBodyTrack()
        }
    }
    
    @objc var rightArm: Bool = true {
        didSet {
            updateBodyTrack()
        }
    }
    @objc var leftWrist: Bool = true {
        didSet {
            updateBodyTrack()
        }
    }
    @objc var rightWrist: Bool = true {
        didSet {
            updateBodyTrack()
        }
    }
    @objc var torso: Bool = true {
        didSet {
            updateBodyTrack()
        }
    }
    @objc var leftLeg: Bool = true {
        didSet {
            updateBodyTrack()
        }
    }
    @objc var rightLeg: Bool = true {
        didSet {
            updateBodyTrack()
        }
    }
    @objc var leftAnkle: Bool = true {
        didSet {
            updateBodyTrack()
        }
    }
    @objc var rightAnkle: Bool = true {
        didSet {
            updateBodyTrack()
        }
    }
    
    
    @objc var orientation: NSNumber = 0 {
        didSet {
//            let result =  CGFloat(truncating: orientation)
//            self.isPortrait = result == 1 ? true : false
        }
    }
    
    
    @objc var poseStarted: NSNumber = 0 {
        didSet {
            let result =  CGFloat(truncating: poseStarted)
            self.poseStart = result == 1 ? true : false
        }
    }
    
    @objc var onLandmark: RCTDirectEventBlock?
    
    // MARK: - Initializers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        //  setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        //  setupUI()
    }
    
    private func updateBodyTrack() {
        // Update propDictionary whenever any property changes
        propDictionary = [
            "face": face,
            "leftArm": leftArm,
            "leftLeg": leftLeg,
            "rightArm": rightArm,
            "leftWrist": leftWrist,
            "rightWrist": rightWrist,
            "torso": torso,
            "rightLeg": rightLeg,
            "leftAnkle": leftAnkle,
            "rightAnkle": rightAnkle,
        ]
    }
    
    // MARK: Constraints
    private func setupConstraints() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        cameraUnavailableLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            previewView.widthAnchor.constraint(equalToConstant: CGFloat(truncating: self.width)),
            previewView.heightAnchor.constraint(equalToConstant: CGFloat(truncating: self.height)),
            previewView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            
            cameraUnavailableLabel.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            cameraUnavailableLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            
            overlayView.topAnchor.constraint(equalTo: previewView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: previewView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: previewView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: previewView.bottomAnchor)
        ])
    }
    
    private func setupUI() {
        requestCameraPermission()
        // Instantiate and add subviews
        previewView = UIView()
        cameraUnavailableLabel = UILabel()
        resumeButton = UIButton()
        overlayView = OverlayView()
        overlayView.backgroundColor = UIColor.white.withAlphaComponent(0.0)
        addSubview(previewView)
        addSubview(cameraUnavailableLabel)
        //    addSubview(resumeButton)
        addSubview(overlayView)
        
        previewView.frame =  CGRect(x:0, y: 0, width:widthInfo, height:heightInfo)
        //  cameraUnavailableLabel.frame =  CGRect(x:0, y: 0, width:375, height:812)
        //resumeButton.frame =  CGRect(x:0, y: 0, width:50, height:50)
        overlayView.frame = CGRect(x:0, y: 0, width:widthInfo, height:heightInfo)
        
        setupConstraints()
        
        initializePoseLandmarkerServiceOnSessionResumption()
        
        
        cameraFeedService.poseStarted(started: self.poseStart)
        
        cameraFeedService.setOrientation(isPortrait: self.isPortrait)
        cameraFeedService.startLiveCameraSession {[weak self] cameraConfiguration in
            DispatchQueue.main.async {
                switch cameraConfiguration {
                case .failed:
                    self?.presentVideoConfigurationErrorAlert()
                case .permissionDenied:
                    self?.presentCameraPermissionsDeniedAlert()
                default:
                    break
                }
            }
        }
        cameraFeedService.delegate = self
        
        cameraFeedService.updateVideoPreviewLayer(toFrame: previewView.bounds)
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    @objc
    override func didSetProps(_ changedProps: [String]!) {
        
        if changedProps.contains("height") && changedProps.contains("width")  {
            setupUI()
        }
    }
    
    @objc func switchCamera() {
        cameraFeedService.switchCamera()
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        if newSuperview == nil { UIApplication.shared.isIdleTimerDisabled = false} }
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                // User granted camera permission
                print("Camera permission granted.")
            } else {
                // User denied camera permission
                print("Camera permission denied.")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func presentCameraPermissionsDeniedAlert() {
        let alertController = UIAlertController(
            title: "Camera Permissions Denied",
            message: "Camera permissions have been denied for this app. You can change this by going to Settings",
            preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in
            UIApplication.shared.open(
                URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
        }
        alertController.addAction(cancelAction)
        alertController.addAction(settingsAction)
        
        UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true, completion: nil)
    }
    
    private func presentVideoConfigurationErrorAlert() {
        let alert = UIAlertController(
            title: "Camera Configuration Failed",
            message: "There was an error while configuring camera.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
    }
    
    private func initializePoseLandmarkerServiceOnSessionResumption() {
        clearAndInitializePoseLandmarkerService()
        startObserveConfigChanges()
    }
    
    @objc private func clearAndInitializePoseLandmarkerService() {
        poseLandmarkerService = nil
        poseLandmarkerService = PoseLandmarkerService
            .liveStreamPoseLandmarkerService(
                modelPath: InferenceConfigurationManager.sharedInstance.model.modelPath,
                numPoses: InferenceConfigurationManager.sharedInstance.numPoses,
                minPoseDetectionConfidence: InferenceConfigurationManager.sharedInstance.minPoseDetectionConfidence,
                minPosePresenceConfidence: InferenceConfigurationManager.sharedInstance.minPosePresenceConfidence,
                minTrackingConfidence: InferenceConfigurationManager.sharedInstance.minTrackingConfidence,
                liveStreamDelegate: self,
                delegate: InferenceConfigurationManager.sharedInstance.delegate)
    }
    
    private func clearPoseLandmarkerServiceOnSessionInterruption() {
        stopObserveConfigChanges()
        poseLandmarkerService = nil
    }
    
    private func startObserveConfigChanges() {
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(clearAndInitializePoseLandmarkerService),
                         name: InferenceConfigurationManager.notificationName
                         
                         ,
                         object: nil)
        isObserving = true
    }
    
    private func stopObserveConfigChanges() {
        if isObserving {
            NotificationCenter.default
                .removeObserver(self,
                                name:InferenceConfigurationManager.notificationName,
                                object: nil)
        }
        isObserving = false
    }
}

extension CameraView: CameraFeedServiceDelegate {
    
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, landmarkData:LandmarkData) {
        let currentTimeMs = Date().timeIntervalSince1970 * 1000
        // Pass the pixel buffer to mediapipe
        backgroundQueue.async { [weak self] in
            self?.poseLandmarkerService?.detectAsync(
                sampleBuffer: sampleBuffer,
                orientation: orientation,
                timeStamps: Int(currentTimeMs))
        }
        self.landmarkData = landmarkData
        //   self.sampleBuffer = sampleBuffer
    }
    
    // MARK: Session Handling Alerts
    
    func sessionWasInterrupted(canResumeManually resumeManually: Bool) {
        // Updates the UI when session is interupted.
        if resumeManually {
            resumeButton.isHidden = false
        } else {
            cameraUnavailableLabel.isHidden = false
        }
        clearPoseLandmarkerServiceOnSessionInterruption()
    }
    
    func sessionInterruptionEnded() {
        // Updates UI once session interruption has ended.
        cameraUnavailableLabel.isHidden = true
        resumeButton.isHidden = true
        initializePoseLandmarkerServiceOnSessionResumption()
    }
    
    func didEncounterSessionRuntimeError() {
        // Handles session run time error by updating the UI and providing a button if session can be
        // manually resumed.
        resumeButton.isHidden = false
        clearPoseLandmarkerServiceOnSessionInterruption()
    }
}

//func uiImageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
//    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
//    let context = CIContext()
//    if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
//        return UIImage(cgImage: cgImage)
//    }
//    return nil
//}


//func dataFromUIImage(_ image: UIImage) -> Data? {
//  return image.jpegData(compressionQuality: 0.5)
//}
//
//
//func base64StringFromData(_ data: Data) -> String {
//    return data.base64EncodedString()
//}

// MARK: PoseLandmarkerServiceLiveStreamDelegate

extension CameraView: PoseLandmarkerServiceLiveStreamDelegate {
    
    
    func poseLandmarkerService(
        _ poseLandmarkerService: PoseLandmarkerService,
        didFinishDetection result: ResultBundle?,
        error: Error?) {
            
            DispatchQueue.main.async { [weak self] in
                guard let weakSelf = self else { return }
                //   weakSelf.inferenceResultDeliveryDelegate?.didPerformInference(result: result)
                guard let poseLandmarkerResult = result?.poseLandmarkerResults.first as? PoseLandmarkerResult else { return }
                let limit = ((self?.landmarkData.frameRate)!)/6
                
                self!.frameCount =  self!.frameCount+1;
                if(self!.frameCount > Int(limit)){
                    self!.frameCount = 0
                    var results = poseLandmarkerResult.landmarks.first
                    var worldLandmarks = poseLandmarkerResult.worldLandmarks.first
                    
                    var swiftDict: [String: Any] = [:]
                    
                    if let landmarks = results {
                        var landmarksArray: [[String: Any]] = []
                        var worldLandmarksArray: [[String: Any]] = []
                        
                        for landmark in landmarks {
                            // Assuming landmark has `x` and `y` properties
                            let landmarkData: [String: Any] = [
                                "x": landmark.x,
                                "y": landmark.y,
                                "z": landmark.z,
                                "visibility": landmark.visibility?.floatValue as Any,
                                "presence": landmark.presence?.floatValue as Any,
                                
                            ]
                            landmarksArray.append(landmarkData)
                        }
                        
                        
                        if(worldLandmarks != nil){
                            for landmark in worldLandmarks! {
                                // Assuming landmark has `x` and `y` properties
                                let landmarkData: [String: Any] = [
                                    "x": landmark.x,
                                    "y": landmark.y,
                                    "z": landmark.z,
                                    "visibility": landmark.visibility?.floatValue as Any,
                                    "presence": landmark.presence?.floatValue as Any,
                                    
                                ]
                                worldLandmarksArray.append(landmarkData)
                            }
                        }
                        
                        
                        //              var pixelBufferFromSampleBuffe = CMSampleBufferGetImageBuffer(self!.sampleBuffer)
                        //              var uiImage = uiImageFromPixelBuffer(pixelBufferFromSampleBuffe!)
                        //              var  dataFromUIImage =  dataFromUIImage(uiImage!)
                        //   var base64StringFromData = base64StringFromData(dataFromUIImage!)
                        
                        // Add the landmarks array to the swiftDict
                        
                        
                        swiftDict["landmarks"] = landmarksArray
                        swiftDict["additionalData"] = [
                            "height": self?.landmarkData.height ?? CGFloat(self!.isPortrait ? DefaultConstants.HEIGHT : DefaultConstants.WIDTH) ,
                            "width": self?.landmarkData.width ?? CGFloat(self!.isPortrait ? DefaultConstants.WIDTH : DefaultConstants.HEIGHT),
                            "presentationTimeStamp": self?.landmarkData.presentationTimeStamp ?? 0,
                            "frameNumber": self?.landmarkData.frameNumber ?? 0,
                            "startTimestamp" : self?.landmarkData.startTimestamp
                        ]
                        
                        swiftDict["worldLandmarks"] = worldLandmarksArray
                        
                        if self!.onLandmark != nil {
                            self!.onLandmark!(swiftDict)
                        }
                    } else {
                        // Handle the case where `results` is nil
                        //                print("No landmarks found")
                    }
                }
                
                if self!.previewView != nil{
                    let orientaiton =  self!.isPortrait ? UIDevice.current.orientation : UIDeviceOrientation(rawValue: 3)
                    let imageSize = weakSelf.cameraFeedService.videoResolution
                    let poseOverlays = OverlayView().poseOverlays(
                        fromMultiplePoseLandmarks: poseLandmarkerResult.landmarks,
                        inferredOnImageOfSize: imageSize,
                        ovelayViewSize: weakSelf.overlayView.bounds.size,
                        imageContentMode: weakSelf.overlayView.imageContentMode,
                        andOrientation: UIImage.Orientation.from(
                            deviceOrientation:  UIDevice.current.orientation ), isPortrait: self!.isPortrait, propDictionary: self!.propDictionary!)
                    weakSelf.overlayView.clear()
                    weakSelf.overlayView.draw(poseOverlays: poseOverlays,
                                              inBoundsOfContentImageOfSize: imageSize,
                                              imageContentMode: weakSelf.cameraFeedService.videoGravity.contentMode,
                                              isPortrait: self!.isPortrait)
                }
            }
        }
}

// MARK: - AVLayerVideoGravity Extension

extension AVLayerVideoGravity {
    var contentMode: UIView.ContentMode {
        switch self {
        case .resizeAspectFill:
            return .scaleAspectFill
        case .resizeAspect:
            return .scaleAspectFit
        case .resize:
            return .scaleToFill
        default:
            return .scaleAspectFill
        }
    }
    
    
}

