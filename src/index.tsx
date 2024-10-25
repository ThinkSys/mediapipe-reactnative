import React, { useEffect, useRef, type MutableRefObject } from 'react';
import {
  requireNativeComponent,
  UIManager,
  Platform,
  type ViewStyle,
  findNodeHandle,
  View,
  PixelRatio,
  NativeModules,
  NativeEventEmitter,
  type EmitterSubscription,
  Dimensions,
} from 'react-native';

const { width: deviceWidth, height: deviceHeight } = Dimensions.get('window');

const LINKING_ERROR =
  `The package '@thinksys/react-native-mediapipe' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

type TsMediapipeProps = {
  ref?: MutableRefObject<View | null>;
  onLandmark?: (event: any) => void;
  face?: boolean;
  leftArm?: boolean;
  rightArm?: boolean;
  leftWrist?: boolean;
  rightWrist?: boolean;
  torso?: boolean;
  leftLeg?: boolean;
  rightLeg?: boolean;
  leftAnkle?: boolean;
  rightAnkle?: boolean;
  height?: number;
  width?: number;
  poseStarted?: number;
};

type MediapipeComponentProps = TsMediapipeProps & {
  style?: ViewStyle;
};

const { MediaPipeNativeModule, TsMediapipeViewManager } = NativeModules;

const isAndroid = Platform.OS === 'android';

const ComponentName = isAndroid ? 'TsMediapipeViewManager' : 'TsMediapipeView';

const switchCamera = isAndroid
  ? MediaPipeNativeModule.switchCameraMethod
  : TsMediapipeViewManager.switchCamera;

const TsMediapipe =
  UIManager.getViewManagerConfig(ComponentName) != null
    ? requireNativeComponent<TsMediapipeProps>(ComponentName)
    : () => {
        throw new Error(LINKING_ERROR);
      };

const createFragment = (viewId: any) =>
  UIManager.dispatchViewManagerCommand(
    viewId,
    UIManager.TsMediapipeViewManager?.Commands?.create.toString(),
    [viewId]
  );

const TsMediapipeView: React.FC<MediapipeComponentProps> = (props) => {
  const {
    onLandmark,
    height = deviceHeight,
    width = deviceWidth,
    face = true,
    rightArm = true,
    leftArm = true,
    leftWrist = true,
    rightWrist = true,
    torso = true,
    leftLeg = true,
    rightLeg = true,
    leftAnkle = true,
    rightAnkle = true,
  } = props;

  const ref = useRef(null);

  useEffect(() => {
    const viewId = findNodeHandle(ref.current);
    if (isAndroid) {
      createFragment(viewId);
    }
  }, []);

  const bodyLandmark = (e: any) => {
    if (!isAndroid && onLandmark) {
      onLandmark(e.nativeEvent);
    }
  };

  useEffect(() => {
    let subscription: EmitterSubscription;
    if (isAndroid) {
      const mediaPipeEventEmitter = new NativeEventEmitter();
      subscription = mediaPipeEventEmitter.addListener('onLandmark', (e) => {
        onLandmark && onLandmark(e);
      });
    }

    return () => {
      subscription?.remove();
    };
  }, []);

  return (
    <View
      style={[
        props?.style,
        {
          height: height,
          width: width,
          zIndex: 0,
        },
      ]}
    >
      <TsMediapipe
        height={isAndroid ? PixelRatio.getPixelSizeForLayoutSize(height) : height}
        width={isAndroid ? PixelRatio.getPixelSizeForLayoutSize(width) : width}
        onLandmark={bodyLandmark}
        face={face}
        leftArm={leftArm}
        rightArm={rightArm}
        leftWrist={leftWrist}
        rightWrist={rightWrist}
        torso={torso}
        leftLeg={leftLeg}
        rightLeg={rightLeg}
        leftAnkle={leftAnkle}
        rightAnkle={rightAnkle}
        ref={ref}
      />
    </View>
  );
};

export { TsMediapipeView as RNMediapipe, switchCamera };
