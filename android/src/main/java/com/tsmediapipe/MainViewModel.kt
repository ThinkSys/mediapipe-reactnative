package com.tsmediapipe

import androidx.lifecycle.ViewModel

/**
 *  This ViewModel is used to store pose landmarker helper settings
 */
class MainViewModel : ViewModel() {

  private var _model = PoseLandmarkerHelper.MODEL_POSE_LANDMARKER_FULL
  private var _delegate: Int = PoseLandmarkerHelper.DELEGATE_CPU
  private var _minPoseDetectionConfidence: Float =
    PoseLandmarkerHelper.DEFAULT_POSE_DETECTION_CONFIDENCE
  private var _minPoseTrackingConfidence: Float = PoseLandmarkerHelper
    .DEFAULT_POSE_TRACKING_CONFIDENCE
  private var _minPosePresenceConfidence: Float = PoseLandmarkerHelper
    .DEFAULT_POSE_PRESENCE_CONFIDENCE

  val currentDelegate: Int get() = _delegate
  val currentModel: Int get() = _model
  val currentMinPoseDetectionConfidence: Float
    get() =
      _minPoseDetectionConfidence
  val currentMinPoseTrackingConfidence: Float
    get() =
      _minPoseTrackingConfidence
  val currentMinPosePresenceConfidence: Float
    get() =
      _minPosePresenceConfidence

  fun setDelegate(delegate: Int) {
    _delegate = delegate
  }

  fun setMinPoseDetectionConfidence(confidence: Float) {
    _minPoseDetectionConfidence = confidence
  }

  fun setMinPoseTrackingConfidence(confidence: Float) {
    _minPoseTrackingConfidence = confidence
  }

  fun setMinPosePresenceConfidence(confidence: Float) {
    _minPosePresenceConfidence = confidence
  }

  fun setModel(model: Int) {
    _model = model
  }
}
