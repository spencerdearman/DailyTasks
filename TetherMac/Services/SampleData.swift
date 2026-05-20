//
//  SampleData.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - SampleDataSeeder

/// Seeds the persistent store with starter content on first launch.
enum SampleDataSeeder {

    // MARK: Bootstrap

    /// Inserts sample areas, projects, headings, tags, and tasks if the store is empty.
    @MainActor
    static func bootstrapIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Area>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // MARK: Areas

        let work = Area(title: "Work", notes: "Professional commitments and shipping work.", symbolName: "briefcase.fill", tintHex: "#62666D", sortOrder: 0)
        let health = Area(title: "Health", notes: "Body, energy, appointments, and routines.", symbolName: "heart.fill", tintHex: "#FF383C", sortOrder: 1)
        let personal = Area(title: "Personal", notes: "Life admin and personal projects.", symbolName: "house.fill", tintHex: "#8A7D6A", sortOrder: 2)
        let finance = Area(title: "Finance", notes: "Budgeting, investments, and money management.", symbolName: "dollarsign.circle.fill", tintHex: "#34A853", sortOrder: 3)
        let learning = Area(title: "Learning", notes: "Courses, reading, and skill development.", symbolName: "book.fill", tintHex: "#9B6FD1", sortOrder: 4)
        let social = Area(title: "Social", notes: "Friends, family, and community.", symbolName: "person.2.fill", tintHex: "#46A0D5", sortOrder: 5)
        let travel = Area(title: "Travel", notes: "Trip planning, bookings, and logistics.", symbolName: "airplane", tintHex: "#6BC4C4", sortOrder: 6)

        // MARK: Projects & Headings

        let keynote = Project(
            title: "Q3 Product Launch",
            notes: """
            ## Launch Plan
            Coordinate the full product launch — marketing site, press kit, and internal training.
            """,
            goalSummary: "Ship the launch site, brief the press, and train the sales team before July 1.",
            tintHex: "#686C73",
            sortOrder: 0,
            area: work
        )
        let kDesign = Heading(title: "Design & Copy", sortOrder: 0, project: keynote)
        let kEngineering = Heading(title: "Engineering", sortOrder: 1, project: keynote)
        let kLaunch = Heading(title: "Launch Day", sortOrder: 2, project: keynote)

        let apartmentMove = Project(
            title: "Apartment Move",
            notes: "Moving to new apartment on June 15.",
            goalSummary: "Pack, coordinate movers, set up utilities, and settle in by mid-June.",
            tintHex: "#8A7D6A",
            sortOrder: 0,
            area: personal
        )
        let movePacking = Heading(title: "Packing", sortOrder: 0, project: apartmentMove)
        let moveLogistics = Heading(title: "Logistics", sortOrder: 1, project: apartmentMove)
        let moveSetup = Heading(title: "New Place Setup", sortOrder: 2, project: apartmentMove)

        let marathonTraining = Project(
            title: "Half Marathon Training",
            notes: "Training for the October half marathon. Following a 16-week plan.",
            goalSummary: "Complete the half marathon under 1:50.",
            tintHex: "#FF383C",
            sortOrder: 0,
            area: health
        )
        let mBase = Heading(title: "Base Building", sortOrder: 0, project: marathonTraining)
        let mSpeed = Heading(title: "Speed Work", sortOrder: 1, project: marathonTraining)
        let mRace = Heading(title: "Race Prep", sortOrder: 2, project: marathonTraining)

        let taxPrep = Project(
            title: "Tax Filing 2026",
            notes: "Gather documents and file by the extension deadline.",
            goalSummary: "File federal and state returns, maximize deductions.",
            tintHex: "#34A853",
            sortOrder: 0,
            area: finance
        )
        let taxDocs = Heading(title: "Documents", sortOrder: 0, project: taxPrep)
        let taxFiling = Heading(title: "Filing", sortOrder: 1, project: taxPrep)

        let appRedesign = Project(
            title: "Mobile App Redesign",
            notes: "Modernize the iOS app with new design system and improved navigation.",
            goalSummary: "Ship redesigned app to App Store by end of Q3.",
            tintHex: "#46A0D5",
            sortOrder: 1,
            area: work
        )
        let arResearch = Heading(title: "Research", sortOrder: 0, project: appRedesign)
        let arDesign = Heading(title: "Design", sortOrder: 1, project: appRedesign)
        let arImplementation = Heading(title: "Implementation", sortOrder: 2, project: appRedesign)

