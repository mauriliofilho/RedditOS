//
//  SubredditViewModel.swift
//  RedditOs
//
//  Created by Thomas Ricouard on 09/07/2020.
//

import Foundation
import SwiftUI
import Combine
import Backend
import os

class SubredditViewModel: ObservableObject {
    enum SortOrder: String, CaseIterable {
        case hot, new, top, rising
    }
    
    let name: String
    
    private var listingCancellable: AnyCancellable?
    
    @Published var listings: [SubredditPost]?
    @Published var sortOrder = SortOrder.hot {
        didSet {
            listings = nil
            fetchListings()
        }
    }
    
    init(name: String) {
        self.name = name
    }
    
    func fetchListings() {
        AppLogger.subreddit.info("Fetching listings for r/\(self.name, privacy: .public) — sort: \(self.sortOrder.rawValue, privacy: .public)")
        listingCancellable = SubredditPost.fetch(subreddit: name,
                                           sort: sortOrder.rawValue,
                                           after: listings?.last)
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.subreddit.error("Failed to fetch listings for r/\(self?.name ?? "", privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            })
            .map{ $0.data?.children.map{ $0.data }}
            .sink{ [weak self] listings in
                let count = listings?.count ?? 0
                AppLogger.subreddit.debug("Received \(count) listings for r/\(self?.name ?? "", privacy: .public)")
                if self?.listings?.last != nil, let listings = listings {
                    self?.listings?.append(contentsOf: listings)
                } else if self?.listings == nil {
                    self?.listings = listings
                }
            }
         
    }
}
