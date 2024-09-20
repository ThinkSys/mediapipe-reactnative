package com.tsmediapipe

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import kotlin.math.max
import kotlin.math.min

class OverlayView(context: Context?, attrs: AttributeSet?) :
  View(context, attrs) {

  private var results: PoseLandmarkerResult? = null
  private var pointPaint = Paint()
  private var linePaint = Paint()

  private var scaleFactor: Float = 1f
  private var imageWidth: Int = 1
  private var imageHeight: Int = 1

  init {
    initPaints()
  }

  fun clear() {
    results = null
    pointPaint.reset()
    linePaint.reset()
    invalidate()
    initPaints()
  }

  private fun initPaints() {
    linePaint.color =
      ContextCompat.getColor(context!!, R.color.icActive)
    linePaint.strokeWidth = LANDMARK_STROKE_WIDTH
    linePaint.style = Paint.Style.STROKE

    pointPaint.color = Color.YELLOW
    pointPaint.strokeWidth = LANDMARK_STROKE_WIDTH
    pointPaint.style = Paint.Style.FILL
  }

  override fun draw(canvas: Canvas) {
    super.draw(canvas)

    val face = GlobalState.isFaceEnabled
    val torso = GlobalState.isTorsoEnabled
    val leftArm = GlobalState.isLeftArmEnabled
    val rightArm = GlobalState.isRightArmEnabled
    val leftLeg = GlobalState.isLeftLegEnabled
    val rightLeg = GlobalState.isRightLegEnabled
    val leftWrist = GlobalState.isLeftWristEnabled
    val rightWrist = GlobalState.isRightWristEnabled
    val leftAnkle = GlobalState.isLeftAnkleEnabled
    val rightAnkle = GlobalState.isRightAnkleEnabled

    results?.let { poseLandmarkerResult ->
      for (landmark in poseLandmarkerResult.landmarks()) {
//        for((count, normalizedLandmark) in landmark.withIndex()) {
//          if(count in 11..14 || count in 23..26){
//            canvas.drawPoint(
//              normalizedLandmark.x() * imageWidth * scaleFactor,
//              normalizedLandmark.y() * imageHeight * scaleFactor,
//              pointPaint
//            )
//          }
//          else{
//            continue;
//          }
//        }

        for ((count, it) in PoseLandmarker.POSE_LANDMARKS.withIndex()) {
          if (face && it.start() in 0..10) {
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }

          if (torso && ((it.start() == 11 && it.end() == 12) || (it.start() == 23 && it.end() == 24) || (it.start() == 11 && it.end() == 23) || (it.start() == 12 && it.end() == 24))) {
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }

          if (leftArm && ((it.start() == 11 && it.end() == 13) || (it.start() == 13 && it.end() == 15))) {
            print("left arm true cond")
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }

          if (rightArm && ((it.start() == 12 && it.end() == 14) || (it.start() == 14 && it.end() == 16))) {
            print("right arm true cond")
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }

          if (leftLeg && ((it.start() == 23 && it.end() == 25) || (it.start() == 25 && it.end() == 27))) {
            print("left leg true cond")
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }

          if (rightLeg && ((it.start() == 24 && it.end() == 26) || (it.start() == 26 && it.end() == 28))) {
            print("right leg true cond")
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }

          if (leftWrist && ((it.start() == 15 && it.end() == 21) || (it.start() == 15 && it.end() == 17) || (it.start() == 15 && it.end() == 19) || (it.start() == 17 && it.end() == 19))) {
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }

          if (rightWrist && ((it.start() == 16 && it.end() == 22) || (it.start() == 16 && it.end() == 20) || (it.start() == 16 && it.end() == 18) || (it.start() == 18 && it.end() == 20))) {
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }

          if (leftAnkle && ((it.start() == 27 && it.end() == 29) || (it.start() == 27 && it.end() == 31) || (it.start() == 29 && it.end() == 31))) {
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }
          if (rightAnkle && ((it.start() == 28 && it.end() == 30) || (it.start() == 28 && it.end() == 32) || (it.start() == 30 && it.end() == 32))) {
            canvas.drawLine(
              poseLandmarkerResult.landmarks()[0][it!!.start()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.start()].y() * imageHeight * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].x() * imageWidth * scaleFactor,
              poseLandmarkerResult.landmarks()[0][it.end()].y() * imageHeight * scaleFactor,
              linePaint
            )
          }
        }
      }
    }
  }

  fun setResults(
    poseLandmarkerResults: PoseLandmarkerResult,
    imageHeight: Int,
    imageWidth: Int,
    runningMode: RunningMode = RunningMode.LIVE_STREAM
  ) {
    results = poseLandmarkerResults

    this.imageHeight = imageHeight
    this.imageWidth = imageWidth

    scaleFactor = when (runningMode) {
      RunningMode.IMAGE,
      RunningMode.VIDEO -> {
        min(width * 1f / imageWidth, height * 1f / imageHeight)
      }

      RunningMode.LIVE_STREAM -> {
        // PreviewView is in FILL_START mode. So we need to scale up the
        // landmarks to match with the size that the captured images will be
        // displayed.
        max(width * 1f / imageWidth, height * 1f / imageHeight)
      }
    }
    invalidate()
  }

  companion object {
    private const val LANDMARK_STROKE_WIDTH = 10F
  }
}