        let japanTrip = Project(
            title: "Japan Trip — September",
            notes: "Two weeks in Tokyo, Kyoto, and Osaka.",
            goalSummary: "Book flights, accommodations, and plan the itinerary.",
            tintHex: "#6BC4C4",
            sortOrder: 0,
            area: travel
        )
        let jpFlights = Heading(title: "Flights & Transport", sortOrder: 0, project: japanTrip)
        let jpAccom = Heading(title: "Accommodations", sortOrder: 1, project: japanTrip)
        let jpItinerary = Heading(title: "Itinerary", sortOrder: 2, project: japanTrip)

        let swiftCourse = Project(
            title: "Advanced Swift Course",
            notes: "Paul Hudson's Advanced Swift — work through all chapters.",
            goalSummary: "Complete all modules and build the capstone project.",
            tintHex: "#9B6FD1",
            sortOrder: 0,
            area: learning
        )
        let scFoundations = Heading(title: "Foundations", sortOrder: 0, project: swiftCourse)
        let scAdvanced = Heading(title: "Advanced Topics", sortOrder: 1, project: swiftCourse)

        let dinnerParty = Project(
            title: "Summer Dinner Party",
            notes: "Hosting 12 people at the new place. Italian theme.",
            goalSummary: "Plan menu, shop, cook, and host a memorable evening.",
            tintHex: "#D96BA0",
            sortOrder: 0,
            area: social
        )
        let dpPlanning = Heading(title: "Planning", sortOrder: 0, project: dinnerParty)
        let dpExecution = Heading(title: "Day-Of", sortOrder: 1, project: dinnerParty)

        // MARK: Tags

        let urgent = Tag(title: "Urgent", symbolName: "exclamationmark.triangle.fill", tintHex: "#E8574A")
        let important = Tag(title: "Important", symbolName: "exclamationmark.circle", tintHex: "#E8953A")
        let waitingOn = Tag(title: "Waiting On", symbolName: "hourglass", tintHex: "#46A0D5")
        let john = Tag(title: "John", symbolName: "person.fill", tintHex: "#8A8E95")
        let sarah = Tag(title: "Sarah", symbolName: "person.fill", tintHex: "#D96BA0")
        let errands = Tag(title: "Errand", symbolName: "car.fill", tintHex: "#72767D")
        let focus = Tag(title: "Deep Focus", symbolName: "brain.head.profile", tintHex: "#9B6FD1")
        let quick = Tag(title: "Quick Win", symbolName: "bolt.fill", tintHex: "#E5C445")
        let blocked = Tag(title: "Blocked", symbolName: "hand.raised.fill", tintHex: "#E8574A")
        let review = Tag(title: "Needs Review", symbolName: "eye.fill", tintHex: "#5BBD6B")
        let mike = Tag(title: "Mike", symbolName: "person.fill", tintHex: "#6BC4C4")

        // ─────────────────────────────────────────────
        // MARK: Tasks — Today (8 tasks = triggers "heavy day" suggestion)
        // ─────────────────────────────────────────────

        let t1 = TaskItem(
            title: "Finalize launch page hero copy",
            notes: "Keep it under 12 words. Emphasize speed and simplicity.",
            whenDate: today,
            deadline: cal.date(byAdding: .day, value: 2, to: today),
            isInInbox: false,
            project: keynote,
            heading: kDesign
        )
        let t1Focus = TaskTagAssignment(task: t1, tag: focus)

        let t2 = TaskItem(
            title: "Review Sarah's PR for onboarding flow",
            notes: "She refactored the whole sign-up wizard — check edge cases.",
            whenDate: today,
            isInInbox: false,
            project: keynote,
            heading: kEngineering
        )
        let t2Sarah = TaskTagAssignment(task: t2, tag: sarah)

        let t3 = TaskItem(
            title: "Run 5 miles — easy pace",
            notes: "Zone 2 heart rate. Recovery day after Sunday's long run.",
            whenDate: today,
            isInInbox: false,
            project: marathonTraining,
            heading: mBase
        )

        let t4 = TaskItem(
            title: "Schedule annual physical",
            notes: "Call the clinic and confirm fasting instructions.",
            whenDate: today,
            isInInbox: false,
            area: health
        )
        let t4Errands = TaskTagAssignment(task: t4, tag: errands)

        let t5 = TaskItem(
            title: "Pay credit card balance",
            notes: "Due by end of week — autopay doesn't cover the full statement.",
            whenDate: today,
            deadline: cal.date(byAdding: .day, value: 4, to: today),
            isInInbox: false,
            area: finance
        )
        let t5Important = TaskTagAssignment(task: t5, tag: important)

