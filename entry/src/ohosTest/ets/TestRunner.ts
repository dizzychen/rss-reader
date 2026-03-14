import { describe } from '@ohos/hypium';
import RssServiceTest from './tests/RssServiceTest';
import RssUtilsTest from './tests/RssUtilsTest';
import ConstantsTest from './tests/ConstantsTest';
import ModelsTest from './tests/ModelsTest';
import FeedRefreshServiceTest from './tests/FeedRefreshServiceTest';
import DatabaseHelperTest from './tests/DatabaseHelperTest';

export default function testsuite() {
  describe('AllTests', () => {
    RssServiceTest();
    RssUtilsTest();
    ConstantsTest();
    ModelsTest();
    FeedRefreshServiceTest();
    DatabaseHelperTest();
  });
}
