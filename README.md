## MPCS 51032 - Assignment 2
### Author
- **Name:** Spencer Dearman
- **UCID:** 12340675
- **UChicago Email:** dearmanspencer@uchicago.edu
- **Slack Username:** Spencer Dearman

### One (Two?) More Thing(s)
I added a Mac Menu Bar App and I created a new iOS App target. **Note:** I made sure to keep the Watch App disconnected so that it can exist as a standalone watch app. 

<img width="493" height="528" alt="mac-demo" src="https://github.com/user-attachments/assets/dbbfeb4d-a371-4d80-a86b-b0695dd8340d" />
<img width="660" height="1434" alt="ios-demo" src="https://github.com/user-attachments/assets/11ef14a7-267c-4ed5-a4e3-f8b87f6d286c" />

I also decided to do an AppIntentConfiguration instead of StaticConfiguration because I want to expand on this with more app intents and it is easier to just set it up from the beginning with AppIntentConfiguration (I had to convert a static --> intent before and it was painful).

### Known Issues
- No known build errors, but getting this running on all three devices at the same time was a bit of a nightmare. I have it working between the Watch App, Mac App, and iOS App, so let me know if you would like to see it in action.

## Resources & Attributions
- Accessory Corner: https://developer.apple.com/documentation/widgetkit/widgetfamily/accessorycorner
- Corner Complication: https://stackoverflow.com/questions/74339034/how-can-one-write-a-watchos-widget-for-accessorycorner-family-that-renders-appro
- Liquid Glass: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
- ProgressView: https://developer.apple.com/documentation/swiftui/progressview
- LinearProgressViewStyle: https://developer.apple.com/documentation/swiftui/linearprogressviewstyle
- Section Init: https://developer.apple.com/documentation/swiftui/section/init(content:header:footer:)
- Pickers: https://developer.apple.com/design/human-interface-guidelines/pickers
- DatePicker: https://developer.apple.com/documentation/SwiftUI/DatePicker
- ScenePhase: https://developer.apple.com/documentation/swiftui/scenephase
- Calendar: https://developer.apple.com/documentation/foundation/calendar/startofday(for:)
- AppStorage: https://developer.apple.com/documentation/swiftui/appstorage
- ShareLink: https://developer.apple.com/documentation/swiftui/sharelink
- UNUserNotificationCenter: https://developer.apple.com/documentation/usernotifications/unusernotificationcenter
- UNCalendarNotificationTrigger: https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger
- WidgetKit: https://developer.apple.com/documentation/widgetkit
- TimelineProvider: https://developer.apple.com/documentation/widgetkit/timelineprovider
- AppIntentConfiguration: https://developer.apple.com/documentation/widgetkit/appintentconfiguration