        let t6 = TaskItem(
            title: "Call landlord about move-out inspection",
            notes: "Confirm whether they need 30 or 60 days notice.",
            whenDate: today,
            isInInbox: false,
            isEvening: true,
            project: apartmentMove,
            heading: moveLogistics
        )

        let t6b = TaskItem(
            title: "Conduct user interviews for app redesign",
            notes: "3 scheduled calls — take notes in Notion. Focus on navigation pain points.",
            whenDate: today,
            isInInbox: false,
            project: appRedesign,
            heading: arResearch
        )
        let t6bImportant = TaskTagAssignment(task: t6b, tag: important)

        let t6c = TaskItem(
            title: "Complete Swift concurrency chapter",
            notes: "Structured concurrency, task groups, and actors.",
            whenDate: today,
            isInInbox: false,
            isEvening: true,
            project: swiftCourse,
            heading: scFoundations
        )

        // ─────────────────────────────────────────────
        // MARK: Tasks — Tomorrow
        // ─────────────────────────────────────────────

        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        let t7 = TaskItem(
            title: "Deploy staging build for QA",
            notes: "Tag v2.1-rc1 and push to TestFlight.",
            whenDate: tomorrow,
            isInInbox: false,
            project: keynote,
            heading: kEngineering
        )
        let t7Urgent = TaskTagAssignment(task: t7, tag: urgent)

        let t8 = TaskItem(
            title: "Pack kitchen — fragile items",
            notes: "Use the bubble wrap from the garage. Label boxes clearly.",
            whenDate: tomorrow,
            isInInbox: false,
            project: apartmentMove,
            heading: movePacking
        )

        let t9 = TaskItem(
            title: "Interval training — 6×800m",
            notes: "Target 3:20 per 800m with 400m recovery jogs.",
            whenDate: tomorrow,
            isInInbox: false,
            project: marathonTraining,
            heading: mSpeed
        )

        let t9b = TaskItem(
            title: "Book Tokyo → Kyoto Shinkansen tickets",
            notes: "Reserve 2 seats on Nozomi, preferably window side.",
            whenDate: tomorrow,
            isInInbox: false,
            project: japanTrip,
            heading: jpFlights
        )

        let t9c = TaskItem(
            title: "Draft wireframes for new nav bar",
            notes: "Tab bar vs sidebar — prepare both options for review.",
            whenDate: tomorrow,
            isInInbox: false,
            project: appRedesign,
            heading: arDesign
        )
        let t9cReview = TaskTagAssignment(task: t9c, tag: review)

        let t9d = TaskItem(
            title: "Finalize dinner party guest list",
            notes: "Confirm RSVPs — need final count for shopping.",
            whenDate: tomorrow,
            deadline: cal.date(byAdding: .day, value: 3, to: today),
            isInInbox: false,
            project: dinnerParty,
            heading: dpPlanning
        )

        // ─────────────────────────────────────────────
        // MARK: Tasks — Upcoming (this week and next)
        // ─────────────────────────────────────────────

        let t10 = TaskItem(
            title: "Write press release draft",
            notes: "First draft for the product launch. Get John's review.",
            whenDate: cal.date(byAdding: .day, value: 3, to: today),
            deadline: cal.date(byAdding: .day, value: 5, to: today),
            isInInbox: false,
            project: keynote,
            heading: kLaunch
        )
        let t10John = TaskTagAssignment(task: t10, tag: john)

        let t11 = TaskItem(
            title: "Set up internet at new apartment",
            notes: "Xfinity appointment confirmed — need to be there 9am–12pm.",
            whenDate: cal.date(byAdding: .day, value: 4, to: today),
            isInInbox: false,
            locationName: "456 Oak Avenue, Apt 3B",
            locationLatitude: 37.7849,
            locationLongitude: -122.4094,
            project: apartmentMove,
            heading: moveSetup
        )

        let t12 = TaskItem(
            title: "Long run — 10 miles",
            notes: "Steady pace, bring gels. Route: waterfront trail.",
            whenDate: cal.date(byAdding: .day, value: 5, to: today),
            isInInbox: false,
            project: marathonTraining,
            heading: mBase
        )

        let t13 = TaskItem(
            title: "Gather W-2s and 1099s",
            notes: "Check email for digital copies. Download from employer portal.",
            whenDate: cal.date(byAdding: .day, value: 3, to: today),
            deadline: cal.date(byAdding: .day, value: 10, to: today),
            isInInbox: false,
            project: taxPrep,
            heading: taxDocs
        )
        let t13Important = TaskTagAssignment(task: t13, tag: important)

