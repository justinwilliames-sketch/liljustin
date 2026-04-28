import Foundation

/// Memory-specific AppSettings flags.
extension AppSettings {

    static let autoExtractMemoryKey = "autoExtractMemory"
    static let conversationHistoryEnabledKey = "conversationHistoryEnabled"

    /// Run the post-turn memory extractor automatically?
    /// Default ON for new installs — the compounding-value case is the
    /// whole point of the memory layer. Sir can disable from
    /// Settings → Memory if the per-turn cost or noise becomes a bother.
    static var autoExtractMemoryEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: autoExtractMemoryKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: autoExtractMemoryKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoExtractMemoryKey)
        }
    }

    /// Persist `ClaudeSession.conversations` across launches?
    /// Default ON — most users expect a chat to remember what they
    /// said yesterday. Off = transcript wiped on every relaunch (the
    /// pre-memory-layer behaviour).
    static var conversationHistoryEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: conversationHistoryEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: conversationHistoryEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: conversationHistoryEnabledKey)
        }
    }

    /// Wipe all memory-layer state. Called by the global "Reset all
    /// data" path so users can rehearse the first-launch flow without
    /// stray remembered facts haunting the new session.
    static func clearMemoryLayerState() {
        MemoryStore.clearAll()
        ConversationHistoryStore.clear()
        UserDefaults.standard.removeObject(forKey: autoExtractMemoryKey)
        UserDefaults.standard.removeObject(forKey: conversationHistoryEnabledKey)
    }
}
