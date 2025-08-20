package com.tsmediapipe;

public class GlobalState {
  public static boolean isFaceEnabled = false;
  public static boolean isTorsoEnabled = false;
  public static boolean isLeftArmEnabled = false;
  public static boolean isRightArmEnabled = false;
  public static boolean isLeftWristEnabled = false;
  public static boolean isRightWristEnabled = false;
  public static boolean isLeftLegEnabled = false;
  public static boolean isRightLegEnabled = false;
  public static boolean isLeftAnkleEnabled = false;
  public static boolean isRightAnkleEnabled = false;

  public static String orientation = "portrait";

  // Performance/configuration
  public static int model = PoseLandmarkerHelper.MODEL_POSE_LANDMARKER_LITE;
  public static int delegate = PoseLandmarkerHelper.DELEGATE_GPU;
  // 0 means no throttle; otherwise events per second
  public static int eventHz = 0;
}
