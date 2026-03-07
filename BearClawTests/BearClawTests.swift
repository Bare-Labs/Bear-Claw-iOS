import Testing
import Foundation
@testable import BearClaw

@Suite(.serialized)
struct BearClawTests {
    @Test func actionResultPreservesPayload() {
        let result = AgentActionResult(action: "lock_doors", success: true, summary: "Doors locked")
        #expect(result.action == "lock_doors")
        #expect(result.success)
    }

    @Test func chatErrorResponseDecodesRequestID() throws {
        let data = Data("""
        {"code":"rate_limited","message":"Slow down","request_id":"req_123"}
        """.utf8)
        let decoded = try JSONDecoder().decode(ChatErrorResponse.self, from: data)
        #expect(decoded.code == .rateLimited)
        #expect(decoded.message == "Slow down")
        #expect(decoded.requestID == "req_123")
    }

    @Test func bearClawClientSendsChatRequestAndDecodesEnvelope() async throws {
        let expected = ChatMessage(
            id: UUID(uuidString: "E53AB489-EAA6-48E7-A644-70BC8B3D1F76")!,
            role: .assistant,
            content: "Hi from BearClaw",
            timestamp: Date(timeIntervalSince1970: 1_710_000_000)
        )
        let responseBody = try JSONEncoder().encode(ChatResponse(message: expected))

        await MockURLProtocolStore.shared.setHandler { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://example.com/v1/chat")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token-123")

            let sent = try JSONDecoder().decode(ChatRequest.self, from: try bodyData(from: request))
            #expect(sent.message == "hello")

            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseBody)
        }

        let client = BearClawClient(
            baseURL: URL(string: "https://example.com")!,
            session: makeMockSession(),
            authTokenProvider: { "token-123" }
        )

        let actual = try await client.sendMessage("hello")
        #expect(actual == expected)
    }

    @Test func bearClawClientMapsTypedAPIErrors() async throws {
        let responseBody = Data("""
        {"code":"rate_limited","message":"Try again in 60 seconds","request_id":"req_429"}
        """.utf8)

        await MockURLProtocolStore.shared.setHandler { request in
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: 429,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseBody)
        }

        let client = BearClawClient(
            baseURL: URL(string: "https://example.com")!,
            session: makeMockSession(),
            authTokenProvider: { nil }
        )

        await #expect(throws: BearClawClientError.apiError(
            code: .rateLimited,
            message: "Try again in 60 seconds",
            requestID: "req_429"
        )) {
            _ = try await client.sendMessage("hello")
        }
    }

    @Test func appSettingsStoreRequiresSecureRemoteURL() async throws {
        let suiteName = "BearClawTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let tokenStore = InMemoryTokenStore()
        let settings = AppSettingsStore(defaults: defaults, tokenStore: tokenStore)

        settings.apiBaseURL = "http://example.com"
        #expect(!settings.isConfigured)

        settings.apiBaseURL = "https://example.com"
        #expect(settings.isConfigured)

        settings.authToken = "secret"
        #expect(tokenStore.readToken() == "secret")
    }

    @Test func pairingPayloadJSONParses() throws {
        let payload = """
        {"endpoint":"https://198.51.100.10:8069","bearer_token":"abc123","cert_sha256":"AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"}
        """
        let parsed = try parseTardiPairingPayload(payload)
        #expect(parsed.endpoint == "https://198.51.100.10:8069")
        #expect(parsed.bearerToken == "abc123")
        #expect(parsed.certSHA256 == "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899")
    }

    @Test func appSettingsStoreAppliesPairingPayload() throws {
        let suiteName = "BearClawTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let tokenStore = InMemoryTokenStore()
        let settings = AppSettingsStore(defaults: defaults, tokenStore: tokenStore)
        try settings.applyPairingPayload("""
        {"endpoint":"https://203.0.113.44:8069","bearer_token":"tok-value","cert_sha256":"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
        """)

        #expect(settings.apiBaseURL == "https://203.0.113.44:8069")
        #expect(settings.authToken == "tok-value")
        #expect(settings.pinnedCertFingerprint == "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef")
        #expect(tokenStore.readToken() == "tok-value")
        #expect(settings.isConfigured)
    }
}

private func makeMockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}

private func bodyData(from request: URLRequest) throws -> Data {
    if let body = request.httpBody {
        return body
    }
    guard let stream = request.httpBodyStream else {
        throw URLError(.badURL)
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1_024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        if read < 0 {
            throw stream.streamError ?? URLError(.cannotParseResponse)
        }
        if read == 0 {
            break
        }
        data.append(buffer, count: read)
    }

    return data
}

private actor MockURLProtocolStore {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    static let shared = MockURLProtocolStore()
    private var handler: Handler?

    func setHandler(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func run(request: URLRequest) throws -> (HTTPURLResponse, Data) {
        guard let handler else {
            throw URLError(.badServerResponse)
        }
        return try handler(request)
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Task {
            do {
                let (response, data) = try await MockURLProtocolStore.shared.run(request: request)
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {}
}

private final class InMemoryTokenStore: AuthTokenStore {
    private var token: String?

    func readToken() -> String? {
        token
    }

    func writeToken(_ token: String?) {
        self.token = token
    }
}
