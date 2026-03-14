//
//  SearchSubredditsViewModel.swift
//  RedditOs
//
//  Created by Thomas Ricouard on 09/07/2020.
//

import Foundation
import SwiftUI
import Combine
import Backend
import os

class SearchSubredditsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var results: [Subreddit]?
    @Published var isLoading = false
    
    private var searchCancellable: AnyCancellable?
    private var apiPublisher: AnyPublisher<SubredditResponse, Never>?
    private var apiCancellable: AnyCancellable?
    
    init() {
        searchCancellable = $searchText
            .subscribe(on: DispatchQueue.global())
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .filter { !$0.isEmpty }
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] text in
                self?.isLoading = true
                self?.search(with: text)
            })
    }
    
    private func search(with text: String) {
        AppLogger.search.info("Searching subreddits for query: \(text, privacy: .public)")
        apiCancellable?.cancel()
        let param = ["query": text]
        apiPublisher = API.shared.request(endpoint: .searchSubreddit, httpMethod: "POST", params: param)
            .subscribe(on: DispatchQueue.global())
            .handleEvents(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.search.error("Subreddit search failed for query '\(text, privacy: .public)': \(error.localizedDescription, privacy: .public)")
                }
            })
            .replaceError(with: SubredditResponse())
            .eraseToAnyPublisher()
        apiCancellable = apiPublisher?
            .receive(on: DispatchQueue.main)
            .map{ $0.subreddits }
            .sink{ [weak self] results in
                let count = results.count ?? 0
                AppLogger.search.debug("Search returned \(count) results for query: \(text, privacy: .public)")
                self?.isLoading = false
                self?.results = results
            }
        
    }
}
