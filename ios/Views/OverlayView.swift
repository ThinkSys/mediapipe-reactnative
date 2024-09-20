import UIKit
import MediaPipeTasksVision

/// A straight line.
struct Line: Codable {
    let from: CGPoint
    let to: CGPoint
}

/**
 This structure holds the display parameters for the overlay to be drawon on a pose landmarker object.
 */
struct PoseOverlay: Codable {
    let dots: [CGPoint]
    let lines: [Line]
}



/// Custom view to visualize the pose landmarks result on top of the input image.
class OverlayView: UIView {
    
    var poseOverlays: [PoseOverlay] = []
    
    private var contentImageSize: CGSize = CGSizeZero
    var imageContentMode: UIView.ContentMode = .scaleAspectFit
    private var orientation = UIDeviceOrientation.portrait
    
    private var edgeOffset: CGFloat = 0.0
    
    
    // MARK: Public Functions
    func draw(
        poseOverlays: [PoseOverlay],
        inBoundsOfContentImageOfSize imageSize: CGSize,
        edgeOffset: CGFloat = 0.0,
        imageContentMode: UIView.ContentMode,
        isPortrait: Bool) {
            
            self.clear()
            contentImageSize = imageSize
            self.edgeOffset = edgeOffset
            self.poseOverlays = poseOverlays
            self.imageContentMode = imageContentMode
            orientation = UIDevice.current.orientation
            self.setNeedsDisplay()
        }
    
    
    func redrawPoseOverlays(forNewDeviceOrientation deviceOrientation:UIDeviceOrientation) {
        
        orientation = deviceOrientation
        
        switch orientation {
        case .portrait:
            fallthrough
        case .landscapeLeft:
            fallthrough
        case .landscapeRight:
            self.setNeedsDisplay()
        default:
            return
        }
    }
    
    func clear() {
        poseOverlays = []
        contentImageSize = CGSize.zero
        imageContentMode = .scaleAspectFit
        orientation = UIDevice.current.orientation
        edgeOffset = 0.0
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        for poseOverlay in poseOverlays {
            drawLines(poseOverlay.lines)
            //      drawDots(poseOverlay.dots)
        }
    }
    
    // MARK: Private Functions
    private func rectAfterApplyingBoundsAdjustment(
        onOverlayBorderRect borderRect: CGRect) -> CGRect {
            
            var currentSize = self.bounds.size
            let minDimension = min(self.bounds.width, self.bounds.height)
            let maxDimension = max(self.bounds.width, self.bounds.height)
            
            switch orientation {
            case .portrait:
                currentSize = CGSizeMake(minDimension, maxDimension)
            case .landscapeLeft:
                fallthrough
            case .landscapeRight:
                currentSize = CGSizeMake(maxDimension, minDimension)
            default:
                break
            }
            
            let offsetsAndScaleFactor = OverlayView.offsetsAndScaleFactor(
                forImageOfSize: self.contentImageSize,
                tobeDrawnInViewOfSize: currentSize,
                withContentMode: imageContentMode)
            
            var newRect = borderRect
                .applying(
                    CGAffineTransform(scaleX: offsetsAndScaleFactor.scaleFactor, y: offsetsAndScaleFactor.scaleFactor)
                )
                .applying(
                    CGAffineTransform(translationX: offsetsAndScaleFactor.xOffset, y: offsetsAndScaleFactor.yOffset)
                )
            
            if newRect.origin.x < 0 &&
                newRect.origin.x + newRect.size.width > edgeOffset {
                newRect.size.width = newRect.maxX - edgeOffset
                newRect.origin.x = edgeOffset
            }
            
            if newRect.origin.y < 0 &&
                newRect.origin.y + newRect.size.height > edgeOffset {
                newRect.size.height += newRect.maxY - edgeOffset
                newRect.origin.y = edgeOffset
            }
            
            if newRect.maxY > currentSize.height {
                newRect.size.height = currentSize.height - newRect.origin.y  - edgeOffset
            }
            
            if newRect.maxX > currentSize.width {
                newRect.size.width = currentSize.width - newRect.origin.x - edgeOffset
            }
            
            return newRect
        }
    
    private func drawDots(_ dots: [CGPoint]) {
        for dot in dots {
            let dotRect = CGRect(
                x: CGFloat(dot.x) - DefaultConstants.pointRadius / 2,
                y: CGFloat(dot.y) - DefaultConstants.pointRadius / 2,
                width: DefaultConstants.pointRadius,
                height: DefaultConstants.pointRadius)
            let path = UIBezierPath(ovalIn: dotRect)
            DefaultConstants.pointFillColor.setFill()
            DefaultConstants.pointColor.setStroke()
            path.stroke()
            path.fill()
        }
    }
    
    private func drawLines(_ lines: [Line]) {
        let path = UIBezierPath()
        for line in lines {
            path.move(to: line.from)
            path.addLine(to: line.to)
        }
        path.lineWidth = DefaultConstants.lineWidth
        DefaultConstants.lineColor.setStroke()
        path.stroke()
    }
    
