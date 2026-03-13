//
//  PostDetailViewModel.swift
//  RedditOs
//
//  Created by Thomas Ricouard on 10/07/2020.
//

import Foundation
import SwiftUI
import Combine
import Backend
import os

class PostDetailViewModel: ObservableObject {
    let listing: SubredditPost
    @Published var comments: [Comment]?
    
    private var commentsCancellable: AnyCancellable?
    
    init(listing: SubredditPost) {
        self.listing = listing
    }
    
    func fetchComments() {
        AppLogger.post.info("Fetching comments for post \(self.listing.id, privacy: .public) in r/\(self.listing.subreddit, privacy: .public)")
        commentsCancellable = Comment.fetch(subreddit: listing.subreddit, id: listing.id)
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    AppLogger.post.error("Failed to fetch comments for post \(self?.listing.id ?? "", privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            })
            .map{ $0.last?.comments }
            .sink{ [weak self] comments in
                let count = comments?.count ?? 0
                AppLogger.post.debug("Received \(count) comments for post \(self?.listing.id ?? "", privacy: .public)")
                self?.comments = comments
            }
    }
}
