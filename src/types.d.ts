import { UIManager } from 'react-native';

declare module 'react-native' {
  interface UIManagerStatic {
    TsMediapipeViewManager: {
      Commands: {
        create: number;
      };
      create: (reactTag: number) => void;
    };
  }
}