    // MARK: Helper Functions
    static func offsetsAndScaleFactor(
        forImageOfSize imageSize: CGSize,
        tobeDrawnInViewOfSize viewSize: CGSize,
        withContentMode contentMode: UIView.ContentMode)
    -> (xOffset: CGFloat, yOffset: CGFloat, scaleFactor: Double) {
        
        let widthScale = viewSize.width / imageSize.width;
        let heightScale = viewSize.height / imageSize.height;
        
        var scaleFactor = 0.0
        
        switch contentMode {
        case .scaleAspectFill:
            scaleFactor = max(widthScale, heightScale)
        case .scaleAspectFit:
            scaleFactor = min(widthScale, heightScale)
        default:
            scaleFactor = 1.0
        }
        
        let scaledSize = CGSize(
            width: imageSize.width * scaleFactor,
            height: imageSize.height * scaleFactor)
        let xOffset = (viewSize.width - scaledSize.width) / 2
        let yOffset = (viewSize.height - scaledSize.height) / 2
        
        return (xOffset, yOffset, scaleFactor)
    }
    
    func generateConnections(filters: [String: Bool]) -> [Connection] {
        var connections: [Connection] = []
        
        if filters["face"] == true {
            connections.append(contentsOf: [
                Connection(start: 0, end: 1),
                Connection(start: 1, end: 2),
                Connection(start: 2, end: 3),
                Connection(start: 3, end: 7),
                Connection(start: 0, end: 4),
                Connection(start: 4, end: 5),
                Connection(start: 5, end: 6),
                Connection(start: 6, end: 8),
                Connection(start: 9, end: 10)
            ])
        }
        
        if filters["leftArm"] == true {
            connections.append(contentsOf: [
                Connection(start: 11, end: 13),
                Connection(start: 13, end: 15)
            ])
        }
        
        if filters["rightArm"] == true {
            connections.append(contentsOf: [
                Connection(start: 12, end: 14),
                Connection(start: 14, end: 16)
            ])
        }
        
        if filters["leftWrist"] == true {
            connections.append(contentsOf: [
                Connection(start: 15, end: 17),
                Connection(start: 15, end: 19),
                Connection(start: 15, end: 21)
            ])
        }
        
        if filters["rightWrist"] == true {
            connections.append(contentsOf: [
                Connection(start: 16, end: 18),
                Connection(start: 16, end: 20),
                Connection(start: 16, end: 22)
            ])
        }
        
        if filters["torso"] == true {
            connections.append(contentsOf: [
                Connection(start: 11, end: 12),
                Connection(start: 11, end: 23),
                Connection(start: 12, end: 24),
                Connection(start: 23, end: 24)
            ])
        }
        
        if filters["leftLeg"] == true {
            connections.append(contentsOf: [
                Connection(start: 23, end: 25),
                Connection(start: 25, end: 27)
            ])
        }
        
        if filters["rightLeg"] == true {
            connections.append(contentsOf: [
                Connection(start: 24, end: 26),
                Connection(start: 26, end: 28)
            ])
        }
        
        if filters["leftAnkle"] == true {
            connections.append(contentsOf: [
                Connection(start: 27, end: 29),
                Connection(start: 27, end: 31)
            ])
        }
        
        if filters["rightAnkle"] == true {
            connections.append(contentsOf: [
                Connection(start: 28, end: 30),
                Connection(start: 28, end: 32)
            ])
        }
        
        return connections
    }
    
    // Helper to get object overlays from detections.
    func poseOverlays(
        fromMultiplePoseLandmarks landmarks: [[NormalizedLandmark]],
        inferredOnImageOfSize originalImageSize: CGSize,
        ovelayViewSize: CGSize,
        imageContentMode: UIView.ContentMode,
        andOrientation orientation: UIImage.Orientation, isPortrait: Bool, propDictionary: [String: Bool]) -> [PoseOverlay] {
            
            var poseOverlays: [PoseOverlay] = []
            
            guard !landmarks.isEmpty else {
                return []
            }
            
            let offsetsAndScaleFactor = OverlayView.offsetsAndScaleFactor(
                forImageOfSize: originalImageSize,
                tobeDrawnInViewOfSize: ovelayViewSize,
                withContentMode: imageContentMode)
            
            for poseLandmarks in landmarks {
                var transformedPoseLandmarks: [CGPoint]!
                
                switch orientation {
                case .left:
                    transformedPoseLandmarks = poseLandmarks.map({CGPoint(x: CGFloat($0.y), y: 1 - CGFloat($0.x))})
                case .right:
                    transformedPoseLandmarks = poseLandmarks.map({CGPoint(x: 1 - CGFloat($0.y), y: CGFloat($0.x))})
                default:
                    transformedPoseLandmarks = poseLandmarks.map({CGPoint(x: CGFloat($0.x), y: CGFloat($0.y))})
                }
                
                let dots: [CGPoint] = transformedPoseLandmarks.map({CGPoint(x: CGFloat($0.x) * originalImageSize.width * offsetsAndScaleFactor.scaleFactor + offsetsAndScaleFactor.xOffset, y: CGFloat($0.y) * originalImageSize.height * offsetsAndScaleFactor.scaleFactor + offsetsAndScaleFactor.yOffset)})
                //          let lines: [Line] = PoseLandmarker.poseLandmarks
                //            .map({ connection in
                //              let start = dots[Int(connection.start)]
                //              let end = dots[Int(connection.end)]
                //              return Line(from: start,
                //                          to: end)
                //            })
                
                let connections = generateConnections(filters: propDictionary)
                
                let lines = connections.compactMap { connection in
                    let startIndex = dots[Int(connection.start)]
                    let endIndex = dots[Int(connection.end)]
                    return Line(from: startIndex, to: endIndex)
                }
                
                poseOverlays.append(PoseOverlay(dots: dots, lines: lines))
            }
            
            return poseOverlays
        }
}
