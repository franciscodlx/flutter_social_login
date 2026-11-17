import AuthenticationServices
import Flutter
import UIKit

/// Runs the sign-in with ASWebAuthenticationSession and reports the redirect
/// back to Dart.
public class SocialAuthCoreIosPlugin: NSObject, FlutterPlugin, AuthSessionApi {
  private var session: ASWebAuthenticationSession?
  private let anchorProvider = PresentationAnchorProvider()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SocialAuthCoreIosPlugin()
    AuthSessionApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
  }

  func isAvailable() throws -> Bool {
    true
  }

  func open(url: String, callbackUrl: String, prefersEphemeralSession: Bool) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      self.start(url: url, callbackUrl: callbackUrl, prefersEphemeralSession: prefersEphemeralSession) {
        continuation.resume(with: $0)
      }
    }
  }

  /// Calls `completion` exactly once, with the redirect URL or a `PigeonError`.
  private func start(
    url: String,
    callbackUrl: String,
    prefersEphemeralSession: Bool,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let fail = { (code: String, message: String) in
      completion(.failure(PigeonError(code: code, message: message, details: nil)))
    }

    // The Dart layer already restricts plain http to loopback hosts.
    guard let authURL = URL(string: url), ["https", "http"].contains(authURL.scheme ?? ""),
          let redirect = URLComponents(string: callbackUrl),
          let scheme = redirect.scheme?.lowercased(), !scheme.isEmpty
    else {
      fail("INVALID_CONFIG", "The authorization URL must be http(s) and the callback URL absolute")
      return
    }

    DispatchQueue.main.async {
      if self.session != nil {
        fail("INVALID_CONFIG", "Another sign-in is already in progress")
        return
      }

      let handler: ASWebAuthenticationSession.CompletionHandler = { callbackURL, error in
        // Clearing the session also breaks the session → handler → self cycle.
        self.session = nil
        if let callbackURL {
          completion(.success(callbackURL.absoluteString))
          return
        }
        let nsError = error as NSError?
        if nsError?.domain == ASWebAuthenticationSessionErrorDomain,
           nsError?.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
          fail("CANCELLED", "The user closed the browser")
        } else if nsError?.domain == ASWebAuthenticationSessionErrorDomain {
          fail("NOT_SUPPORTED", nsError?.localizedDescription ?? "The sign-in could not be presented")
        } else {
          fail("PROVIDER_ERROR", nsError?.localizedDescription ?? "The sign-in failed")
        }
      }

      let session: ASWebAuthenticationSession
      if scheme == "https" {
        // Universal Link redirect: only ASWebAuthenticationSession can
        // intercept it, starting with iOS 17.4.
        guard #available(iOS 17.4, *), let host = redirect.host else {
          fail("NOT_SUPPORTED", "https callback URLs need iOS 17.4 or later; use a custom scheme")
          return
        }
        session = ASWebAuthenticationSession(
          url: authURL,
          callback: .https(host: host, path: redirect.path.isEmpty ? "/" : redirect.path),
          completionHandler: handler
        )
      } else {
        session = ASWebAuthenticationSession(
          url: authURL,
          callbackURLScheme: scheme,
          completionHandler: handler
        )
      }

      session.presentationContextProvider = self.anchorProvider
      session.prefersEphemeralWebBrowserSession = prefersEphemeralSession
      self.session = session
      if !session.start() {
        self.session = nil
        fail("NOT_SUPPORTED", "The sign-in could not be presented")
      }
    }
  }

  func cancel() throws {
    DispatchQueue.main.async {
      // The completion handler runs with `canceledLogin` and fails the call.
      self.session?.cancel()
    }
  }
}

private final class PresentationAnchorProvider: NSObject,
  ASWebAuthenticationPresentationContextProviding {
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let active = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    if let window = active?.windows.first(where: { $0.isKeyWindow }) ?? active?.windows.first {
      return window
    }
    if let active {
      return ASPresentationAnchor(windowScene: active)
    }
    return ASPresentationAnchor()
  }
}