        let t14 = TaskItem(
            title: "Order new desk for home office",
            notes: "The standing desk from Autonomous — Oak top, programmable height.",
            whenDate: cal.date(byAdding: .day, value: 6, to: today),
            isInInbox: false,
            isEvening: true,
            project: apartmentMove,
            heading: moveSetup
        )

        let t14b = TaskItem(
            title: "Research Kyoto ryokans",
            notes: "Budget $150/night. Prefer traditional tatami rooms with onsen.",
            whenDate: cal.date(byAdding: .day, value: 3, to: today),
            isInInbox: false,
            project: japanTrip,
            heading: jpAccom
        )

        let t14c = TaskItem(
            title: "Build prototype of new tab bar",
            notes: "Use SwiftUI — animate the transitions between tabs.",
            whenDate: cal.date(byAdding: .day, value: 4, to: today),
            isInInbox: false,
            project: appRedesign,
            heading: arImplementation
        )
        let t14cFocus = TaskTagAssignment(task: t14c, tag: focus)

        let t14d = TaskItem(
            title: "Plan Fushimi Inari + Arashiyama day trip",
            notes: "Start early at Fushimi Inari, bamboo grove in the afternoon.",
            whenDate: cal.date(byAdding: .day, value: 5, to: today),
            isInInbox: false,
            project: japanTrip,
            heading: jpItinerary
        )

        let t14e = TaskItem(
            title: "Create dinner party menu",
            notes: "Antipasto, homemade pasta, tiramisu. Check for dietary restrictions.",
            whenDate: cal.date(byAdding: .day, value: 4, to: today),
            isInInbox: false,
            project: dinnerParty,
            heading: dpPlanning
        )

        let t14f = TaskItem(
            title: "Team standup presentation — redesign progress",
            notes: "5 min max. Show wireframes and user interview highlights.",
            whenDate: cal.date(byAdding: .day, value: 5, to: today),
            isInInbox: false,
            project: appRedesign,
            heading: arResearch
        )
        let t14fMike = TaskTagAssignment(task: t14f, tag: mike)

        let t14g = TaskItem(
            title: "Schedule dentist appointment",
            notes: "Overdue for a cleaning. Try Dr. Park's office.",
            whenDate: cal.date(byAdding: .day, value: 6, to: today),
            isInInbox: false,
            area: health
        )
        let t14gErrands = TaskTagAssignment(task: t14g, tag: errands)

        let t14h = TaskItem(
            title: "Review investment portfolio allocation",
            notes: "Rebalance if stocks > 70%. Check bond ladder maturity dates.",
            whenDate: cal.date(byAdding: .day, value: 7, to: today),
            isInInbox: false,
            area: finance
        )

        let t14i = TaskItem(
            title: "Pack bedroom — clothes and linens",
            notes: "Seasonal clothes in vacuum bags. Label by room.",
            whenDate: cal.date(byAdding: .day, value: 7, to: today),
            isInInbox: false,
            project: apartmentMove,
            heading: movePacking
        )

        let t14j = TaskItem(
            title: "Tempo run — 6 miles at marathon pace",
            notes: "Target 7:30/mi. Stay consistent, don't go out too fast.",
            whenDate: cal.date(byAdding: .day, value: 8, to: today),
            isInInbox: false,
            project: marathonTraining,
            heading: mSpeed
        )

        let t14k = TaskItem(
            title: "Book flights to Tokyo (NRT)",
            notes: "Check ANA direct SFO→NRT. Use points if available.",
            whenDate: cal.date(byAdding: .day, value: 3, to: today),
            deadline: cal.date(byAdding: .day, value: 7, to: today),
            isInInbox: false,
            project: japanTrip,
            heading: jpFlights
        )
        let t14kUrgent = TaskTagAssignment(task: t14k, tag: urgent)

        let t14l = TaskItem(
            title: "Practice Swift macros chapter",
            notes: "Build a custom @Observable-like macro from scratch.",
            whenDate: cal.date(byAdding: .day, value: 8, to: today),
            isInInbox: false,
            project: swiftCourse,
            heading: scAdvanced
        )

        let t14m = TaskItem(
            title: "Send birthday card to Aunt Linda",
            notes: "Her birthday is the 28th. Get card from Papyrus.",
            whenDate: cal.date(byAdding: .day, value: 6, to: today),
            isInInbox: false,
            area: social
        )
        let t14mQuick = TaskTagAssignment(task: t14m, tag: quick)

