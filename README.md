# React Native Mediapipe

The ThinkSys Mediapipe enables pose detection for React Native apps, providing a comprehensive solution for both iOS and Android developers. It offers real-time motion tracking, seamless integration, and customizable features, ideal for fitness, healthcare, and interactive applications. By combining MediaPipe's advanced capabilities with React Native's cross-platform framework, developers can easily build immersive, motion-based apps across both mobile platforms.

<p align="center">
<img src="https://i.ibb.co/L1FNt92/thinksys-logo.png" height="100" alt="ThinkSys" />
</p>

## Requirement
* iOS 13 or higher
* Gradle minimum SDK 24 or higher
* Android SDK Version 26 or higher


## Installation
```
npm install @thinksys/react-native-mediapipe
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

## Props

| Prop        | Description                                                                                     |
|-------------|-------------------------------------------------------------------------------------------------|
| `width`     | Sets the camera view width.                                                                      |
| `height`    | Sets the camera view height.                                                                     |
| `onLandmark`| Callback function to retrieve body landmark data.                                                |
| `face`      | Toggles visibility of the face in the body model. Affects the data provided by `onLandmark`.      |
| `leftArm`   | Toggles visibility of the left arm in the body model. Affects the data provided by `onLandmark`.  |
| `rightArm`  | Toggles visibility of the right arm in the body model. Affects the data provided by `onLandmark`. |
| `leftWrist` | Toggles visibility of the left wrist in the body model. Affects the data provided by `onLandmark`.|
| `rightWrist`| Toggles visibility of the right wrist in the body model. Affects the data provided by `onLandmark`.|
| `torso`     | Toggles visibility of the torso in the body model. Affects the data provided by `onLandmark`.     |
| `leftLeg`   | Toggles visibility of the left leg in the body model. Affects the data provided by `onLandmark`.  |
| `rightLeg`  | Toggles visibility of the right leg in the body model. Affects the data provided by `onLandmark`. |
| `leftAnkle` | Toggles visibility of the left ankle in the body model. Affects the data provided by `onLandmark`.|
| `rightAnkle`| Toggles visibility of the right ankle in the body model. Affects the data provided by `onLandmark`.|


## Usage

### Basic

```js
import { RNMediapipe } from '@thinksys/react-native-mediapipe';

export default function App() {

    return (
        <View>
            <RNMediapipe 
                width={400}
                height={300}
            />
        </View>
    )
}
```

### Usage with body prop

#### Used to show/hide any body part overlay
#### By default, the body prop is set to true

```js
import { RNMediapipe } from '@thinksys/react-native-mediapipe';

export default function App() {

    return (
        <View>
            <RNMediapipe 
                width={400}
                height={300}
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
        </View>
    )
}
```

### Usage with switch camera method

```js
import { RNMediapipe, switchCamera } from '@thinksys/react-native-mediapipe';

export default function App() {

    const onFlip = () => {
        switchCamera();
    };

    return (
        <View>
            <RNMediapipe 
                width={400}
                height={300}
            />

            <TouchableOpacity onPress={onFlip} style={styles.btnView}>
                <Text style={styles.btnTxt}>Switch Camera</Text>
            </TouchableOpacity>
        </View>
    )
}

```

### Usage with onLandmark prop

```js
import { RNMediapipe } from '@thinksys/react-native-mediapipe';

export default function App() {

    return (
        <View>
            <RNMediapipe 
                width={400}
                height={300}
                onLandmark={(data) => {
                    console.log('Body Landmark Data:', data);
                }}
            />
        </View>
    )
}

```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

---

## 🔗 Links
[![thinksys](https://img.shields.io/badge/my_portfolio-000?style=for-the-badge&logo=ko-fi&logoColor=white)](https://thinksys.com/)

[![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://in.linkedin.com/company/thinksys-inc)

## License

This project is licensed under a custom MIT License with restrictions - see the [LICENSE](LICENSE) file for details.
