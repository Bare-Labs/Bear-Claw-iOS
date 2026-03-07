import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var draft = ""
    @Published var messages: [ChatMessage] = []
    @Published var errorText: String?

    private let clientProvider: () -> BearClawClientProtocol

    init(clientProvider: @escaping () -> BearClawClientProtocol) {
        self.clientProvider = clientProvider
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        draft = ""
        messages.append(.init(role: .user, content: text))

        do {
            let response = try await clientProvider().sendMessage(text)
            messages.append(response)
            errorText = nil
        } catch {
            errorText = userFacingError(error)
        }
    }

    private func userFacingError(_ error: Error) -> String {
        if let clientError = error as? BearClawClientError {
            switch clientError {
            case .unauthorized:
                return "Unauthorized. Update your bearer token in Settings."
            case let .apiError(code, message, _):
                switch code {
                case .upstreamTimeout:
                    return "Gateway timed out. Try again."
                case .rateLimited:
                    return "Rate limited. Wait a moment and retry."
                default:
                    return "Request failed: \(message)"
                }
            case .serverError:
                return "Gateway error. Try again shortly."
            case .invalidResponse:
                return "Gateway returned an invalid response."
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection."
            case .timedOut:
                return "Network timeout. Try again."
            default:
                return "Network request failed."
            }
        }

        return "Message failed. Check gateway URL and token in Settings."
    }
}

extension ChatViewModel {
    static var preview: ChatViewModel {
        ChatViewModel(clientProvider: { PreviewClient() })
    }
}

struct PreviewClient: BearClawClientProtocol {
    func sendMessage(_ text: String) async throws -> ChatMessage {
        ChatMessage(role: .assistant, content: "Received: \(text)")
    }
}