        let t14n = TaskItem(
            title: "File estimated quarterly tax payment",
            notes: "Q2 payment due. Calculate from last quarter's income.",
            whenDate: cal.date(byAdding: .day, value: 9, to: today),
            deadline: cal.date(byAdding: .day, value: 12, to: today),
            isInInbox: false,
            project: taxPrep,
            heading: taxFiling
        )

        // ─────────────────────────────────────────────
        // MARK: Tasks — Overdue (triggers agent suggestion)
        // ─────────────────────────────────────────────

        let t15 = TaskItem(
            title: "Send updated wireframes to design team",
            notes: "The revised navigation flow with the simplified sidebar.",
            whenDate: cal.date(byAdding: .day, value: -3, to: today),
            isInInbox: false,
            project: keynote,
            heading: kDesign
        )
        let t15Urgent = TaskTagAssignment(task: t15, tag: urgent)
        let t15WaitingOn = TaskTagAssignment(task: t15, tag: waitingOn)

        let t16 = TaskItem(
            title: "Refill running shoe prescription",
            notes: "Need new Brooks Ghost 16 — check if insurance covers orthotics.",
            whenDate: cal.date(byAdding: .day, value: -2, to: today),
            isInInbox: false,
            area: health
        )
        let t16Errands = TaskTagAssignment(task: t16, tag: errands)

        let t17 = TaskItem(
            title: "Reply to accountant about deductions",
            notes: "She asked about home office square footage and equipment receipts.",
            whenDate: cal.date(byAdding: .day, value: -1, to: today),
            isInInbox: false,
            project: taxPrep,
            heading: taxDocs
        )

        let t17b = TaskItem(
            title: "Respond to Mike's design feedback",
            notes: "He flagged issues with the color contrast on dark mode.",
            whenDate: cal.date(byAdding: .day, value: -2, to: today),
            isInInbox: false,
            project: appRedesign,
            heading: arDesign
        )
        let t17bMike = TaskTagAssignment(task: t17b, tag: mike)
        let t17bBlocked = TaskTagAssignment(task: t17b, tag: blocked)

        let t17c = TaskItem(
            title: "RSVP for networking event",
            notes: "Tech meetup downtown — free food, good speakers.",
            whenDate: cal.date(byAdding: .day, value: -4, to: today),
            isInInbox: false,
            area: social
        )

        // ─────────────────────────────────────────────
        // MARK: Tasks — Inbox (triggers categorization suggestion)
        // ─────────────────────────────────────────────

        let t18 = TaskItem(
            title: "Look into meal prep services",
            notes: "Factor or Trifecta — compare pricing for 10 meals/week.",
            status: .active,
            isInInbox: true
        )

        let t19 = TaskItem(
            title: "Renew gym membership",
            notes: "Check if annual pricing is better than month-to-month.",
            status: .active,
            isInInbox: true
        )

        let t20 = TaskItem(
            title: "Buy birthday gift for Mom",
            notes: "She mentioned wanting a Kindle Paperwhite.",
            deadline: cal.date(byAdding: .day, value: 12, to: today),
            status: .active,
            isInInbox: true
        )
        let t20Quick = TaskTagAssignment(task: t20, tag: quick)

        let t21 = TaskItem(
            title: "Fix leaky kitchen faucet",
            notes: "Probably just needs a new washer. YouTube the model number.",
            status: .active,
            isInInbox: true
        )

        let t21b = TaskItem(
            title: "Research noise-canceling headphones",
            notes: "Sony WH-1000XM5 vs AirPods Max 2. Check Wirecutter.",
            status: .active,
            isInInbox: true
        )

        let t21c = TaskItem(
            title: "Update LinkedIn profile",
            notes: "Add recent project work and update headline.",
            status: .active,
            isInInbox: true
        )

        let t21d = TaskItem(
            title: "Cancel unused Hulu subscription",
            notes: "Haven't watched anything in months.",
            status: .active,
            isInInbox: true
        )
        let t21dQuick = TaskTagAssignment(task: t21d, tag: quick)

        let t21e = TaskItem(
            title: "Get car oil change",
            notes: "Past 5000 miles since last one. Jiffy Lube or dealership.",
            status: .active,
            isInInbox: true
        )
        let t21eErrands = TaskTagAssignment(task: t21e, tag: errands)

