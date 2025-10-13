import Foundation
import React

@objc(TsMediapipeViewManager)
class TsMediapipeViewManager: RCTViewManager {
    
    private var cameraView: CameraView?
    
    override func view() -> (UIView) {
        let view = CameraView()
        cameraView = view
        return view
    }
    
    @objc override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    @objc func switchCamera() {
        cameraView?.switchCamera()
    }
    
    
}
