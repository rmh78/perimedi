# Launch screen

Cold start uses `UILaunchScreen` in `PeriMedi/Resources/Info.plist` (`GENERATE_INFOPLIST_FILE = NO`): a peach `#ffe4d6` page (`LaunchPeach`, same in Dark). No launch image — a missing or slow image read as white (cream) or black. `UIUserInterfaceStyle` is Light. Accent rose `#d43d6c` is not the page chrome.

`UILaunchStoryboardName` = `LaunchScreen` is the same peach page with the word **PeriMedi** centered (Palatino-Bold, blush `#94274b`). iOS prefers `UILaunchScreen` when that key is present, so the system frame is peach; the wordmark is the first SwiftUI overlay. The storyboard is a resource in `generate_pbxproj.py`.

After first paint, that overlay fades out in about half a second. `-uiTesting` and `-remindIn=` skip it so XCTest is not delayed. Reduce Motion skips the fade.
