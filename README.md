# Tether
### Author
- **Name:** Spencer Dearman
- **UCID:** 12340675
- **UChicago Email:** dearmanspencer@uchicago.edu
- **Slack Username:** Spencer Dearman

### Demo 3 (5/13)
https://github.com/user-attachments/assets/22efdb34-9511-499f-8751-c80c3bc29ede

## Tether — Version Summary: Detailed Changelog

---

## 1. Gemini AI Integration (Core AI Engine)

### **GeminiService** (`TetherMac/Services/GeminiService.swift`)

* **Engine:** Powered by Google Gemini 2.5 Flash.
* **Structured Output:** Implements `response_schema` to return strongly-typed `GeminiActionResponse` objects.
* **Action Vocabulary:** Supports 14 specific actions: `create_task`, `complete_task`, `move_task`, `schedule_task`, `defer_task`, `list_tasks`, `decompose_task`, `plan_day`, `reschedule_overdue`, `create_event`, `delete_event`, `propose_reschedule`, `query`, and `chat`.
* **Context Management:** Maintains a 10-message conversation history with automatic pruning.
* **Reliability:** Includes a retry loop with exponential backoff for 503 and 429 errors.
* **Prompt Construction:** `GeminiPromptBuilder` injects full user context, including areas, projects, tasks, calendar events, location, and weather data.

### **CategorizationService** (`TetherMac/Services/CategorizationService.swift`)

* **Function:** Secondary classifier for auto-categorizing new tasks into Areas and Projects.
* **Configuration:** Uses a low temperature (0.1) for deterministic classification.
* **Fallback:** Gracefully handles missing API keys.

### **SynthesisService** (`TetherMac/Services/SynthesisService.swift`)

* **Function:** Generates time-of-day adaptive "Daily Briefing" reports.
* **Output:** Returns structured JSON containing greetings, scheduling conflicts, and a time-blocked `suggested_plan`.
* **Context:** Incorporates weather, overdue tasks, and calendar previews.

### **SemanticRouter** (`TetherMac/Services/SemanticRouter.swift`)

* **Logic:** On-device NLP using Apple’s `NaturalLanguage` framework and `NLEmbedding`.
* **Functionality:**
* Infers Area via keyword matching and cosine distance (threshold < 0.92).
* Detects urgency signals (`asap`, `urgent`) for auto-scheduling.
* Identifies "someday" signals and evening context (`tonight`, `after work`).



---

## 2. The Tether Agent (Task Agent System)

### **TaskAgent** (`TetherMac/Services/TaskAgent.swift`)

* **Scale:** Approximately 1,220 lines of core orchestration logic.
* **Execution Engine:** Handlers for all 14 action types, including:
* **Task Management:** Creation with auto-categorization, fuzzy-match mutations, and decomposition of goals into 3–7 subtasks.
* **Planning:** `plan_day` builds structured schedules incorporating tasks and calendar events.
* **Calendar Operations:** Direct manipulation with confirmation dialogs and conflict detection (`propose_reschedule`).


* **Multi-Command Support:** Processes multiple commands in a single message via follow-up loops (up to 4 iterations).
* **Date Parsing:** Robust handling of ISO 8601, natural language ("next friday"), ordinals ("11th"), and relative dates.
* **Response Model:** `AgentResponse` returns messages, affected IDs, UI cards, and deletion confirmations.

---

## 3. Agent Window & UI (Mac)

### **AgentOverlay** (`TetherMac/Views/Agent/AgentOverlay.swift`)

* **Interface:** Spotlight-style floating overlay (⌘A).
* **Features:**
* Glass-effect search bar with animated processing indicators.
* **Conversation Scrubber:** Pip-based navigation for the 3 most recent conversations; history prunes after 48 hours.
* **Rendering:** Inline markdown, grouped event timelines, and interactive task chips.
* **Animations:** Custom `RevealView` top-to-bottom gradient mask.



### **Specialized UI Components**

* **DailyPlanCard:** Displays weather (WeatherKit), color-coded time blocks (Focus, Errands, Flex), and grouped task sections.
* **ScheduleProposalCard:** Highlights conflicts with an orange badge and suggests 2–4 alternative slots with reasoning.

