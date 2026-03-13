import SwiftUI
import Combine
import Foundation
import KeychainAccess
import os


public class OauthClient: ObservableObject {
    public enum State {
        case unknown, signedOut, signinInProgress
        case authenthicated(authToken: String)
    }
    
    struct AuthTokenResponse: Decodable {
        let accessToken: String
        let tokenType: String
        let refreshToken: String?
    }
    
    static public let shared = OauthClient()
    
    @Published public var authState = State.unknown
    
    // Oauth URL
    private let baseURL = "https://www.reddit.com/api/v1/authorize"
    private let secrets: [String: AnyObject]?
    private let scopes = ["mysubreddits", "identity", "edit", "save", "vote", "subscribe", "read", "submit"]
    private let state = UUID().uuidString
    private let redirectURI = "redditos://auth"
    private let duration = "permanent"
    private let type = "code"
    
    // Keychain
    private let keychainService = "com.thomasricouard.RedditOs-reddit-token"
    private let keychainAuthTokenKey = "auth_token"
    private let keychainAuthTokenRefreshToken = "refresh_auth_token"
    
    // Request
    private var requestCancellable: AnyCancellable?
    private var refreshCancellable: AnyCancellable?
    
    private var refreshTimer: Timer?
    
    init() {
        if let path = Bundle.module.path(forResource: "secrets", ofType: "plist"),
           let secrets = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            self.secrets = secrets
        } else {
            self.secrets = nil
            AppLogger.auth.error("No secrets file found — Reddit login will not be available")
        }
        
        let keychain = Keychain(service: keychainService)
        if let token = keychain[keychainAuthTokenKey],
           let refresh = keychain[keychainAuthTokenRefreshToken] {
            AppLogger.auth.info("Existing auth token found in keychain — refreshing")
            authState = .authenthicated(authToken: token)
            DispatchQueue.main.async {
                self.refreshToken(refreshToken: refresh)
            }
        } else {
            AppLogger.auth.info("No stored auth token — user is signed out")
            authState = .signedOut
        }
        
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0 * 30, repeats: true) { _ in
            switch self.authState {
            case .authenthicated(_):
                let keychain = Keychain(service: self.keychainService)
                if let refresh = keychain[self.keychainAuthTokenRefreshToken] {
                    self.refreshToken(refreshToken: refresh)
                }
            default:
                break
            }
        }
    }
    
    public func startOauthFlow() -> URL? {
        guard let clientId = secrets?["client_id"] as? String else {
            AppLogger.auth.error("Cannot start OAuth flow — client_id missing from secrets")
            return nil
        }
        AppLogger.auth.info("Starting OAuth flow")
        authState = .signinInProgress
        
        return URL(string: baseURL)!
            .appending("client_id", value: clientId)
            .appending("response_type", value: type)
            .appending("state", value: state)
            .appending("redirect_uri", value: redirectURI)
            .appending("duration", value: duration)
            .appending("scope", value: scopes.joined(separator: " "))
    }
    
    public func handleNextURL(url: URL) {
        if url.absoluteString.hasPrefix(redirectURI),
           url.queryParameters?.first(where: { $0.value == state }) != nil,
           let code = url.queryParameters?.first(where: { $0.key == type }){
            AppLogger.auth.info("OAuth redirect received — exchanging code for token")
            authState = .signinInProgress
            requestCancellable = makeOauthPublisher(code: code.value)?
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        AppLogger.auth.error("OAuth token exchange failed: \(error.localizedDescription, privacy: .public)")
                    }
                },
                receiveValue: { response in
                    AppLogger.auth.info("OAuth token exchange succeeded — user authenticated")
                    self.authState = .authenthicated(authToken: response.accessToken)
                    let keychain = Keychain(service: self.keychainService)
                    keychain[self.keychainAuthTokenKey] = response.accessToken
                    keychain[self.keychainAuthTokenRefreshToken] = response.refreshToken
                })
        }
    }
    
    public func logout() {
        AppLogger.auth.info("User signed out")
        authState = .signedOut
        let keychain = Keychain(service: keychainService)
        keychain[keychainAuthTokenKey] = nil
        keychain[keychainAuthTokenRefreshToken] = nil
    }
    
    private func refreshToken(refreshToken: String) {
        AppLogger.auth.info("Refreshing OAuth token")
        refreshCancellable = makeRefreshOauthPublisher(refreshToken: refreshToken)?
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    AppLogger.auth.error("OAuth token refresh failed: \(error.localizedDescription, privacy: .public)")
                }
            },
            receiveValue: { response in
                AppLogger.auth.info("OAuth token refresh succeeded")
                self.authState = .authenthicated(authToken: response.accessToken)
                let keychain = Keychain(service: self.keychainService)
                keychain[self.keychainAuthTokenKey] = response.accessToken
            })
    }
    
    private func makeOauthPublisher(code: String) -> AnyPublisher<AuthTokenResponse, APIError>? {
        let params: [String: String] = ["code": code,
                                        "grant_type": "authorization_code",
                                        "redirect_uri": redirectURI]
        return API.shared.request(endpoint: .accessToken,
                                  basicAuthUser: secrets?["client_id"] as? String,
                                  httpMethod: "POST",
                                  isJSONEndpoint: false,
                                  queryParamsAsBody: true,
                                  params: params).eraseToAnyPublisher()
    }
    
    private func makeRefreshOauthPublisher(refreshToken: String) -> AnyPublisher<AuthTokenResponse, APIError>? {
        let params: [String: String] = ["grant_type": "refresh_token",
                                         "refresh_token": refreshToken]
        return API.shared.request(endpoint: .accessToken,
                                  basicAuthUser: secrets?["client_id"] as? String,
                                  httpMethod: "POST",
                                  isJSONEndpoint: false,
                                  queryParamsAsBody: true,
                                  params: params).eraseToAnyPublisher()
    }
}
