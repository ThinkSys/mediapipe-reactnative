package com.tsmediapipe;

import android.util.Log;
import android.view.Choreographer;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.FragmentActivity;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;

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
  private Choreographer.FrameCallback frameCallback;
  private CameraFragment currentFragment;

  ReactApplicationContext reactContext;

  public TsMediapipeViewManager(ReactApplicationContext reactContext) {
    this.reactContext = reactContext;
  }

  @Override
  public String getName() {
    return REACT_CLASS;
  }

  private OverlayView overlayView;

  
  private void createFragmentAuto(FrameLayout root) {
    Log.d("TsMediapipe", "Auto-creating fragment - START");

    final FragmentActivity activity = (FragmentActivity) reactContext.getCurrentActivity();
    if (activity == null) {
      Log.e("TsMediapipe", "Activity is null, cannot create fragment");
      return;
    }

    // Clean up existing fragment if any
    cleanupFragment();

    try {
      Log.d("TsMediapipe", "Creating new CameraFragment instance");
      currentFragment = new CameraFragment();
      final FragmentManager fragmentManager = activity.getSupportFragmentManager();

      int containerId = root.getId();
      if (containerId == View.NO_ID) {
        containerId = View.generateViewId();
        root.setId(containerId);
        Log.d("TsMediapipe", "Generated new container ID: " + containerId);
      } else {
        Log.d("TsMediapipe", "Using existing container ID: " + containerId);
      }

      final int finalContainerId = containerId; // Make final for lambda
      final CameraFragment finalFragment = currentFragment; // Make final for lambda


      if (root.getParent() == null) {
        Log.w("TsMediapipe", "Container has no parent - this might cause issues");
      }

      activity.runOnUiThread(new Runnable() {
        @Override
        public void run() {
          try {
            Log.d("TsMediapipe", "Starting fragment transaction");

            fragmentManager
                    .beginTransaction()
                    .replace(finalContainerId, finalFragment, "camera_fragment_" + finalContainerId)
                    .commitAllowingStateLoss();

            Log.d("TsMediapipe", "Fragment transaction committed");

            boolean executed = fragmentManager.executePendingTransactions();
            Log.d("TsMediapipe", "Pending transactions executed: " + executed);

            Fragment addedFragment = fragmentManager.findFragmentByTag("camera_fragment_" + finalContainerId);
            if (addedFragment != null) {
              Log.d("TsMediapipe", "Fragment successfully added to manager");
            } else {
              Log.e("TsMediapipe", "Fragment not found in manager after transaction!");
            }

          } catch (Exception e) {
            Log.e("TsMediapipe", "Error in fragment transaction: " + e.getMessage(), e);
          }
        }
      });

    } catch (Exception e) {
      Log.e("TsMediapipe", "Error auto-creating fragment: " + e.getMessage(), e);
    }
  }

  /**
   * Return a FrameLayout which will later hold the Fragment
   */
  @Override
  public FrameLayout createViewInstance(ThemedReactContext reactContext) {
    Log.d("TsMediapipe", "createViewInstance");
    FrameLayout frameLayout = new FrameLayout(reactContext);
    frameLayout.setId(View.generateViewId());


    return frameLayout;
  }


  private void createCameraViewDirectly(FrameLayout container, ThemedReactContext context) {
    try {
      Log.d("TsMediapipe", "Camera view created directly");
    } catch (Exception e) {
      Log.e("TsMediapipe", "Error creating camera view directly: " + e.getMessage(), e);
    }
  }

  
  @Override
  public void onAfterUpdateTransaction(@NonNull FrameLayout view) {
    super.onAfterUpdateTransaction(view);
    setupLayout(view);

    if (currentFragment == null && propWidth > 0 && propHeight > 0) {
      view.post(new Runnable() {
        @Override
        public void run() {
          if (view.getParent() != null) {
            createFragmentAuto(view);
          } else {
            Log.w("TsMediapipe", "View not yet attached to parent, retrying...");
            view.postDelayed(new Runnable() {
              @Override
              public void run() {
                createFragmentAuto(view);
              }
            }, 100);
          }
        }
      });
    }
  }


  @Override
  public void onDropViewInstance(@NonNull FrameLayout view) {
    Log.d("TsMediapipe", "onDropViewInstance");
    if (frameCallback != null) {
      Choreographer.getInstance().removeFrameCallback(frameCallback);
      frameCallback = null;
    }

    cleanupFragment();
    super.onDropViewInstance(view);
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

    if (args == null || args.size() == 0) {
      Log.e("TsMediapipe", "receiveCommand: args is null or empty");
      return;
    }

    int reactNativeViewId = args.getInt(0);
    int commandIdInt = Integer.parseInt(commandId);

    switch (commandIdInt) {
      case COMMAND_CREATE:
        createFragment(root, reactNativeViewId);
        break;
      default:
        Log.w("TsMediapipe", "Received unknown command: " + commandIdInt);
    }
  }

  @ReactProp(name = "width")
  public void setWidthProp(FrameLayout view, Integer width) {
    if (width != null && width > 0) {
      propWidth = width;
      Log.d("TsMediapipe", "Width set to: " + width);
    }
  }

  @ReactProp(name = "height")
  public void setHeightProp(FrameLayout view, Integer height) {
    if (height != null && height > 0) {
      propHeight = height;
      Log.d("TsMediapipe", "Height set to: " + height);
    }
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

  /**
   * Replace your React Native view with a custom fragment
   */
  public void createFragment(FrameLayout root, int reactNativeViewId) {
    Log.d("TsMediapipe", "createFragment called with viewId: " + reactNativeViewId);

    final FragmentActivity activity = (FragmentActivity) reactContext.getCurrentActivity();
    if (activity == null) {
      Log.e("TsMediapipe", "Activity is null, cannot create fragment");
      return;
    }

    // Clean up existing fragment if any
    cleanupFragment();

    try {
      currentFragment = new CameraFragment();
      final FragmentManager fragmentManager = activity.getSupportFragmentManager();

      // Use the FrameLayout's ID instead of reactNativeViewId
      int containerId = root.getId();
      if (containerId == View.NO_ID) {
        containerId = View.generateViewId();
        root.setId(containerId);
      }

      final int finalContainerId = containerId;
      final CameraFragment finalFragment = currentFragment;

      Log.d("TsMediapipe", "Adding fragment to container: " + containerId);

      fragmentManager
              .beginTransaction()
              .replace(finalContainerId, finalFragment, "camera_fragment_" + finalContainerId)
              .commitNowAllowingStateLoss(); // Use commitNow to ensure immediate execution

      Log.d("TsMediapipe", "Fragment transaction completed");

    } catch (Exception e) {
      Log.e("TsMediapipe", "Error creating fragment: " + e.getMessage(), e);
    }
  }

  private void cleanupFragment() {
    if (currentFragment != null) {
      final FragmentActivity activity = (FragmentActivity) reactContext.getCurrentActivity();
      if (activity != null) {
        try {
          final FragmentManager fragmentManager = activity.getSupportFragmentManager();
          final Fragment existingFragment = fragmentManager.findFragmentByTag("camera_fragment_" + currentFragment.getId());
          if (existingFragment != null) {
            fragmentManager.beginTransaction()
                    .remove(existingFragment)
                    .commitNowAllowingStateLoss();
          }
        } catch (Exception e) {
          Log.e("TsMediapipe", "Error cleaning up fragment: " + e.getMessage());
        }
      }
      currentFragment = null;
    }
  }

  public void setupLayout(View view) {
    if (frameCallback != null) {
      Choreographer.getInstance().removeFrameCallback(frameCallback);
    }

    frameCallback = new Choreographer.FrameCallback() {
      @Override
      public void doFrame(long frameTimeNanos) {
        try {
          manuallyLayoutChildren(view);
          view.getViewTreeObserver().dispatchOnGlobalLayout();
          Choreographer.getInstance().postFrameCallback(this);
        } catch (Exception e) {
          Log.e("TsMediapipe", "Error in frame callback: " + e.getMessage());
        }
      }
    };

    Choreographer.getInstance().postFrameCallback(frameCallback);
  }

  /**
   * Layout all children properly
   */
  public void manuallyLayoutChildren(View view) {
    try {
      // Use default dimensions if props are not set
      int width = propWidth > 0 ? propWidth : ViewGroup.LayoutParams.MATCH_PARENT;
      int height = propHeight > 0 ? propHeight : ViewGroup.LayoutParams.MATCH_PARENT;

      View parent = (View) view.getParent();
      if (parent == null) {
        return; // Ensure the parent is not null
      }

      // Only measure if the view needs it
      if (view.isLayoutRequested()) {
        view.measure(
                View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)
        );
      }

      // Get parent's dimensions
      int parentWidth = parent.getWidth();
      int parentHeight = parent.getHeight();

      // Only layout if parent has valid dimensions
      if (parentWidth > 0 && parentHeight > 0) {
        view.layout(0, 0, parentWidth, parentHeight);
      }

    } catch (Exception e) {
      Log.e("TsMediapipe", "Error in manuallyLayoutChildren: " + e.getMessage());
    }
  }
}