---

## 4. Agent on iOS

### **AgentSheet** (`TetherApp/Views/Agent/AgentSheet.swift`)

* Adapted sheet-based interface for mobile, supporting conversation history and synthesis.

### **CommandPaletteOverlay** (`TetherApp/Views/Agent/CommandPaletteOverlay.swift`)

* Unified glass overlay combining search (Find) and AI chat in a tabbed interface.

---

## 5. Google Calendar Syncing

### **GoogleCalendarService** (`TetherMac/Services/GoogleCalendarService.swift`)

* **Integration:** Google Calendar REST API v3 and Google Sign-In SDK.
* **OAuth:** Implements `calendar.readonly` scope with session restoration on launch.
* **Sync Logic:** Fetches from all user calendars; handles both `dateTime` and `date` (all-day) formats with ISO 8601 fallbacks.

### **CalendarStore** (`TetherMac/Services/CalendarService.swift`)

* **Unified Source:** Merges EventKit (Apple) and Google Calendar data.
* **Maintenance:** 30-second auto-refresh timer and deduplication based on title and timestamp.

### **EventKitSyncService** (`TetherMac/Services/EventKitSyncService.swift`)

* Manages Apple EventKit CRUD operations and Reminder imports.
* Uses `SemanticRouter` for intelligent area assignment during reminder ingestion.

---

## 6. Daily Synthesis & Briefing System

### **DailySynthesis Model** (`TetherMac/Models/DailySynthesis.swift`)

* SwiftData model persisting briefings, conflicts, plan data, and dismissal states.

### **SynthesisView** (`TetherMac/Views/Overlays/SynthesisView.swift`)

* Overlay featuring period-aware greetings, weather icons, and collapsible "Heads Up" and "Overdue" sections.

### **BackgroundScheduler** (`TetherMac/Services/BackgroundScheduler.swift`)

* Uses `NSBackgroundActivityScheduler` for overnight jobs:
* **Overnight Synthesis:** Generates next-day briefing (00:00–06:00).
* **Overnight Reschedule:** Automatically moves overdue tasks to "Today."



---

## 7. Location & Weather Services

### **LocationService** (`TetherMac/Services/LocationService.swift`)

* CoreLocation-based coordinates and city name retrieval.
* Supports forward/reverse geocoding via `MKLocalSearch`.

### **TetherWeatherService** (`TetherMac/Services/WeatherService.swift`)

* Fetches conditions, high/low temperatures, and precipitation via Apple WeatherKit.
* Implements a 30-minute cache to optimize API usage.

---

## 8. UI Refinements

* **Aesthetics:** Extensive use of `.glassEffect` across sidebars and overlays.
* **Shortcuts:** ⌘F (Quick Find), ⌘A (Agent), ⌘1–6 (Navigation).
* **Interactions:**
* Drag-and-drop task reassignment in the sidebar.
* Delayed completion (2.5s window) allowing for undo-by-re-tap.


* **Search:** Quick Find overlay searches tasks, projects, areas, and calendar events simultaneously.

---

## 9. Data Model Additions

### **AgentConversation** (`TetherMac/Models/AgentConversation.swift`)

* SwiftData model for persisting chat history with JSON-serialized message metadata.

### **TaskItem Enhancements**

* **Location:** Added `locationName`, `latitude`, and `longitude`.
* **Calendar:** Added `calendarEventID`, `calendarStartAt`, and `calendarDurationMinutes`.
* **Metadata:** Added `reminderItemID` (sync), `isEvening` (flagging), and `recurrenceRule`.

---

## 10. Cross-Platform Architecture

* **TetherMac:** Full macOS implementation with native background scheduling and window management.
* **TetherApp:** iOS companion with touch-optimized UI and sheet-based navigation.
* **Shared Logic:** Core models and services (Gemini, TaskAgent, Categorization) are shared across targets to ensure logic parity.

### Demo 2 (5/6)
https://github.com/user-attachments/assets/b448113c-fae2-4801-b591-c63c0eec9e08

### Demo 1 (4/29)
https://github.com/user-attachments/assets/e34ca83f-e926-4552-ac2c-65e14b9be1ea
