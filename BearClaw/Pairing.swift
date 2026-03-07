import Foundation

struct TardiPairingPayload: Codable, Equatable, Sendable {
    let endpoint: String
    let bearerToken: String
    let certSHA256: String

    enum CodingKeys: String, CodingKey {
        case endpoint
        case bearerToken = "bearer_token"
        case certSHA256 = "cert_sha256"
    }
}

enum TardiPairingError: Error, Equatable {
    case invalidFormat
    case invalidJSON
    case invalidEndpoint
    case invalidToken
    case invalidFingerprint
}

func parseTardiPairingPayload(_ input: String) throws -> TardiPairingPayload {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw TardiPairingError.invalidFormat }

    let jsonData: Data
    if trimmed.hasPrefix("tardi1:") {
        let encoded = String(trimmed.dropFirst("tardi1:".count))
        guard let decoded = decodeBase64URL(encoded) else {
            throw TardiPairingError.invalidFormat
        }
        jsonData = decoded
    } else {
        guard let data = trimmed.data(using: .utf8) else {
            throw TardiPairingError.invalidFormat
        }
        jsonData = data
    }

    guard let payload = try? JSONDecoder().decode(TardiPairingPayload.self, from: jsonData) else {
        throw TardiPairingError.invalidJSON
    }

    guard let url = URL(string: payload.endpoint), url.scheme?.lowercased() == "https" else {
        throw TardiPairingError.invalidEndpoint
    }

    let token = payload.bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else { throw TardiPairingError.invalidToken }

    let normalizedFingerprint = normalizeFingerprint(payload.certSHA256)
    guard normalizedFingerprint.count == 64 else { throw TardiPairingError.invalidFingerprint }

    return TardiPairingPayload(
        endpoint: payload.endpoint,
        bearerToken: token,
        certSHA256: normalizedFingerprint
    )
}

func normalizeFingerprint(_ raw: String) -> String {
    let cleaned = raw
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: ":", with: "")
        .lowercased()

    guard cleaned.count == 64 else { return "" }
    guard cleaned.allSatisfy({ $0.isHexDigit }) else { return "" }
    return cleaned
}

private func decodeBase64URL(_ text: String) -> Data? {
    var base64 = text
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    let padding = 4 - (base64.count % 4)
    if padding < 4 {
        base64 += String(repeating: "=", count: padding)
    }
    return Data(base64Encoded: base64)
}

