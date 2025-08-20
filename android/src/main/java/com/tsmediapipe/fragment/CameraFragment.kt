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
      // Use global overrides if provided from JS props
      val delegateOverride = com.tsmediapipe.GlobalState.delegate
      val modelOverride = com.tsmediapipe.GlobalState.model

      // Reflect overrides into viewModel used to build helper
      viewModel.setDelegate(delegateOverride)
      viewModel.setModel(modelOverride)

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

    // Delay starting until after layout to avoid black preview on some devices
    fragmentCameraBinding.viewFinder.post {
      if (!hasPermissions(requireContext())) {
        requestPermissionLauncher.launch(
          Manifest.permission.CAMERA
        )
      } else {
        completeCameraSetUpWithPose()
      }
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

    // Validate available lens before selecting
    val hasBack = try { cameraProvider.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA) } catch (e: Exception) { false }
    val hasFront = try { cameraProvider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA) } catch (e: Exception) { false }
    cameraFacing = when (cameraFacing) {
      CameraSelector.LENS_FACING_BACK -> if (hasBack) CameraSelector.LENS_FACING_BACK else CameraSelector.LENS_FACING_FRONT
      else -> if (hasFront) CameraSelector.LENS_FACING_FRONT else CameraSelector.LENS_FACING_BACK
    }
    val cameraSelector = CameraSelector.Builder().requireLensFacing(cameraFacing).build()

    preview = Preview.Builder().setTargetAspectRatio(AspectRatio.RATIO_4_3)
      .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
      .build()

    imageAnalyzer =
      ImageAnalysis.Builder()
        .setTargetAspectRatio(AspectRatio.RATIO_4_3)
        .setTargetRotation(fragmentCameraBinding.viewFinder.display.rotation)
        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .setImageQueueDepth(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
        .build()
        .also {
          it.setAnalyzer(backgroundExecutor) { image ->
            try {
              detectPose(image)
            } finally {
              // Ensure image is closed promptly to avoid analyzer stalls
              if (!image.isClosed) image.close()
            }
          }
        }

    cameraProvider.unbindAll()

    try {
      camera = cameraProvider.bindToLifecycle(
        this, cameraSelector, preview, imageAnalyzer
      )
      // Ensure UI thread for setting provider
      requireActivity().runOnUiThread {
        preview?.setSurfaceProvider(fragmentCameraBinding.viewFinder.surfaceProvider)
      }
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
    val provider = cameraProvider
    val backAvailable = try { provider?.hasCamera(CameraSelector.DEFAULT_BACK_CAMERA) ?: false } catch (_: Exception) { false }
    val frontAvailable = try { provider?.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA) ?: false } catch (_: Exception) { false }
    cameraFacing = if (cameraFacing == CameraSelector.LENS_FACING_BACK) {
      if (frontAvailable) CameraSelector.LENS_FACING_FRONT else CameraSelector.LENS_FACING_BACK
    } else {
      if (backAvailable) CameraSelector.LENS_FACING_BACK else CameraSelector.LENS_FACING_FRONT
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


        val reactContext = ReactContextProvider.reactApplicationContext
        // Optional throttle by eventHz from GlobalState
        val hz = com.tsmediapipe.GlobalState.eventHz
        val canEmit = if (hz > 0) {
          val now = SystemClock.uptimeMillis()
          val interval = 1000L / hz
          val last = lastEmitTs
          if (now - last >= interval) {
            lastEmitTs = now
            true
          } else false
        } else true
        if (canEmit) {
          // Emit as a structured map for parity with iOS
          val map = com.facebook.react.bridge.Arguments.createMap()
          val landmarksArray = com.facebook.react.bridge.Arguments.createArray()
          for (lm in landmarksArray) { /* placeholder to keep structure */ }
          // Instead of rebuilding from scratch, parse swiftDict with Gson to WritableMap
          val gson = Gson()
          val jsonData = gson.toJson(swiftDict)
          val readable = com.facebook.react.bridge.Arguments.createMap()
          // Use a small JSON parser to convert string → map
          try {
            val jsonObj = org.json.JSONObject(jsonData)
            val writable = com.facebook.react.bridge.Arguments.createMap()
            fun putAny(key: String, value: Any?) {
              when (value) {
                is Number -> writable.putDouble(key, value.toDouble())
                is String -> writable.putString(key, value)
                is Boolean -> writable.putBoolean(key, value)
                is org.json.JSONObject -> writable.putMap(key, com.facebook.react.bridge.Arguments.makeNativeMap(value))
                is org.json.JSONArray -> writable.putArray(key, com.facebook.react.bridge.Arguments.makeNativeArray(value))
                else -> writable.putNull(key)
              }
            }
            val keys = jsonObj.keys()
            while (keys.hasNext()) {
              val k = keys.next()
              putAny(k, jsonObj.get(k))
            }
            reactContext?.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
              ?.emit("onLandmark", writable)
          } catch (e: Exception) {
            // Fallback to string
            reactContext?.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
              ?.emit("onLandmark", jsonData)
          }
        }

        if (com.tsmediapipe.GlobalState.showOverlay) {
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
  }

  override fun onError(error: String, errorCode: Int) {
    activity?.runOnUiThread {
      Toast.makeText(requireContext(), error, Toast.LENGTH_SHORT).show()
      if (errorCode == PoseLandmarkerHelper.GPU_ERROR) {
      }
    }
  }
}
