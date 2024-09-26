# React Native Thinksys Mediapipe

The ThinkSys Mediapipe enables pose detection for React Native apps, providing a comprehensive solution for both iOS and Android developers. It offers real-time motion tracking, seamless integration, and customizable features, ideal for fitness, healthcare, and interactive applications. By combining MediaPipe's advanced capabilities with React Native's cross-platform framework, developers can easily build immersive, motion-based apps across both mobile platforms.

<p align="center">
<img src="https://i.ibb.co/L1FNt92/thinksys-logo.png" height="100" alt="Thinksys" />
</p>

## Requirement
* Gradle minimum SDK 24 or higher
* iOS 13 or higher
* Android SDK Version 26 or higher


## Installation
```
npm install react-native-thinksys-mediapipe
```

## iOS setup
1. Add camera usage permission in Info.plist in example/ios
    ```
    <key>NSCameraUsageDescription</key>
	<string>This app uses camera to get pose landmarks that appear in the camera feed.</string>
    ```
   
2. Run ```cd ios && pod install```


## Android setup
Add these to your project's manifest.

```
<uses-feature android:name="android.hardware.camera" />
<uses-permission android:name="android.permission.CAMERA" />
```

## Usage
```js
import { RNMediapipe, switchCamera } from 'react-native-thinksys-mediapipe';


const onFlip = () => {
    switchCamera();
};

<RNMediapipe 
    width={400}
    height={300}
    onLandmark={(data: any) => {
        console.log('Body Landmark Data:', data);
    }}
    face={true}
    leftArm={true}
    rightArm={true}
    leftWrist={true}
    rightWrist={true}
    torso={true}
    leftLeg={true}
    rightLeg={true}
    leftAnkle={true}
    rightAnkle={true}
/>

<TouchableOpacity onPress={onFlip} style={styles.btnView}>
    <Text style={styles.btnTxt}>Switch Camera</Text>
</TouchableOpacity>

```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

---


## 🔗 Links
[![thinksys](https://img.shields.io/badge/my_portfolio-000?style=for-the-badge&logo=ko-fi&logoColor=white)](https://thinksys.com/)

[![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://in.linkedin.com/company/thinksys-inc)

## License

This project is licensed under a custom MIT License with restrictions - see the [LICENSE](LICENSE) file for details.
