# Tether
### Author
- **Name:** Spencer Dearman
- **UCID:** 12340675
- **UChicago Email:** dearmanspencer@uchicago.edu
- **Slack Username:** Spencer Dearman

## Tether Final Change Summary

### Agent Intelligence & Automation

* **Proactive Suggestions:** Implemented `AgentSuggestionService` (iOS & macOS) to analyze task state locally and generate contextual suggestions (e.g., categorize inbox, reschedule overdue, plan the day). Suggestions are cached for two hours across tab switches.
* **Inline UI Integration:** Deployed inline suggestion and result cards directly at the top of the task list (`TaskListScreen` on iOS, `TaskCollectionView` on macOS), allowing users to execute agent actions without opening the dedicated overlay.
* **Bulk Categorization:** Introduced `categorizeBulk()` within the `CategorizationService` to classify multiple inbox tasks in a single Gemini API call. `TaskAgent.categorizeInbox()` applies these results directly to the data model, bypassing the conversational interface. Prompting now includes full area descriptions for improved accuracy.
* **Query Resolution:** Fixed agent date querying. The agent now attempts to parse filters as dates before falling back to standard text or project searches.

### Natural Language Smart Entry

* **Smart Parsing System:** Integrated `SmartEntryField` (iOS) and updated `QuickEntryView` (macOS) to support natural language input. The system locally parses dates, times, evening flags, areas, and projects in real-time.
* **Live Preview:** Displays a parsed text preview below the input field and automatically populates the corresponding form values.
* **Categorization Fallback:** Falls back to the Gemini-powered `CategorizationService` if no area or project is matched locally.

### UI/UX Redesign & Animations

* **Live Task Materialization:** `AgentActivityService` now tracks `affectedTaskIDs`. When the agent modifies or creates a task, the corresponding UI elements visually respond with a blue/purple gradient border, shimmer sweeps, and accent bars across both platforms.
* **macOS Agent Panel Redesign:** Replaced the centered floating panel with a right-side sliding panel. Updated visual styling includes an 18pt corner radius, 9pt padding, a translucent glass background, and a hover-to-reveal conversation history list.
* **iOS Keyboard & Layout Fixes:** Resolved keyboard occlusion in the iOS Agent Sheet by removing `ignoresSafeArea` and pinning the input bar to the bottom safe area. Removed obsolete suggestion chips and the search overlay.
* **Standardized Agent Identity:** Established a unified agent color palette (indigo to sky blue). Replaced old empty states with a centered "Tether Agent" title featuring a seamless sine-wave animated gradient.
* **Detail View Updates (macOS):** Removed toolbar buttons in `ProjectDetailView` and `AreaDetailView`. Actions were moved to context menus on the title text. Added `AreaEditSheet` and `ProjectEditSheet` to support modal editing of names, notes, colors, and icons.
* **Task Editor Fixes:** Corrected deadline label wrapping by isolating the date picker in a vertical stack below the label.

### Data & Architecture

* **Sample Data Expansion:** Scaled sample data from roughly 130 lines to 900 lines per platform. The database now seeds 7 areas, 8+ projects, and 72 tasks distributed across various states (inbox, overdue, today, completed). Added a "Reset & Load Sample Data" trigger in Settings.
* **Model Configuration:** Updated the LLM integration to specifically target `gemini-2.5-flash` and refined system instructions.
* **Xcode Configuration:** Renamed the macOS build product from `TetherMac.app` to `Tether.app` and updated the `Info.plist` exceptions.

### Demo 3 (5/13)
https://github.com/user-attachments/assets/22efdb34-9511-499f-8751-c80c3bc29ede

### Demo 2 (5/6)
https://github.com/user-attachments/assets/b448113c-fae2-4801-b591-c63c0eec9e08

### Demo 1 (4/29)
https://github.com/user-attachments/assets/e34ca83f-e926-4552-ac2c-65e14b9be1ea
