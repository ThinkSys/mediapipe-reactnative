package com.tsmediapipe.fragment

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Bundle
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.AspectRatio
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import com.facebook.react.modules.core.DeviceEventManagerModule
import com.google.gson.Gson
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.tsmediapipe.CameraFragmentManager
import com.tsmediapipe.MainViewModel
import com.tsmediapipe.PoseLandmarkerHelper
import com.tsmediapipe.ReactContextProvider
import com.tsmediapipe.databinding.FragmentMyCameraBinding
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class CameraFragment : Fragment(), PoseLandmarkerHelper.LandmarkerListener {

  companion object {
    private const val TAG = "Pose Landmarker"
  }

  private var _fragmentCameraBinding: FragmentMyCameraBinding? = null
  private val PERMISSIONS_REQUIRED = arrayOf(Manifest.permission.CAMERA)

  private val fragmentCameraBinding
    get() = _fragmentCameraBinding!!

  private lateinit var poseLandmarkerHelper: PoseLandmarkerHelper
  private val viewModel: MainViewModel by activityViewModels()
  private var preview: Preview? = null
  private var imageAnalyzer: ImageAnalysis? = null
  private var camera: Camera? = null
  private var cameraProvider: ProcessCameraProvider? = null
  private var cameraFacing = CameraSelector.LENS_FACING_FRONT

  /** Blocking ML operations are performed using this executor */
  private lateinit var backgroundExecutor: ExecutorService

  fun hasPermissions(context: Context) = PERMISSIONS_REQUIRED.all {
    ContextCompat.checkSelfPermission(
      context,
      it
    ) == PackageManager.PERMISSION_GRANTED
  }

  private val requestPermissionLauncher =
    registerForActivityResult(
      ActivityResultContracts.RequestPermission()
    ) { isGranted: Boolean ->
      if (isGranted) {
        Toast.makeText(
          context,
          "Permission request granted",
          Toast.LENGTH_LONG
        ).show()
        completeCameraSetUpWithPose()

      } else {
        Toast.makeText(
          context,
          "Permission request denied",
          Toast.LENGTH_LONG
        ).show()
      }
    }

  fun completeCameraSetUpWithPose() {
    setUpCamera()

    // Create the PoseLandmarkerHelper that will handle the inference
    backgroundExecutor.execute {
      poseLandmarkerHelper = PoseLandmarkerHelper(
        context = requireContext(),
        runningMode = RunningMode.LIVE_STREAM,
        minPoseDetectionConfidence = viewModel.currentMinPoseDetectionConfidence,
        minPoseTrackingConfidence = viewModel.currentMinPoseTrackingConfidence,
        minPosePresenceConfidence = viewModel.currentMinPosePresenceConfidence,
        currentDelegate = viewModel.currentDelegate,
        poseLandmarkerHelperListener = this
      )
    }
  }

  override fun onResume() {
    super.onResume()

    // Start the PoseLandmarkerHelper again when users come back
    // to the foreground.
    backgroundExecutor.execute {
      if (this::poseLandmarkerHelper.isInitialized) {
        if (poseLandmarkerHelper.isClose()) {
          poseLandmarkerHelper.setupPoseLandmarker()
        }
      }
    }
  }

  override fun onPause() {
    super.onPause()
    if (this::poseLandmarkerHelper.isInitialized) {
      viewModel.setMinPoseDetectionConfidence(poseLandmarkerHelper.minPoseDetectionConfidence)
      viewModel.setMinPoseTrackingConfidence(poseLandmarkerHelper.minPoseTrackingConfidence)
      viewModel.setMinPosePresenceConfidence(poseLandmarkerHelper.minPosePresenceConfidence)
      viewModel.setDelegate(poseLandmarkerHelper.currentDelegate)

      // Close the PoseLandmarkerHelper and release resources
      backgroundExecutor.execute { poseLandmarkerHelper.clearPoseLandmarker() }
    }
  }

  override fun onDestroyView() {
    _fragmentCameraBinding = null
    super.onDestroyView()

    backgroundExecutor.shutdown()
    backgroundExecutor.awaitTermination(
      Long.MAX_VALUE, TimeUnit.NANOSECONDS
    )
  }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    CameraFragmentManager.cameraFragment = this
  }

  override fun onDestroy() {
    super.onDestroy()
    CameraFragmentManager.cameraFragment = null
  }

  override fun onCreateView(
    inflater: LayoutInflater,
    container: ViewGroup?,
    savedInstanceState: Bundle?
  ): View {
    _fragmentCameraBinding =
      FragmentMyCameraBinding.inflate(inflater, container, false)

    return fragmentCameraBinding.root
  }

  @SuppressLint("MissingPermission")
  override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
    super.onViewCreated(view, savedInstanceState)

    // Initialize our background executor
    backgroundExecutor = Executors.newSingleThreadExecutor()

    if (!hasPermissions(requireContext())) {
      requestPermissionLauncher.launch(
        Manifest.permission.CAMERA
      )
    } else {
      completeCameraSetUpWithPose()
    }
  }

  private fun setUpCamera() {
    val cameraProviderFuture =
      ProcessCameraProvider.getInstance(requireContext())
    cameraProviderFuture.addListener(
      {
        cameraProvider = cameraProviderFuture.get()
        bindCameraUseCases()
      }, ContextCompat.getMainExecutor(requireContext())
    )
  }

  @SuppressLint("UnsafeOptInUsageError")
  private fun bindCameraUseCases() {
    val cameraProvider = cameraProvider
      ?: throw IllegalStateException("Camera initialization failed.")

    val cameraSelector =
      CameraSelector.Builder().requireLensFacing(cameraFacing).build()

    preview = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
      .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
      .build()

    imageAnalyzer =
      ImageAnalysis.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
        .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
        .build()
        .also {
          it.setAnalyzer(backgroundExecutor) { image ->
            detectPose(image)
          }
        }

    cameraProvider.unbindAll()

    try {
      camera = cameraProvider.bindToLifecycle(
        this, cameraSelector, preview, imageAnalyzer
      )

      preview?.setSurfaceProvider(fragmentCameraBinding.viewFinder.surfaceProvider)
    } catch (exc: Exception) {
      Log.e(TAG, "Use case binding failed", exc)
    }
  }

  private fun detectPose(imageProxy: ImageProxy) {
    if (this::poseLandmarkerHelper.isInitialized) {
      poseLandmarkerHelper.detectLiveStream(
        imageProxy = imageProxy,
        isFrontCamera = cameraFacing == CameraSelector.LENS_FACING_FRONT
      )
    }
  }

  fun switchCamera() {
    cameraFacing = if (cameraFacing == CameraSelector.LENS_FACING_BACK) {
      CameraSelector.LENS_FACING_FRONT
    } else {
      CameraSelector.LENS_FACING_BACK
    }
    Log.d(
      "CameraFragment",
      "Switched camera to ${if (cameraFacing == CameraSelector.LENS_FACING_BACK) "BACK" else "FRONT"}"
    )
    // Add your code to bind camera use cases again with the new cameraFacing value
    bindCameraUseCases()
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    imageAnalyzer?.targetRotation =
      fragmentCameraBinding.viewFinder.display.rotation
  }

  override fun onResults(
    resultBundle: PoseLandmarkerHelper.ResultBundle
  ) {
    activity?.runOnUiThread {
      if (_fragmentCameraBinding != null) {

        val data = resultBundle.results.first()
        val landmarksArray: MutableList<Map<String, Any>> = mutableListOf()
        val worldLandmarksArray: MutableList<Map<String, Any>> = mutableListOf()

        val landmarks = data.landmarks()
        val worldLandmarks = data.worldLandmarks()

        if (landmarks.isNotEmpty()) {
          for (landmark in landmarks[0]) {
            val landmarkData: Map<String, Any> = mapOf(
              "x" to landmark.x(),
              "y" to landmark.y(),
              "z" to landmark.z(),
              "visibility" to landmark.visibility().get(),
              "presence" to landmark.presence().get()
            )
            landmarksArray.add(landmarkData)
          }
        }

        worldLandmarks?.let {
          if (it.isNotEmpty() && it[0].size == 33) {
            for (worldLandmark in it[0]) {
              // Assuming similar structure for worldLandmark as for landmark
              val worldLandmarkData: Map<String, Any> = mapOf(
                "x" to worldLandmark.x(),
                "y" to worldLandmark.y(),
                "z" to worldLandmark.z(),
                "visibility" to worldLandmark.visibility().get(),
                "presence" to worldLandmark.presence().get()
              )
              worldLandmarksArray.add(worldLandmarkData)
            }
          }
        }

        val additionalData = mapOf(
          "height" to resultBundle.inputImageHeight,
          "width" to resultBundle.inputImageWidth,
//          "presentationTimeStamp" to resultBundle.presentationTimeStamp,
//          "frameNumber" to resultBundle.frameNumber,
//          "startTimestamp" to resultBundle.startTimestamp
        )

        val swiftDict: MutableMap<String, Any> = mutableMapOf(
          "landmarks" to landmarksArray,
          "additionalData" to additionalData,
          "worldLandmarks" to worldLandmarksArray
        )


        val gson = Gson()
        val jsonData = gson.toJson(swiftDict)

        val reactContext = ReactContextProvider.reactApplicationContext
        reactContext?.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
          ?.emit("onLandmark", jsonData)

        fragmentCameraBinding.myOverlay.setResults(
          resultBundle.results.first(),
          resultBundle.inputImageHeight,
          resultBundle.inputImageWidth,
          RunningMode.LIVE_STREAM
        )
        fragmentCameraBinding.myOverlay.invalidate()
      }
    }
  }

  override fun onError(error: String, errorCode: Int) {
    activity?.runOnUiThread {
      Toast.makeText(requireContext(), error, Toast.LENGTH_SHORT).show()
      if (errorCode == PoseLandmarkerHelper.GPU_ERROR) {
      }
    }
  }
}