        // ─────────────────────────────────────────────
        // MARK: Tasks — Someday / Later
        // ─────────────────────────────────────────────

        let t22 = TaskItem(
            title: "Learn SwiftUI Charts framework",
            notes: "Build a sample dashboard to visualize running data.",
            status: .someday,
            isInInbox: false,
            area: learning
        )

        let t23 = TaskItem(
            title: "Research Japanese study plan",
            notes: "Maybe start with a light reading + listening routine.",
            status: .someday,
            isInInbox: false,
            area: learning
        )

        let t24 = TaskItem(
            title: "Plan weekend trip to Tahoe",
            notes: "Check cabin availability for August. Budget ~$600.",
            status: .someday,
            isInInbox: false,
            area: travel
        )

        let t25 = TaskItem(
            title: "Set up automated investing with Wealthfront",
            notes: "Monthly contribution of $500 into risk-score 8 portfolio.",
            status: .someday,
            isInInbox: false,
            area: finance
        )

        let t26 = TaskItem(
            title: "Read 'Designing Data-Intensive Applications'",
            notes: "Been on the shelf for months. Start with the replication chapter.",
            status: .someday,
            isInInbox: false,
            area: learning
        )

        let t26b = TaskItem(
            title: "Build a personal website",
            notes: "Simple portfolio with blog. Maybe use Astro or Next.js.",
            status: .someday,
            isInInbox: false,
            area: learning
        )

        let t26c = TaskItem(
            title: "Try indoor rock climbing",
            notes: "Mission Cliffs has beginner sessions on Saturdays.",
            status: .someday,
            isInInbox: false,
            area: health
        )

        let t26d = TaskItem(
            title: "Organize photo library",
            notes: "10,000+ photos unsorted. Set up smart albums by year/trip.",
            status: .someday,
            isInInbox: false,
            area: personal
        )

        let t26e = TaskItem(
            title: "Learn to cook Thai food",
            notes: "Start with pad thai and green curry. Buy a wok.",
            status: .someday,
            isInInbox: false,
            area: personal
        )

        let t26f = TaskItem(
            title: "Write a technical blog post",
            notes: "Topic: building a task manager with SwiftUI + SwiftData.",
            status: .someday,
            isInInbox: false,
            area: work
        )

        let t26g = TaskItem(
            title: "Volunteer at local food bank",
            notes: "SF-Marin Food Bank has Saturday morning shifts.",
            status: .someday,
            isInInbox: false,
            area: social
        )

        let t26h = TaskItem(
            title: "Set up home NAS for backups",
            notes: "Synology DS224+ with 2x 4TB drives in RAID 1.",
            status: .someday,
            isInInbox: false,
            area: personal
        )

        // ─────────────────────────────────────────────
        // MARK: Tasks — Completed (recent history)
        // ─────────────────────────────────────────────

        let c1 = TaskItem(
            title: "Share final deck with John",
            notes: "Send the PDF after QA and ask for one last pass.",
            whenDate: cal.date(byAdding: .day, value: -1, to: today),
            status: .completed,
            isInInbox: false,
            project: keynote,
            heading: kDesign
        )
        c1.completedAt = cal.date(byAdding: .day, value: -1, to: today)
        let c1John = TaskTagAssignment(task: c1, tag: john)

        let c2 = TaskItem(
            title: "Set up CI/CD pipeline for launch site",
            notes: "GitHub Actions → Vercel preview deploys on every PR.",
            whenDate: cal.date(byAdding: .day, value: -2, to: today),
            status: .completed,
            isInInbox: false,
            project: keynote,
            heading: kEngineering
        )
        c2.completedAt = cal.date(byAdding: .day, value: -2, to: today)

        let c3 = TaskItem(
            title: "Book movers for June 15",
            notes: "Confirmed with Two Men and a Truck — 8am arrival.",
            whenDate: cal.date(byAdding: .day, value: -3, to: today),
            status: .completed,
            isInInbox: false,
            project: apartmentMove,
            heading: moveLogistics
        )
        c3.completedAt = cal.date(byAdding: .day, value: -2, to: today)

        let c4 = TaskItem(
            title: "Buy race entry — Bay to Breakers",
            notes: "Registered for the October race. Confirmation #BK-4821.",
            whenDate: cal.date(byAdding: .day, value: -5, to: today),
            status: .completed,
            isInInbox: false,
            project: marathonTraining,
            heading: mRace
        )
        c4.completedAt = cal.date(byAdding: .day, value: -4, to: today)

