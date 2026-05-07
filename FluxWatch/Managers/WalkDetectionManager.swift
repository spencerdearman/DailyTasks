//
//  WalkDetectionManager.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import CoreMotion
import Foundation
import SwiftUI

// MARK: - WalkDetectionManager

/// Monitors CoreMotion activity updates to detect sustained walking periods.
@MainActor
@Observable
class WalkDetectionManager {

    // MARK: - Properties

    static let shared = WalkDetectionManager()

    private let activityManager = CMMotionActivityManager()
    private var walkStartTime: Date?
    private var isMonitoring = false

    private(set) var isWalking = false
    private(set) var walkDetected = false

    // MARK: - Public Methods

    /// Begins listening for walking activity via CoreMotion.
    func startMonitoring() {
        guard !isMonitoring else { return }
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("CoreMotion Activity not available (likely running in Simulator)")
            return
        }

        isMonitoring = true
        walkStartTime = nil

        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            guard activity.confidence == .medium || activity.confidence == .high else { return }

            if activity.walking {
                self.isWalking = true
                if self.walkStartTime == nil {
                    self.walkStartTime = Date()
                } else if let startTime = self.walkStartTime, Date().timeIntervalSince(startTime) >= 30 {
                    self.walkDetected = true
                    self.stopMonitoring()
                }
            } else {
                self.isWalking = false
                self.walkStartTime = nil
            }
        }
    }

    /// Stops listening for walking activity.
    func stopMonitoring() {
        guard isMonitoring else { return }
        activityManager.stopActivityUpdates()
        isMonitoring = false
        isWalking = false
        walkStartTime = nil
    }

    /// Resets walk detection state for a new day.
    func resetForNewDay() {
        walkDetected = false
        stopMonitoring()
    }

    /// Simulates a walk detection event for debug purposes.
    func simulateWalkDetected() {
        walkDetected = true
    }

    /// Clears the walk detected flag.
    func resetWalkDetected() {
        walkDetected = false
    }
}
