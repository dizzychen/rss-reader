import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AbilityDelegatorRegistry } from '@kit.TestKit';
import { Hypium } from '@ohos/hypium';
import testsuite from './TestRunner';

export default class TestAbility extends UIAbility {
  onCreate() {
    console.info('TestAbility onCreate');
    const abilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();
    const abilityDelegatorArguments = AbilityDelegatorRegistry.getArguments();
    console.info('start run testcase!!!');
    Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite);
  }

  onDestroy() {
    console.info('TestAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    console.info('TestAbility onWindowStageCreate');
    windowStage.loadContent('testability/pages/Index', (err) => {
      if (err.code) {
        console.error('TestAbility onWindowStageCreate loadContent failed');
        return;
      }
      console.info('TestAbility onWindowStageCreate loadContent succeeded');
    });
  }

  onWindowStageDestroy() {
    console.info('TestAbility onWindowStageDestroy');
  }

  onForeground() {
    console.info('TestAbility onForeground');
  }

  onBackground() {
    console.info('TestAbility onBackground');
  }
}
