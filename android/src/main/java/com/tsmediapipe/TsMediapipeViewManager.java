package com.tsmediapipe;

import android.util.Log;
import android.view.Choreographer;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentActivity;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.common.MapBuilder;
import com.facebook.react.uimanager.annotations.ReactProp;
import com.facebook.react.uimanager.ViewGroupManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.tsmediapipe.fragment.CameraFragment;

import java.util.Map;

public class TsMediapipeViewManager extends ViewGroupManager<FrameLayout> {


  public static final String REACT_CLASS = "TsMediapipeViewManager";
  public final int COMMAND_CREATE = 1;
  private int propWidth;
  private int propHeight;

  ReactApplicationContext reactContext;

  public TsMediapipeViewManager(ReactApplicationContext reactContext) {
    this.reactContext = reactContext;
  }

  @Override
  public String getName() {
    return REACT_CLASS;
  }

  private OverlayView overlayView;

  /**
   * Return a FrameLayout which will later hold the Fragment
   */
  @Override
  public FrameLayout createViewInstance(ThemedReactContext reactContext) {
    Log.d("hello", "createViewInstance");

    return new FrameLayout(reactContext);
  }

  /**
   * Map the "create" command to an integer
   */
  @Nullable
  @Override
  public Map<String, Integer> getCommandsMap() {
    return MapBuilder.of("create", COMMAND_CREATE);
  }

  /**
   * Handle "create" command (called from JS) and call createFragment method
   */
  @Override
  public void receiveCommand(
    @NonNull FrameLayout root,
    String commandId,
    @Nullable ReadableArray args
  ) {

    super.receiveCommand(root, commandId, args);
    int reactNativeViewId = args.getInt(0);
    int commandIdInt = Integer.parseInt(commandId);

    switch (commandIdInt) {
      case COMMAND_CREATE:
        createFragment(root, reactNativeViewId);
        break;
      default: {
      }
    }
  }

  @ReactProp(name = "width")
  public void setWidthProp(FrameLayout view, Integer width) {
    propWidth = width;
  }

  @ReactProp(name = "height")
  public void setHeightProp(FrameLayout view, Integer height) {
    propHeight = height;
  }

  @ReactProp(name = "face")
  public void setFaceProp(View view, boolean face) {
    GlobalState.isFaceEnabled = face;
  }

  @ReactProp(name = "leftArm")
  public void setLeftArmProp(View view, boolean leftArm) {
    GlobalState.isLeftArmEnabled = leftArm;
  }

  @ReactProp(name = "rightArm")
  public void setRightArmProp(View view, boolean rightArm) {
    GlobalState.isRightArmEnabled = rightArm;
  }

  @ReactProp(name = "leftWrist")
  public void setLeftWristProp(View view, boolean leftWrist) {
    GlobalState.isLeftWristEnabled = leftWrist;
  }

  @ReactProp(name = "rightWrist")
  public void setRightWristProp(View view, boolean rightWrist) {
    GlobalState.isRightWristEnabled = rightWrist;
  }

  @ReactProp(name = "torso")
  public void setTorsoProp(View view, boolean torso) {
    GlobalState.isTorsoEnabled = torso;
  }

  @ReactProp(name = "leftLeg")
  public void setLeftLegProp(View view, boolean leftLeg) {
    GlobalState.isLeftLegEnabled = leftLeg;
  }

  @ReactProp(name = "rightLeg")
  public void setRightLegProp(View view, boolean rightLeg) {
    GlobalState.isRightLegEnabled = rightLeg;
  }

  @ReactProp(name = "leftAnkle")
  public void setLeftAnkleProp(View view, boolean leftAnkle) {
    GlobalState.isLeftAnkleEnabled = leftAnkle;
  }

  @ReactProp(name = "rightAnkle")
  public void setRightAnkleProp(View view, boolean rightAnkle) {
    GlobalState.isRightAnkleEnabled = rightAnkle;
  }

  @ReactProp(name = "model")
  public void setModelProp(View view, @Nullable String model) {
    if (model == null) return;
    if ("lite".equalsIgnoreCase(model)) {
      GlobalState.model = PoseLandmarkerHelper.MODEL_POSE_LANDMARKER_LITE;
    } else if ("heavy".equalsIgnoreCase(model)) {
      GlobalState.model = PoseLandmarkerHelper.MODEL_POSE_LANDMARKER_HEAVY;
    } else if ("full".equalsIgnoreCase(model)) {
      GlobalState.model = PoseLandmarkerHelper.MODEL_POSE_LANDMARKER_FULL;
    }
  }

  @ReactProp(name = "delegate")
  public void setDelegateProp(View view, @Nullable String delegate) {
    if (delegate == null) return;
    if ("GPU".equalsIgnoreCase(delegate)) {
      GlobalState.delegate = PoseLandmarkerHelper.DELEGATE_GPU;
    } else if ("CPU".equalsIgnoreCase(delegate)) {
      GlobalState.delegate = PoseLandmarkerHelper.DELEGATE_CPU;
    }
  }

  @ReactProp(name = "eventHz")
  public void setEventHzProp(View view, @Nullable Integer eventHz) {
    if (eventHz == null) return;
    GlobalState.eventHz = eventHz;
  }


  /**
   * Replace your React Native view with a custom fragment
   */
  public void createFragment(FrameLayout root, int reactNativeViewId) {
    // Ensure the native container view has a valid ID to host the Fragment
    root.setId(reactNativeViewId);
    setupLayout(root);

    final CameraFragment myFragment = new CameraFragment();
    FragmentActivity activity = (FragmentActivity) reactContext.getCurrentActivity();
    if (activity == null) {
      return;
    }
    activity.runOnUiThread(new Runnable() {
      @Override
      public void run() {
        activity.getSupportFragmentManager()
          .beginTransaction()
          .replace(reactNativeViewId, myFragment, String.valueOf(reactNativeViewId))
          .commitAllowingStateLoss();
      }
    });
  }

  public void setupLayout(View view) {
    Choreographer.getInstance().postFrameCallback(new Choreographer.FrameCallback() {
      @Override
      public void doFrame(long frameTimeNanos) {
        manuallyLayoutChildren(view);
        view.getViewTreeObserver().dispatchOnGlobalLayout();
        Choreographer.getInstance().postFrameCallback(this);
      }
    });
  }

  /**
   * Layout all children properly
   */
  public void manuallyLayoutChildren(View view) {
    // propWidth and propHeight coming from react-native props
    int width = propWidth;
    int height = propHeight;
    View parent = (View) view.getParent();
    if (parent == null) {
      return; // Ensure the parent is not null
    }
    view.measure(
      View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
    );

// Get parent's dimensions
    int parentWidth = parent.getWidth();
    int parentHeight = parent.getHeight();

    // Calculate the top-left coordinates to center the view
    int x = 0;
    int y = 0;

    view.layout(x, y, parentWidth, parentHeight);
  }
}
