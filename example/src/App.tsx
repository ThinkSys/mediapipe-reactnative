import * as React from 'react';

import {
  StyleSheet,
  TouchableOpacity,
  Text,
  SafeAreaView,
  Dimensions,
} from 'react-native';
import { RNMediapipe, switchCamera } from '@thinksys/react-native-mediapipe';

export default function App() {
  const { width, height } = Dimensions.get('window');

  const onFlip = () => {
    switchCamera();
  };

  const handleLandmark = (data: any) => {
    console.log('Body Landmark Data:', data);
  };

  return (
    <SafeAreaView style={styles.container}>
      <RNMediapipe
        style={styles.tsMediapipeView}
        width={width}
        height={height}
        onLandmark={handleLandmark}
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
        frameLimit={25} // ios only(set the frame rate during initialization)
      />
      <TouchableOpacity onPress={onFlip} style={styles.btnView}>
        <Text style={styles.btnTxt}>Switch Camera</Text>
      </TouchableOpacity>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    backgroundColor: 'white',
    flex: 1,
  },
  btnView: {
    width: 150,
    height: 60,
    backgroundColor: 'green',
    padding: 8,
    borderRadius: 8,
    alignItems: 'center',
    alignSelf: 'center',
    justifyContent: 'center',
    position: 'absolute',
    bottom: 42,
  },
  btnTxt: { color: 'white' },
  tsMediapipeView: {
    alignSelf: 'center',
  },
});
