import UIKit
import AVFoundation

// MARK: CameraFeedServiceDelegate Declaration
protocol CameraFeedServiceDelegate: AnyObject {
    
    /**
     This method delivers the pixel buffer of the current frame seen by the device's camera.
     */
    func didOutput(sampleBuffer: CMSampleBuffer, orientation: UIImage.Orientation, landmarkData:LandmarkData)
    
    /**
     This method initimates that a session runtime error occured.
     */
    func didEncounterSessionRuntimeError()
    
    /**
     This method initimates that the session was interrupted.
     */
    func sessionWasInterrupted(canResumeManually resumeManually: Bool)
    
    /**
     This method initimates that the session interruption has ended.
     */
    func sessionInterruptionEnded()
    
}

struct WatermarkImage {
    let image: CIImage
    let position: CGPoint
}


struct LandmarkData {
    var height: CGFloat
    var width: CGFloat
    var frameNumber: Double
    var presentationTimeStamp: Double
    var frameRate: Double
    var startTimestamp: Int
}


extension UIImage {
    convenience init?(ciImage: CIImage) {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }
}

/**
 This class manages all camera related functionality
 */
class CameraFeedService: NSObject {
    /**
     This enum holds the state of the camera initialization.
     */
    enum CameraConfigurationStatus {
        case success
        case failed
        case permissionDenied
    }
    
    
    
    // MARK: Public Instance Variables
    var videoResolution: CGSize {
        get {
            guard let size = imageBufferSize else {
                return CGSize.zero
            }
            let minDimension = min(size.width, size.height)
            let maxDimension = max(size.width, size.height)
            
            
            if self.isPortrait{
                switch UIDevice.current.orientation {
                case .portrait:
                    return CGSize(width: minDimension, height: maxDimension)
                case .landscapeLeft:
                    fallthrough
                case .landscapeRight:
                    return CGSize(width: maxDimension, height: minDimension)
                default:
                    return CGSize(width: minDimension, height: maxDimension)
                }
            }else {
                return  CGSize(width: maxDimension, height: minDimension)
            }
            
            
            
        }
    }
    
    let videoGravity = AVLayerVideoGravity.resizeAspectFill
    
    // MARK: Instance Variables
    private let session: AVCaptureSession = AVCaptureSession()
    private lazy var videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
    private let sessionQueue = DispatchQueue(label: "com.google.mediapipe.CameraFeedService.sessionQueue")
    private var cameraPosition: AVCaptureDevice.Position = .front
    
    private var cameraConfigurationStatus: CameraConfigurationStatus = .failed
    private lazy var videoDataOutput = AVCaptureVideoDataOutput()
    private var isSessionRunning = false
    private var imageBufferSize: CGSize?
    private var movieOutput: AVCaptureMovieFileOutput?
    var videoInput: AVAssetWriterInput?
    private var _adpater: AVAssetWriterInputPixelBufferAdaptor?
    private var _time: Double = 0
    // AVAssetWriter property for video saving
    private var assetWriter: AVAssetWriter?
    private var isReacordingStart: Bool = false
    private var isTimerStart: Bool = false
    private var lastTimestamp: CMTime?
    private var frameCount: Double = 0
    private var frameRate: Double = 0
    private var startTimestamp: Int = 0
    private var eventName: String = "Intro"
    private var repCount: String?
    private var frameHeight: Int = 0
    private var frameWidth: Int = 0
    // MARK: CameraFeedServiceDelegate
    weak var delegate: CameraFeedServiceDelegate?
    var counter:Double = 0
    var poseCount:Double = 0
    private var isPoseStarted: Bool =  true
    private var isPortrait: Bool = true
    //  var lastProcessedTimestamp: CMTime = CMTime.zero
    //  let processingInterval: Double = 0.05 // Adjust as needed, represents the desired interval between processing in seconds
    
    // MARK: Initializer
    init(previewView: UIView) {
        super.init()
        
        // Initializes the session
        session.sessionPreset = .hd1280x720
        
        setUpPreviewView(previewView)
        
        attemptToConfigureSession()
        //    NotificationCenter.default.addObserver(
        //      self, selector: #selector(orientationChanged),
        //      name: UIDevice.orientationDidChangeNotification,
        //      object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setUpPreviewView(_ view: UIView) {
        videoPreviewLayer.videoGravity = videoGravity
        if(self.isPortrait){
            videoPreviewLayer.connection?.videoOrientation =  .portrait
        }
        view.layer.addSublayer(videoPreviewLayer)
    }
    