        let c5 = TaskItem(
            title: "Submit expense report for conference",
            notes: "All receipts uploaded to Concur.",
            whenDate: cal.date(byAdding: .day, value: -4, to: today),
            status: .completed,
            isInInbox: false,
            area: work
        )
        c5.completedAt = cal.date(byAdding: .day, value: -3, to: today)

        let c6 = TaskItem(
            title: "Complete competitor analysis for redesign",
            notes: "Analyzed 5 competitor apps. Key findings in Notion doc.",
            whenDate: cal.date(byAdding: .day, value: -3, to: today),
            status: .completed,
            isInInbox: false,
            project: appRedesign,
            heading: arResearch
        )
        c6.completedAt = cal.date(byAdding: .day, value: -2, to: today)

        let c7 = TaskItem(
            title: "Renew passport",
            notes: "Expedited processing — should arrive in 2 weeks.",
            whenDate: cal.date(byAdding: .day, value: -6, to: today),
            status: .completed,
            isInInbox: false,
            area: travel
        )
        c7.completedAt = cal.date(byAdding: .day, value: -5, to: today)

        let c8 = TaskItem(
            title: "Set up emergency fund account",
            notes: "Opened high-yield savings at Marcus. $5K initial deposit.",
            whenDate: cal.date(byAdding: .day, value: -7, to: today),
            status: .completed,
            isInInbox: false,
            area: finance
        )
        c8.completedAt = cal.date(byAdding: .day, value: -6, to: today)

        let c9 = TaskItem(
            title: "Complete Swift generics chapter",
            notes: "Protocol-oriented programming patterns. Good exercises.",
            whenDate: cal.date(byAdding: .day, value: -4, to: today),
            status: .completed,
            isInInbox: false,
            project: swiftCourse,
            heading: scFoundations
        )
        c9.completedAt = cal.date(byAdding: .day, value: -3, to: today)

        let c10 = TaskItem(
            title: "Clean out garage",
            notes: "Donated 3 boxes to Goodwill. Kept the tools organized.",
            whenDate: cal.date(byAdding: .day, value: -5, to: today),
            status: .completed,
            isInInbox: false,
            area: personal
        )
        c10.completedAt = cal.date(byAdding: .day, value: -4, to: today)

        let c11 = TaskItem(
            title: "Run 8 miles — hilly route",
            notes: "Golden Gate Park loop. Felt strong on the climbs.",
            whenDate: cal.date(byAdding: .day, value: -2, to: today),
            status: .completed,
            isInInbox: false,
            project: marathonTraining,
            heading: mBase
        )
        c11.completedAt = cal.date(byAdding: .day, value: -2, to: today)

        let c12 = TaskItem(
            title: "Write thank-you notes from dinner",
            notes: "Sent cards to the 4 couples who brought wine.",
            whenDate: cal.date(byAdding: .day, value: -8, to: today),
            status: .completed,
            isInInbox: false,
            area: social
        )
        c12.completedAt = cal.date(byAdding: .day, value: -7, to: today)

        let c13 = TaskItem(
            title: "Fix broken unit tests in auth module",
            notes: "Token refresh mock was stale. Updated to match new API.",
            whenDate: cal.date(byAdding: .day, value: -1, to: today),
            status: .completed,
            isInInbox: false,
            project: appRedesign,
            heading: arImplementation
        )
        c13.completedAt = cal.date(byAdding: .day, value: -1, to: today)

        // MARK: Checklist Items

        let cl1 = ChecklistItem(title: "Write headline variations (3 options)", sortOrder: 0, task: t1)
        let cl2 = ChecklistItem(title: "Get sign-off from marketing lead", isCompleted: false, sortOrder: 1, task: t1)
        let cl3 = ChecklistItem(title: "Update Figma mockup with final copy", isCompleted: false, sortOrder: 2, task: t1)
        t1.checklist = [cl1, cl2, cl3]

        let cl4 = ChecklistItem(title: "Check edge case: empty state", isCompleted: true, sortOrder: 0, task: t2)
        let cl5 = ChecklistItem(title: "Check edge case: 50+ items", sortOrder: 1, task: t2)
        let cl6 = ChecklistItem(title: "Leave review comments", sortOrder: 2, task: t2)
        t2.checklist = [cl4, cl5, cl6]

        let cl7 = ChecklistItem(title: "Kitchen dishes and glassware", sortOrder: 0, task: t8)
        let cl8 = ChecklistItem(title: "Coffee maker and small appliances", sortOrder: 1, task: t8)
        let cl9 = ChecklistItem(title: "Spice rack", isCompleted: true, sortOrder: 2, task: t8)
        t8.checklist = [cl7, cl8, cl9]

