## Flux
### Author
- **Name:** Spencer Dearman
- **UCID:** 12340675
- **UChicago Email:** dearmanspencer@uchicago.edu
- **Slack Username:** Spencer Dearman

### Demo 2

https://github.com/user-attachments/assets/b448113c-fae2-4801-b591-c63c0eec9e08

## Development Summary: Architecture Refactor and UI Refinements

This document details the systemic changes made to the application architecture, the synchronization of task logic across platforms, and the implementation of native EventKit scheduling.

---

### 1. Global Architecture and Naming Refactor
The codebase underwent a systemic renaming and reorganization to remove redundancy and follow standard Apple development patterns.

* **Prefix Removal**: Removed the `Flux` prefix from all data models, views, and services (e.g., `FluxArea` became `Area`, `FluxProject` became `Project`).
* **Task Naming**: `FluxTask` was renamed to `TaskItem` to avoid naming conflicts with Swift’s built-in `Task` type.
* **File Organization**: Transitioned from massive single files (like `ContentView.swift`) to a file-per-type structure.
* **Directory Hierarchy**: Standardized folders for both **FluxMac** and **FluxApp** (iOS) into `Models`, `Views`, `Components`, `Helpers`, and `Services`.

---

### 2. Task Completion Consistency
Logic was synchronized across iOS and macOS to provide a unified user experience for completing tasks.

* **Delay-then-Disappear Pattern**: Task completion now includes a **2.5-second delay**.
* **Immediate Visual Feedback**: Upon marking a task, it immediately enters a "completed" state with dimmed opacity.
* **Undo Capability**: Users can tap the task again during the 2.5-second window to undo the completion.
* **Implementation**: `TaskCard` (iOS), `AreaDetailView` (macOS), and `ProjectDetailView` (macOS) now all utilize a unified `toggleTask()` method to handle this delay logic.

---

### 3. macOS UI and Layout Refinements
The macOS interface was updated to feel more native and reduce visual clutter.

* **Toolbar Restructuring**: Replaced the ellipsis (three-dots) menu in `ProjectDetailView` and `AreaDetailView` with direct toolbar buttons (**Open in Window**, **Rename**, **Delete**).
* **Project Title Styling**: Removed the `.ultraThinMaterial` background pill from project titles. Titles are now plain bold text to match other detail views.
* **Vertical Alignment**: Task row circles are now strictly centered vertically within their row, replacing previous conditional alignment.
* **Typography Spacing**: Reduced bottom padding on expanded task titles from **14pt to 4pt** to bring tags closer to the task name. Tag vertical padding was standardized to **8pt**.

---

### 4. Calendar and EventKit Integration
The scheduling interface was redesigned to merge deadlines and calendar events into a single, cohesive workflow.

* **Unified Schedule Popover**: Combined the deadline picker and EventKit calendar controls into one interface.
* **Simplified Logic**:
    * The calendar event time now automatically syncs with the task's deadline time.
    * If no deadline time is set, the system defaults to a suggested start time (**9:00 AM**) rather than an all-day event.
* **Disclosure UI**: Tucked advanced calendar options into a `DisclosureGroup` to avoid overwhelming the user.
* **Success Feedback**: The "Schedule on Calendar" button turns **green** once an event is successfully created.
* **UI Polish**:
    * Removed duplicate up/down stepper arrows; duration is now managed via a clean menu.
    * Fixed popover sizing to **304x420** to ensure it anchors correctly below the button.
    * Removed custom material backgrounds to allow system-standard popover borders.
* **Upcoming View**: Grouped events by day in `EventStrip`, adding clear date headers to separate chronological entries.

---

### EventKit Integration Implementation
The application leverages the **EventKit** framework to bridge local task management with system-level calendar scheduling, ensuring that deadlines and calendar events function as a single unit.

* **Unified Interaction Model**: The scheduling logic is merged directly into the deadline picker. This allows users to set a task deadline and simultaneously create a corresponding calendar event within the same popover interface in `TaskRow` and `QuickEntryView`.
* **Time Synchronization**: The calendar event start time is programmatically tied to the task's deadline. To prevent "All Day" event clutter, if a user provides a date without a specific time, the system utilizes `suggestedCalendarStartAt` logic to default the event to **9:00 AM**.
* **Lifecycle Management**: The integration supports full **CRUD** (Create, Read, Update, Delete) operations for events:
    * Creating new events upon task save.
    * Updating existing events when task times are modified.
    * Removing linked events when a task is deleted or manually de-scheduled.
* **Visual State Tracking**: The UI communicates integration status through color-coded feedback. The calendar button transitions to a **green state** upon successful event creation, providing immediate confirmation that the EventKit transaction is complete.
* **Chronological Grouping**: The `Upcoming` view utilizes `EventStrip` to aggregate these entries. It performs a grouping operation by date, inserting clear headers to organize events chronologically, which improves scannability for users with high-density schedules.

### Demo 1
https://github.com/user-attachments/assets/e34ca83f-e926-4552-ac2c-65e14b9be1ea