    // MARK: notification methods
//    @objc func orientationChanged(notification: Notification) {
//        if isPortrait {
//            switch UIImage.Orientation.from(deviceOrientation: UIDevice.current.orientation) {
//            case .up:
//                videoPreviewLayer.connection?.videoOrientation = .portrait
//            case .left:
//                videoPreviewLayer.connection?.videoOrientation = .landscapeRight
//            case .right:
//                videoPreviewLayer.connection?.videoOrientation = .landscapeLeft
//            default:
//                break
//            }
//        }
//    }
    
    // MARK: Session Start and End methods
    
    /**
     This method starts an AVCaptureSession based on whether the camera configuration was successful.
     */
    
    func startLiveCameraSession(_ completion: @escaping(_ cameraConfiguration: CameraConfigurationStatus) -> Void) {
        
        sessionQueue.async {
            switch self.cameraConfigurationStatus {
            case .success:
                self.addObservers()
                self.startSession()
            default:
                break
            }
            completion(self.cameraConfigurationStatus)
            
        }
    }
    
    /**
     This method stops a running an AVCaptureSession.
     */
    func stopSession() {
        self.removeObservers()
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        
    }
    
    
    func getPath() -> URL {
        return  videoOutputURL
    }
    
    func setOrientation( isPortrait: Bool) {
        self.isPortrait = isPortrait
    }
    
    func poseStarted(started: Bool) {
        self.isPoseStarted = started
    }
    
    private func configureFrameRate(for device: AVCaptureDevice, frameRate: Int) {
        do {
            try device.lockForConfiguration()
            
            // Set frame rate
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate))
            
