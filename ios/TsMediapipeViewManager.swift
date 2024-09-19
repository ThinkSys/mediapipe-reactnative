import Foundation
import React

@objc(TsMediapipeViewManager)
class TsMediapipeViewManager: RCTViewManager {
    
    let cameraView = CameraView()
    
    override func view() -> (UIView) {
        return cameraView
    }
    
    @objc override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc func switchCamera() {
        cameraView.switchCamera()
    }
    
    
}
