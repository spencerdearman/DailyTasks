//
//  WalkDetectionManager.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import Foundation
import CoreMotion
import SwiftUI

@MainActor
@Observable
class WalkDetectionManager {
    static let shared = WalkDetectionManager()
    
    private let activityManager = CMMotionActivityManager()
    private var walkStartTime: Date?
    private var isMonitoring = false
    
    private(set) var isWalking = false
    private(set) var walkDetected = false
    
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
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        activityManager.stopActivityUpdates()
        isMonitoring = false
        isWalking = false
        walkStartTime = nil
    }
    
    func resetForNewDay() {
        walkDetected = false
        stopMonitoring()
    }
    
    func simulateWalkDetected() {
        walkDetected = true
    }
    
    func resetWalkDetected() {
        walkDetected = false
    }
}