        let cl10 = ChecklistItem(title: "Download W-2 from employer portal", sortOrder: 0, task: t13)
        let cl11 = ChecklistItem(title: "Collect 1099-INT from bank", sortOrder: 1, task: t13)
        let cl12 = ChecklistItem(title: "Find charitable donation receipts", sortOrder: 2, task: t13)
        let cl13 = ChecklistItem(title: "Export crypto transaction history", sortOrder: 3, task: t13)
        t13.checklist = [cl10, cl11, cl12, cl13]

        let cl14 = ChecklistItem(title: "Check Japan Rail Pass pricing", isCompleted: true, sortOrder: 0, task: t9b)
        let cl15 = ChecklistItem(title: "Compare reserved vs unreserved seats", sortOrder: 1, task: t9b)
        let cl16 = ChecklistItem(title: "Book on SmartEX app", sortOrder: 2, task: t9b)
        t9b.checklist = [cl14, cl15, cl16]

        let cl17 = ChecklistItem(title: "Appetizer: bruschetta trio", isCompleted: true, sortOrder: 0, task: t14e)
        let cl18 = ChecklistItem(title: "Main: fresh pappardelle with ragu", sortOrder: 1, task: t14e)
        let cl19 = ChecklistItem(title: "Dessert: tiramisu (make day before)", sortOrder: 2, task: t14e)
        let cl20 = ChecklistItem(title: "Wine pairing: Chianti + Prosecco", sortOrder: 3, task: t14e)
        let cl21 = ChecklistItem(title: "Check for vegetarian/allergy needs", sortOrder: 4, task: t14e)
        t14e.checklist = [cl17, cl18, cl19, cl20, cl21]

        let cl22 = ChecklistItem(title: "Compare SFO vs OAK departure options", sortOrder: 0, task: t14k)
        let cl23 = ChecklistItem(title: "Check credit card points balance", sortOrder: 1, task: t14k)
        let cl24 = ChecklistItem(title: "Book return flight NRT→SFO", sortOrder: 2, task: t14k)
        t14k.checklist = [cl22, cl23, cl24]

        // MARK: Persist

        let allAreas = [work, health, personal, finance, learning, social, travel]
        let allProjects = [keynote, apartmentMove, marathonTraining, taxPrep, appRedesign, japanTrip, swiftCourse, dinnerParty]
        let allHeadings = [
            kDesign, kEngineering, kLaunch,
            movePacking, moveLogistics, moveSetup,
            mBase, mSpeed, mRace,
            taxDocs, taxFiling,
            arResearch, arDesign, arImplementation,
            jpFlights, jpAccom, jpItinerary,
            scFoundations, scAdvanced,
            dpPlanning, dpExecution
        ]
        let allTags = [urgent, important, waitingOn, john, sarah, errands, focus, quick, blocked, review, mike]
        let allTagAssignments: [TaskTagAssignment] = [
            t1Focus, t2Sarah, t4Errands, t5Important, t6bImportant,
            t7Urgent, t9cReview, t10John, t13Important, t14cFocus,
            t14fMike, t14gErrands, t14kUrgent, t14mQuick,
            t15Urgent, t15WaitingOn, t16Errands,
            t17bMike, t17bBlocked,
            t20Quick, t21dQuick, t21eErrands,
            c1John
        ]
        let allTasks: [TaskItem] = [
            // today
            t1, t2, t3, t4, t5, t6, t6b, t6c,
            // tomorrow
            t7, t8, t9, t9b, t9c, t9d,
            // upcoming
            t10, t11, t12, t13, t14, t14b, t14c, t14d, t14e, t14f, t14g, t14h, t14i, t14j, t14k, t14l, t14m, t14n,
            // overdue
            t15, t16, t17, t17b, t17c,
            // inbox
            t18, t19, t20, t21, t21b, t21c, t21d, t21e,
            // someday
            t22, t23, t24, t25, t26, t26b, t26c, t26d, t26e, t26f, t26g, t26h,
            // completed
            c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13
        ]

        for area in allAreas { context.insert(area) }
        for project in allProjects { context.insert(project) }
        for heading in allHeadings { context.insert(heading) }
        for tag in allTags { context.insert(tag) }
        for assignment in allTagAssignments { context.insert(assignment) }
        for task in allTasks { context.insert(task) }

        try? context.save()
    }
}