            device.unlockForConfiguration()
        } catch {
            print("Error configuring frame rate: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: - Camera Switching
    func switchCamera() {
        
        cameraPosition = cameraPosition == .back ? .front : .back
        
        sessionQueue.async {
            self.session.beginConfiguration()
            
            // Remove existing input
            if let currentInput = self.session.inputs.first {
                self.session.removeInput(currentInput)
            }
            
            self.addVideoDeviceInput()
            
            // Update video orientation
            self.videoPreviewLayer.connection?.videoOrientation = .portrait
            self.videoDataOutput.connection(with: .video)?.videoOrientation = .portrait
            self.videoDataOutput.connection(with: .video)?.isVideoMirrored = self.cameraPosition == .front
            
            // Mirror the preview layer if using front camera
            self.videoPreviewLayer.connection?.automaticallyAdjustsVideoMirroring = false
            self.videoPreviewLayer.connection?.isVideoMirrored = self.cameraPosition == .front
            
            self.session.commitConfiguration()
            
        }
    }
    
    /**
     This method resumes an interrupted AVCaptureSession.
     */
    func resumeInterruptedSession(withCompletion completion: @escaping (Bool) -> ()) {
        sessionQueue.async {
            self.startSession()
            
            DispatchQueue.main.async {
                completion(self.isSessionRunning)
            }
        }
        
    }
    
    func updateVideoPreviewLayer(toFrame frame: CGRect) {
        videoPreviewLayer.frame = frame
    }
    
    /**
     This method starts the AVCaptureSession
     **/
    private func startSession() {
        self.session.startRunning()
        self.isSessionRunning = self.session.isRunning
    }
    
    // MARK: Session Configuration Methods.
    /**
     This method requests for camera permissions and handles the configuration of the session and stores the result of configuration.
     */
    private func attemptToConfigureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            self.cameraConfigurationStatus = .success
        case .notDetermined:
            self.sessionQueue.suspend()
            self.requestCameraAccess(completion: { (granted) in
                self.sessionQueue.resume()
            })
        case .denied:
            self.cameraConfigurationStatus = .permissionDenied
        default:
            break
        }
        
        self.sessionQueue.async {
            self.configureSession()
        }
    }
    
    /**
     This method requests for camera permissions.
     */
    private func requestCameraAccess(completion: @escaping (Bool) -> ()) {
        AVCaptureDevice.requestAccess(for: .video) { (granted) in
            if !granted {
                self.cameraConfigurationStatus = .permissionDenied
            }
            else {
                self.cameraConfigurationStatus = .success
            }
            completion(granted)
        }
    }
    
    /**
     This method tries to add an AVCaptureDeviceInput to the current AVCaptureSession.
     */
    private func addVideoDeviceInput() -> Bool {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition) else {
            return false
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoDeviceInput) {
                session.addInput(videoDeviceInput)
                return true
            } else {
                return false
            }
        } catch {
            fatalError("Cannot create video device input")
        }
    }
    
    
    /**
     This method tries to add an AVCaptureVideoDataOutput to the current AVCaptureSession.
     */
    private func addVideoDataOutput() -> Bool {
        let sampleBufferQueue = DispatchQueue(label: "sampleBufferQueue")
        videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCMPixelFormat_32BGRA]
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            if let connection = videoDataOutput.connection(with: .video) {
                let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition)
                
                self.configureFrameRate(for: videoDevice!, frameRate: 25)
                
                connection.videoOrientation = isPortrait ? .portrait : .landscapeRight
                
                if cameraPosition == .front && connection.isVideoOrientationSupported {
                    connection.isVideoMirrored = true
                }
                if !self.isPortrait {
                    videoPreviewLayer.connection?.videoOrientation = .landscapeRight
                }
            }
            return true
        } else {
            return false
        }
    }
    
    
    /**
     This method handles all the steps to configure an AVCaptureSession.
     */
    private func configureSession() {
        
        guard cameraConfigurationStatus == .success else {
            return
        }
        session.beginConfiguration()
        
        // Add an AVCaptureDeviceInput.
        guard self.addVideoDeviceInput() == true else {
            self.session.commitConfiguration()
            self.cameraConfigurationStatus = .failed
            return
        }
        
        // Add an AVCaptureVideoDataOutput.
        guard self.addVideoDataOutput() else {
            self.session.commitConfiguration()
            self.cameraConfigurationStatus = .failed
            return
        }
        
        // Add an AVCaptureMovieFileOutput.
        guard self.addMovieFileOutput() else {
            self.session.commitConfiguration()
            self.cameraConfigurationStatus = .failed
            return
        }
        
        session.commitConfiguration()
        self.cameraConfigurationStatus = .success
    }
    
    
    /**
     This method tries to add an AVCaptureMovieFileOutput to the current AVCaptureSession.
     */
    private func addMovieFileOutput() -> Bool {
        movieOutput = AVCaptureMovieFileOutput()
        if let movieOutput = movieOutput {
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                return true
            }
        }
        return false
    }
    
    
    
    
    // MARK: Notification Observer Handling
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(CameraFeedService.sessionRuntimeErrorOccured(notification:)), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(CameraFeedService.sessionWasInterrupted(notification:)), name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(CameraFeedService.sessionInterruptionEnded), name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
    }
    
    func observeValueForKeyPath(_ keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "running" {
        }
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionWasInterrupted, object: session)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVCaptureSessionInterruptionEnded, object: session)
    }
    
    
    
    func startRecording(startRecording: Bool) {
        if !isReacordingStart {
            self.assetWriter = nil // Release reference
            self.videoInput = nil
            self._adpater = nil
            videoOutputURL = documentDirectory.appendingPathComponent(generateDynamicFileName())
            isReacordingStart = startRecording
        }
    }
    
    
    func stopRecording() {
        if  isReacordingStart  {
            self.eventName = "Intro"
            isReacordingStart = false
            isTimerStart = false
            guard videoInput?.isReadyForMoreMediaData == true, assetWriter!.status != .failed else { return }
            
            videoInput?.markAsFinished()
            assetWriter?.finishWriting { [weak self] in
                guard let self = self else { return }
                self.assetWriter = nil // Release reference
                self.videoInput = nil
                self._adpater = nil
                print("Video recording finished.") // Or handle success/failure as needed
            }
        }
    }
    
    
    func startTimer(start: Bool) {
        if !isTimerStart{
            self.startTimestamp = Int(Date().timeIntervalSince1970 * 1000)
            isTimerStart = start
        }
    }
    
    func setEvent(name: String) {
        self.eventName = name
    }
    
    func setRepCount(count: String) {
        self.repCount = count
    }
    
    func getFrameResolution()-> [Int] {
        return [self.frameHeight, self.frameWidth]
    }
    
    func getSourceID()-> String {
        
        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        
        // Device ID
        let deviceID = videoDevice!.uniqueID
        print("Device ID: \(deviceID)")
        
        let localizedName = videoDevice!.localizedName
        
        
        return deviceID+"_"+localizedName
    }
    
    
    
    
    // MARK: Notification Observers
    @objc func sessionWasInterrupted(notification: Notification) {
        
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
           let reasonIntegerValue = userInfoValue.integerValue,
           let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted with reason \(reason)")
            
            var canResumeManually = false
            switch reason {
            case .videoDeviceInUseByAnotherClient:
                canResumeManually = true
            default:
                canResumeManually = false
            }
            self.stopRecording()
            self.delegate?.sessionWasInterrupted(canResumeManually: canResumeManually)
            
        }
    }
    
    
    @objc func sessionInterruptionEnded(notification: Notification) {
        //  videoOutputURL = documentDirectory.appendingPathComponent(generateDynamicFileName())
        self.delegate?.sessionInterruptionEnded()
    }
    
    @objc func sessionRuntimeErrorOccured(notification: Notification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else {
            return
        }
        
        print("Capture session runtime error: \(error)")
        
        guard error.code == .mediaServicesWereReset else {
            self.delegate?.didEncounterSessionRuntimeError()
            return
        }
        
        sessionQueue.async {
            if self.isSessionRunning {
                self.startSession()
            } else {
                DispatchQueue.main.async {
                    self.delegate?.didEncounterSessionRuntimeError()
                }
            }
        }
    }
}


