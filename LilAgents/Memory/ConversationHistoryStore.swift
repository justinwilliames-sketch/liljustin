import Foundation

/// Persists `ClaudeSession.conversations` across app launches so a
/// quit-and-reopen doesn't wipe the transcript. Stored as a single
/// JSON file at
/// `~/Library/Application Support/LilJustin/conversations.json`.
///
/// Tool-use and tool-result messages are filtered out — they're
/// transient render details that have no meaning post-launch.
/// Expert suggestion entries are dropped for the same reason
/// (LilJustin is single-persona; experts are disabled).
///
/// Caps:
///   - At most `maxConversations` keys retained (most-recently-updated
///     wins). LilJustin practically only uses the "justin" key, so this
///     is theoretical headroom.
///   - At most `maxMessagesPerConversation` messages per key, again
///     most-recent. Bounded prompt cost when the session resumes.
enum ConversationHistoryStore {

    private static let currentVersion = 1
    private static let maxConversations = 8
    private static let maxMessagesPerConversation = 60

    // MARK: - Persistence shape

    private struct PersistedDocument: Codable {
        let version: Int
        let savedAt: Date
        let conversations: [PersistedConversation]
    }

    private struct PersistedConversation: Codable {
        let key: String
        let lastReadHistoryCount: Int
        let messages: [PersistedMessage]
    }

    private struct PersistedMessage: Codable {
        let role: String   // "user" / "assistant" / "error"
        let text: String
        let speakerName: String?
        let speakerKind: String?
        let speakerTitle: String?
        let speakerAvatarPath: String?
    }

    // MARK: - Save / Load

    static func save(_ conversations: [String: ConversationState]) {
        let docs = conversations
            .compactMap { (key, state) -> PersistedConversation? in
                let messages = state.history.compactMap { msg -> PersistedMessage? in
                    let roleString: String
                    switch msg.role {
                    case .user: roleString = "user"
                    case .assistant: roleString = "assistant"
                    case .error: roleString = "error"
                    case .toolUse, .toolResult: return nil
                    }
                    let kindString = msg.speaker.map { speakerKindString(for: $0.kind) }
                    return PersistedMessage(
                        role: roleString,
                        text: msg.text,
                        speakerName: msg.speaker?.name,
                        speakerKind: kindString,
                        speakerTitle: msg.speaker?.title,
                        speakerAvatarPath: msg.speaker?.avatarPath
                    )
                }
                guard !messages.isEmpty else { return nil }
                let trimmed = Array(messages.suffix(maxMessagesPerConversation))
                return PersistedConversation(
                    key: key,
                    lastReadHistoryCount: state.lastReadHistoryCount,
                    messages: trimmed
                )
            }
            .prefix(maxConversations)

        let doc = PersistedDocument(
            version: currentVersion,
            savedAt: Date(),
            conversations: Array(docs)
        )

        guard let url = fileURL(),
              let data = try? JSONEncoder().encode(doc) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> [String: ConversationState] {
        guard let url = fileURL(),
              let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(PersistedDocument.self, from: data),
              doc.version == currentVersion else {
            return [:]
        }

        var result: [String: ConversationState] = [:]
        for conv in doc.conversations {
            var state = ConversationState()
            for pm in conv.messages {
                let role: ClaudeSession.Message.Role
                switch pm.role {
                case "user": role = .user
                case "assistant": role = .assistant
                case "error": role = .error
                default: continue
                }

                let speaker: TranscriptSpeaker?
                if let name = pm.speakerName, let kindString = pm.speakerKind {
                    let kind = speakerKind(from: kindString)
                    speaker = TranscriptSpeaker(
                        name: name,
                        title: pm.speakerTitle,
                        avatarPath: pm.speakerAvatarPath,
                        kind: kind
                    )
                } else {
                    speaker = nil
                }

                state.history.append(ClaudeSession.Message(
                    role: role,
                    text: pm.text,
                    speaker: speaker,
                    followUpExpert: nil
                ))
            }
            // Mark everything as already-read so the unread-divider
            // doesn't show the entire restored history as "new".
            state.lastReadHistoryCount = state.history.count
            result[conv.key] = state
        }
        return result
    }

    static func clear() {
        guard let url = fileURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Speaker kind round-trip

    private static func speakerKindString(for kind: TranscriptSpeaker.Kind) -> String {
        switch kind {
        case .justin: return "justin"
        case .expert: return "expert"
        case .user: return "user"
        case .system: return "system"
        }
    }

    private static func speakerKind(from raw: String) -> TranscriptSpeaker.Kind {
        switch raw {
        case "justin": return .justin
        case "expert": return .expert
        case "user": return .user
        case "system": return .system
        default: return .system
        }
    }

    // MARK: - Disk path

    private static func fileURL() -> URL? {
        let fm = FileManager.default
        guard let support = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        let dir = support.appendingPathComponent("LilJustin", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("conversations.json")
    }
}
