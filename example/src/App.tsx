import * as React from 'react';

import {
  StyleSheet,
  TouchableOpacity,
  Text,
  SafeAreaView,
  Dimensions,
} from 'react-native';
import {
  TsMediapipeView,
  switchCamera,
} from 'react-native-thinksys-mediapipe';

export default function App() {
  const onFlip = () => {
    switchCamera();
  };

  const handleLandmark = (data: any) => {
    console.log('Body Landmark Data:', data);
  };

  return (
    <SafeAreaView
      style={{
        backgroundColor: 'white',
        flex: 1,
      }}
    >
        <TsMediapipeView
          style={styles.tsMediapipeView}
          width={Dimensions.get('window').width}
          height={300}
          onLandmark={handleLandmark}
          face={true}
          leftArm={true}
          rightArm={true}
          leftWrist={false}
          rightWrist={false}
          torso={true}
          leftLeg={false}
          rightLeg={false}
          leftAnkle={false}
          rightAnkle={false}
        />
      <TouchableOpacity onPress={onFlip} style={styles.btnView}>
        <Text style={{ color: 'white' }}>Switch Camera</Text>
      </TouchableOpacity>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  btnView: {
    width: 100,
    height: 60,
    backgroundColor: 'green',
    padding: 8,
    borderRadius: 8,
    alignItems: 'center',
    alignSelf: 'center',
    justifyContent: 'center',
  },
  tsMediapipeView: {
    alignSelf: 'center',
  },
});
