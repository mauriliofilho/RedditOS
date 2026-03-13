import Foundation
import SwiftUI
import Combine
import os

public class CurrentUser: ObservableObject {
    @Published public var user: User?
    @Published public var subscriptions: [Subreddit] = []
    
    private var disposables: [AnyCancellable?] = []
    
    private var authStateCancellable: AnyCancellable?
    
    public init() {
        authStateCancellable = OauthClient.shared.$authState.sink(receiveValue: { state in
            switch state {
            case .signedOut:
                self.user = nil
            case .authenthicated:
                self.refreshUser()
            default:
                break
            }
        })
    }
    
    private func refreshUser() {
        AppLogger.user.info("Fetching current user profile")
        let cancellable = makeUserPublisher()?
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.user.error("Failed to fetch user profile: \(error.localizedDescription, privacy: .public)")
                }
            }, receiveValue: { user in
                AppLogger.user.info("User profile loaded: \(user.name, privacy: .private)")
                self.user = user
            })
        disposables.append(cancellable)
    }
    
    private func makeUserPublisher() -> AnyPublisher<User, APIError>? {
        return API.shared.request(endpoint: .me).eraseToAnyPublisher()
    }
}