let fileManager = FileManager.default
let documentDirectory = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)


func generateDynamicFileName() -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd_HHmmss" // Define the format for the timestamp
    return "JSR\(dateFormatter.string(from: Date())).mp4"
}
// URL for the output video file
private var videoOutputURL: URL = documentDirectory.appendingPathComponent(generateDynamicFileName())
/**
 AVCaptureVideoDataOutputSampleBufferDelegate
 */
extension CameraFeedService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    /** This method delegates the CVPixelBuffer of the frame seen by the camera currently.
     */
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        // Assuming you have these properties defined elsewhere
        guard let imageSize = imageBufferSize else {
            imageBufferSize = CGSize(width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))
            return
        }
        
        if  self.frameHeight == 0 {
            self.frameHeight  = Int(imageSize.height)
        }
        
        if  self.frameWidth == 0 {
            self.frameWidth  = Int(imageSize.width)
        }
        
        //
        //
        if  self.isPoseStarted {
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
           
            if let lastTimestamp = lastTimestamp {
                let elapsed = CMTimeSubtract(timestamp, lastTimestamp)
                let seconds = CMTimeGetSeconds(elapsed)
                
                frameCount += 1
                self.frameRate = Double(frameCount) / seconds
         
            } else {
                // Initial timestamp
                lastTimestamp = timestamp
                frameCount = 0
            }
            
            var currentTimeStamp =  Int(Date().timeIntervalSince1970 * 1000)
          
            let data = LandmarkData(height: imageSize.height, width: imageSize.width, frameNumber: frameCount, presentationTimeStamp: Double(timestamp.value), frameRate: self.frameRate, startTimestamp:currentTimeStamp)
            
            delegate?.didOutput(sampleBuffer: sampleBuffer, orientation: UIImage.Orientation.from(deviceOrientation:  UIDevice.current.orientation), landmarkData: data)
            
            
        }
    }
    
    
    func convertToMMSSFormat(elapsedMilliseconds: Int) -> String {
        let elapsedSeconds = elapsedMilliseconds / 1000
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    
    
    func compressCIImage(ciImage: CIImage, compressionQuality: CGFloat) -> Data? {
        guard let uiImage = UIImage(ciImage: ciImage) else { return nil }
        return uiImage.jpegData(compressionQuality: compressionQuality)
    }
    
    
    func ciImageFromJPEGData(jpegData: Data) -> CIImage? {
        return CIImage(data: jpegData)
    }
    
    
    func processSampleBuffer( imageBuffer : CVImageBuffer,sampleBuffer:CMSampleBuffer, imageSize: CGSize) -> CMSampleBuffer? {
      
        var timerString: String = "00:00"
        let date = Date()
        let currentTimestamp = Int(date.timeIntervalSince1970 * 1000)
        let currentTimestampString = String(currentTimestamp)
        if(isTimerStart){
            let timerTime = currentTimestamp - self.startTimestamp
            timerString = convertToMMSSFormat(elapsedMilliseconds: timerTime);
        }
        
        // Convert image buffer to CIImage
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        
        var timerRepStrig = "Timer "+timerString
        if (self.repCount != nil){
            timerRepStrig = "Timer "+timerString+"\n"+self.repCount!
        }
        
        let texts = [self.eventName, timerRepStrig, "",  currentTimestampString, " / " + String(self.startTimestamp)]
        let logo = UIImage(named: "logo")!
        let limit = frameRate/2
        var watermarkImage:CIImage!
        counter = counter + 1
        if    (watermarkImage == nil || counter > limit){
            counter = 0
            watermarkImage = generateWatermarkImage(imageSize: imageSize, texts: texts, logo: logo)
        }
     
        let watermarkedImage = watermarkImage!.composited(over: ciImage)
        
        // Render the modified CIImage back to a pixel buffer
        guard let newPixelBuffer = renderCIImageToPixelBuffer(watermarkedImage, imageSize: CGSize(width: CVPixelBufferGetWidth(imageBuffer), height: CVPixelBufferGetHeight(imageBuffer))) else {
            print("Error: Failed to render CIImage to pixel buffer")
            return nil
        }
        
        // Create a new CMSampleBuffer with the modified pixel buffer
        var newSampleBuffer: CMSampleBuffer?
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: newPixelBuffer, formatDescriptionOut: &formatDescription)
        
        // Copy timing information from the original sample buffer
        let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        var timingInfo = CMSampleTimingInfo(duration: CMSampleBufferGetDuration(sampleBuffer), presentationTimeStamp: presentationTimeStamp, decodeTimeStamp: CMTime.invalid)
        
        
        
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: newPixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDescription!, sampleTiming: &timingInfo, sampleBufferOut: &newSampleBuffer)
        
        
        
        
        return newSampleBuffer
    }
    
    
    func renderCIImageToPixelBuffer(_ image: CIImage, imageSize: CGSize) -> CVPixelBuffer? {
        let pixelBufferAttrs = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(imageSize.width), Int(imageSize.height), kCVPixelFormatType_32BGRA, pixelBufferAttrs as CFDictionary, &pixelBuffer)
        
        guard let pb = pixelBuffer else { return nil }
        let ciContext = CIContext()
        ciContext.render(image, to: pb)
        
        return pb
    }
    
    func generateWatermarkImage(imageSize: CGSize, texts: [String], logo: UIImage, backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.5)) -> CIImage? {
        let scale = UIScreen.main.scale
        
        
        
        var isPortrait = false;
        if imageSize.height > imageSize.width {
            isPortrait = true
        }
        
        let heightRatio = isPortrait ?  imageSize.height/1920 :  imageSize.width/1920
        let widthRatio = isPortrait ?  imageSize.width/1080 : imageSize.height/1080
        
        
        var size = 165 * widthRatio
        var attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size),
            .foregroundColor: UIColor.white
        ]
        
        //      let texts = [self.eventName, "Timer "+timerString, "",  currentTimestampString, " / " + String(self.startTimestamp)]
        
        
        
        // Define padding for the background
        var padding: CGFloat = 10.0 * widthRatio
        
        // let textSizes = texts.map { NSAttributedString(string: $0, attributes: attributes).size() }
        
        // Create a renderer to draw the text and the watermark image
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            
            // Draw each text at the corresponding fixed position with a background
            //  let positions = [topRight, topRightTextBelow, topLeft, bottomLeft, leftFurther]
            for (index, text) in texts.enumerated() {
                
                var fontSize =  30 * widthRatio
                var fontColor = UIColor.white
                
                
                if index == 0 {
                    fontSize =  isPortrait ?  65 * widthRatio :  65 * widthRatio
                    fontColor  = UIColor.black
                }else  {
                    
                    if index == 1 {
                        fontSize =  isPortrait ?  48 * widthRatio :  48 * widthRatio
                    }
                    
                    if index == 3 || index == 4 {
                        fontSize =   isPortrait ?  42 * widthRatio :  42 * widthRatio
                    }
                }
                
                attributes = [
                    .font: UIFont.systemFont(ofSize: fontSize),
                    .foregroundColor: fontColor
                ]
                
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                var textSize = attributedString.size()
                //          if index == 0 {
                //            textSize = CGSize(width: textSize.width+21, height: textSize.height+14)
                //          }
                //
                //          if index == 3 ||  index == 4 {
                //            textSize = CGSize(width: textSize.width-21, height: textSize.height-14)
                //          }
                
                var color = UIColor.black.withAlphaComponent(0.75)
                var radius: CGFloat = 33 * widthRatio
                var backgroundRect: CGRect?
                
                var textOrigin: CGPoint?
                if index == 0 {
                    textOrigin = CGPoint(x: imageSize.width - textSize.width - 21 * widthRatio , y: isPortrait ? 42 * heightRatio : 52 * heightRatio )
                    color =  UIColor(red: 154/255, green: 212/255, blue: 174/255, alpha: 0.75)
                    radius = 42 * widthRatio
                    backgroundRect = CGRect(
                        x: textOrigin!.x - 37.4 * widthRatio,
                        y: textOrigin!.y - 25 * heightRatio ,
                        width: textSize.width + 140 * widthRatio,
                        height: textSize.height + 55  * heightRatio
                    )
                }
                if index == 1 {
                    textOrigin = CGPoint(x: imageSize.width - 320 * widthRatio, y: isPortrait ? 194 * heightRatio : 210 * heightRatio)
                    backgroundRect = CGRect(
                        x: textOrigin!.x - (37.4 * widthRatio ),
                        y: textOrigin!.y - 25 * heightRatio ,
                        width: textSize.width + 133 * widthRatio,
                        height: textSize.height + 55  * heightRatio
                    )
                }
                
                if index == 2 {
                    color =  UIColor.red
                    textOrigin = CGPoint(x: 0, y: 0)
                    backgroundRect = CGRect(
                        x: 0,
                        y: 0,
                        width: 1,
                        height: 1
                    )
                    radius = 0
                }
                
                
                if index == 3 {
                    textOrigin =  CGPoint(x: 10 * widthRatio, y: imageSize.height - 75 * heightRatio)
                }
                
                if index == 4 {
                    textOrigin =  CGPoint(x: 325 * widthRatio, y: imageSize.height - 75 * heightRatio) // Adjust as needed
                }
                
                
                
                if index == 0 || index == 1  ||  index == 2 {
                    
                    let bezierPath = UIBezierPath(roundedRect: backgroundRect!, cornerRadius: radius)
                    cgContext.setFillColor(color.cgColor)
                    cgContext.addPath(bezierPath.cgPath)
                    cgContext.fillPath()
                }
                // Draw text
                attributedString.draw(at: textOrigin!)
                
            }
            
            // Draw the watermark image at the bottom-left position
            let watermarkSize = CGSize(width: 275 * widthRatio, height: 84 * heightRatio)
            
            let watermarkPosition = CGPoint(x: 10 * widthRatio, y: imageSize.height - watermarkSize.height - 21 * heightRatio) // Adjust position if needed
            let watermarkRect = CGRect(origin: watermarkPosition, size: watermarkSize)
            
            // Flip the context vertically
            cgContext.translateBy(x: 0, y: imageSize.height)
            cgContext.scaleBy(x: 1.0, y: -1.0)
            cgContext.draw(logo.cgImage!, in: watermarkRect)
        }
        
        // Ensure the renderer uses the correct scale factor
        let cgImage = image.cgImage!
        let ciImage = CIImage(cgImage: cgImage, options: nil).transformed(by: CGAffineTransform(scaleX: 1.0 / scale, y: 1.0 / scale))
        
        return ciImage
    }

}




/**
 AVCaptureFileOutputRecordingDelegate
 */
extension CameraFeedService: AVCaptureFileOutputRecordingDelegate {
    
    /** This method gets called when the output started recording to a file.
     */
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        // Handle recording started event
        print("Recording started")
    }
    
    /** This method gets called when the output finished recording to a file.
     */
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Handle recording finished event
        if let error = error {
            print("Recording finished with error: \(error.localizedDescription)")
        } else {
            print("Recording finished successfully.")
        }
    }
}

// MARK: UIImage.Orientation Extension
extension UIImage.Orientation {
    static func from(deviceOrientation: UIDeviceOrientation) -> UIImage.Orientation {
        switch deviceOrientation {
        case .portrait:
            return .up
        case .landscapeLeft:
            return .left
        case .landscapeRight:
            return .right
        default:
            return .up
        }
    }
}




