import Foundation
import Security
import CryptoKit

final class PinnedCertificateDelegate: NSObject, URLSessionDelegate {
    private let pinnedFingerprint: String?

    init(pinnedFingerprint: String?) {
        let normalized = pinnedFingerprint.map(normalizeFingerprint)
        self.pinnedFingerprint = normalized?.isEmpty == false ? normalized : nil
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let pinnedFingerprint else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let leaf = SecTrustGetCertificateAtIndex(trust, 0)
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let certData = SecCertificateCopyData(leaf) as Data
        let digest = SHA256.hash(data: certData)
        let fingerprint = digest.map { String(format: "%02x", $0) }.joined()

        guard fingerprint == pinnedFingerprint else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

