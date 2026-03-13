//
//  File.swift
//  
//
//  Created by Thomas Ricouard on 10/07/2020.
//

import Foundation
import SwiftUI
import os

public class PersistedContent: ObservableObject {
    @Published public var subreddits: [Subreddit] = [] {
        didSet {
            save()
        }
    }
    
    private let filePath: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    struct SavedData: Codable {
        let subreddits: [Subreddit]
    }
    
    public init() {
        do {
            filePath = try FileManager.default.url(for: .documentDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: false).appendingPathComponent("redditOsData")
            load()
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    private func load() {
        if let data = try? Data(contentsOf: filePath) {
            do {
                let savedData = try decoder.decode(SavedData.self, from: data)
                self.subreddits = savedData.subreddits
                AppLogger.persistence.info("Persisted content loaded — \(savedData.subreddits.count) subreddits")
            } catch let error {
                AppLogger.persistence.error("Failed to load persisted content: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func save() {
        do {
            let savedData = SavedData(subreddits: subreddits)
            let data = try self.encoder.encode(savedData)
            try data.write(to: self.filePath, options: .atomicWrite)
            AppLogger.persistence.debug("Persisted content saved — \(savedData.subreddits.count) subreddits")
        } catch let error {
            AppLogger.persistence.error("Failed to save persisted content: \(error.localizedDescription, privacy: .public)")
        }
    }
}
