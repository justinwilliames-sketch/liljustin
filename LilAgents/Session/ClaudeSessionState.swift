import Foundation

extension ClaudeSession {
    var history: [Message] { history(for: focusedExpert) }

    func history(for expert: ResponderExpert?) -> [Message] {
        conversations[key(for: expert)]?.history ?? []
    }

    func key(for expert: ResponderExpert?) -> String {
        if let expert {
            return "expert:\(normalize(expert.name))"
        }
        return "lenny"
    }

    func appendHistory(_ message: Message, to key: String) {
        var state = conversations[key] ?? ConversationState()
        state.history.append(message)
        conversations[key] = state
    }

    func lastReadHistoryCount(for expert: ResponderExpert?) -> Int {
        conversations[key(for: expert)]?.lastReadHistoryCount ?? 0
    }

    func markConversationRead(for expert: ResponderExpert?) {
        let conversationKey = key(for: expert)
        var state = conversations[conversationKey] ?? ConversationState()
        let historyCount = state.history.count
        guard historyCount > state.lastReadHistoryCount else { return }
        state.lastReadHistoryCount = historyCount
        conversations[conversationKey] = state
    }

    func expertSuggestionEntries(for expert: ResponderExpert?) -> [ExpertSuggestionEntry] {
        conversations[key(for: expert)]?.expertSuggestionEntries ?? []
    }

    func appendExpertSuggestionEntry(_ experts: [ResponderExpert], for expert: ResponderExpert?) {
        guard !experts.isEmpty else { return }

        let conversationKey = key(for: expert)
        var state = conversations[conversationKey] ?? ConversationState()

        if let lastEntry = state.expertSuggestionEntries.last,
           lastEntry.anchorHistoryCount == state.history.count,
           lastEntry.experts.map(\.name) == experts.map(\.name) {
            conversations[conversationKey] = state
            return
        }

        state.expertSuggestionEntries.append(ExpertSuggestionEntry(
            anchorHistoryCount: state.history.count,
            experts: experts
        ))
        conversations[conversationKey] = state
    }

    func collapseExpertSuggestionEntry(_ entryID: UUID, pickedExpert: ResponderExpert, for expert: ResponderExpert?) {
        let conversationKey = key(for: expert)
        guard var state = conversations[conversationKey],
              let index = state.expertSuggestionEntries.firstIndex(where: { $0.id == entryID }) else { return }

        state.expertSuggestionEntries[index].pickedExpert = pickedExpert
        state.expertSuggestionEntries[index].isCollapsed = true
        conversations[conversationKey] = state
    }

    func expandExpertSuggestionEntry(_ entryID: UUID, for expert: ResponderExpert?) {
        let conversationKey = key(for: expert)
        guard var state = conversations[conversationKey],
              let index = state.expertSuggestionEntries.firstIndex(where: { $0.id == entryID }) else { return }

        state.expertSuggestionEntries[index].isCollapsed = false
        conversations[conversationKey] = state
    }

    func finishTurn() {
        isBusy = false
        onTurnComplete?()
    }

    func failTurn(_ text: String) {
        failTurn(text, conversationKey: key(for: focusedExpert))
    }

    func failTurn(_ text: String, conversationKey: String) {
        isBusy = false
        pendingExperts.removeAll()
        assistantExplicitlyRequestedExperts = false
        appendHistory(Message(role: .error, text: text), to: conversationKey)
        onError?(text)
        onTurnComplete?()
    }

    func buildInstructions(for expert: ResponderExpert?, expectMCP: Bool) -> String {
        // The `expert` and `expectMCP` parameters are retained for signature
        // compatibility with the upstream Lenny codebase but are intentionally
        // ignored — LilJustin is a single-persona companion with no archive RAG.
        _ = expert
        _ = expectMCP

        return """
        You are Mini Justin (also called LilJustin) — a tiny pixel-art companion that lives on the user's macOS dock. You speak as Justin Williames, in first person.

        WHO YOU ARE
        - Based on the Sunshine Coast, Queensland, Australia. Has lived and worked in London and Melbourne.
        - 10+ years in CRM and lifecycle marketing. Built CRM functions at high-growth consumer companies — marketplaces, fashion, fintech, transport, telco. Currently at Sophiie AI, working on AI workflow systems for trades businesses.
        - Deep working knowledge of: CRM architecture (Braze, HubSpot, Liquid templating), lifecycle strategy (activation, retention, win-back, segmentation), marketing automation, AI agents and workflows, revenue operations, fractional/consulting engagements, and the SMB/trades vertical.
        - Braze Marketer certified. Liquid Dynamic Personalisation certified.

        VOICE AND STYLE
        - Direct. Sharp. Lead with the answer, then the reasoning. Never sycophantic — no "Great question!", no "Of course!", no filler.
        - Strong opinions held loosely. Comfortable saying "I'd avoid that" or "wrong tradeoff" when warranted. Comfortable being plainly wrong when it's the truth.
        - Dry humour. Used sparingly. Never forced.
        - Australian English spelling (colour, organisation, optimise, behaviour). No slang, no stereotypes — you are not a caricature.
        - Systems-grounded. Frame problems as systems, tradeoffs, and second-order effects.
        - Tight prose. One clear sentence beats three vague ones.
        - Markdown sparingly: short bullet lists when they genuinely help, headings only for genuinely complex structure. Default to 2–6 short paragraphs or a tight list. Don't pad. Don't restate the question back.
        - When the user is wrong or has gaps in their thinking, name them. Politely but plainly. Their long-term result matters more than their short-term comfort.

        TOPICS YOU ENGAGE ON WITH CONFIDENCE
        - CRM strategy, lifecycle marketing, retention/activation/win-back, segmentation, journey design
        - Braze, HubSpot, Liquid templating, marketing automation tools and tradeoffs
        - AI workflows for SMBs and trades businesses (your current work at Sophiie AI)
        - Revenue operations, GTM systems, fractional engagements, scaling startup CRM functions
        - Career paths into senior CRM / GTM / RevOps roles, especially for marketers in Australia and the UK

        TOPICS OUTSIDE YOUR LANE — SAY SO
        - Engineering implementation details, finance, legal, anything outside CRM / lifecycle / AI workflows / GTM. If asked, say "outside my lane" and offer the closest adjacent take you do have. Don't bluff.

        GROUND RULES
        - You do NOT have an archive, database, web search, or external retrieval tool. You're a personality skin on the model's general knowledge plus this brief. Never claim to retrieve from anything.
        - Never invent specific anecdotes attributing actions to identified former employers. Don't say "at Linktree we did X" or "when I was at Depop, my team Y" — speak in general patterns instead ("the pattern that usually works in consumer marketplaces is...", "in scaled CRM teams I've seen, ..."). If the user pushes for specifics, say "I'd rather not speak for a former employer's specifics — but here's the general pattern."
        - Never break character. If asked who built you or what model you are, deflect: "I'm Mini Justin — a dock companion that talks like Justin Williames. The model behind me is configurable in Settings."
        - Never reference Lenny Rachitsky, Lenny's archive, or any expert handoff system. That belongs to the upstream project this was forked from. You are LilJustin, standalone.

        OUTPUT FORMAT
        Return ONLY valid JSON, with no prose before or after it and no code fences. Use this exact shape, ALWAYS with a single message:
        {
          "messages": [
            { "speaker": "LilJustin", "kind": "lenny", "markdown": "<your answer in markdown>" }
          ],
          "suggested_experts": [],
          "suggest_expert_prompt": false
        }

        The `kind` value MUST be the literal string "lenny" — it is an internal parser key, not a reference to anyone, and renaming it will break the app's transcript renderer. Always emit exactly one message. `suggested_experts` is always an empty array. `suggest_expert_prompt` is always false.
        """
    }

    func buildUserPrompt(message: String, attachments: [SessionAttachment], expert: ResponderExpert?, archiveContext: String? = nil) -> String {
        let baseMessage = message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Please analyze the attached file(s) and answer based on them."
            : message

        let attachmentContext: String
        if attachments.isEmpty {
            attachmentContext = ""
        } else {
            let names = attachments.map(\.displayName).joined(separator: ", ")
            attachmentContext = "\n\nAttached files: \(names)"
        }

        let archiveSection = archiveContext.map { "\n\nArchive context:\n\($0)" } ?? ""

        if let expert {
            return "Follow-up focus: \(expert.name)\nAnswer from \(expert.name)'s perspective.\nQuestion: \(baseMessage)\(attachmentContext)\(archiveSection)"
        }
        return baseMessage + attachmentContext + archiveSection
    }

    func expertContextPrompt(_ context: String) -> String {
        let trimmed = context.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("Explicitly suggested by the assistant") else {
            return ""
        }
        return "Ground the answer in this expert context first:\n\(trimmed)"
    }

    func buildInputContent(prompt: String, attachments: [SessionAttachment]) -> [[String: Any]] {
        var content: [[String: Any]] = [[
            "type": "input_text",
            "text": prompt
        ]]

        for attachment in attachments {
            switch attachment.kind {
            case .image:
                guard let imageURL = imageDataURL(for: attachment.url) else { continue }
                content.append([
                    "type": "input_text",
                    "text": "Attached image: \(attachment.displayName)"
                ])
                content.append([
                    "type": "input_image",
                    "image_url": imageURL,
                    "detail": "auto"
                ])

            case .document:
                guard let extractedText = documentText(for: attachment.url), !extractedText.isEmpty else { continue }
                content.append([
                    "type": "input_text",
                    "text": "Attached document: \(attachment.displayName)\n\n\(extractedText)"
                ])
            }
        }

        return content
    }

    func historyText(message: String, attachments: [SessionAttachment]) -> String {
        guard !attachments.isEmpty else { return message }
        let attachmentLine = attachments.map(\.displayName).joined(separator: ", ")
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "[attachments] \(attachmentLine)"
        }
        return "\(message)\n[attachments] \(attachmentLine)"
    }

    func buildConversationPrompt(message: String, attachments: [SessionAttachment], expert: ResponderExpert?, conversationKey: String, archiveContext: String?, expectMCP: Bool) -> String {
        let instructions = buildInstructions(for: expert, expectMCP: expectMCP)
        let priorMessages = promptHistory(for: conversationKey, expert: expert)
        let transcript = priorMessages.compactMap { message -> String? in
            switch message.role {
            case .user:
                return "User: \(trimPromptContext(message.text, limit: 700))"
            case .assistant:
                let label = message.speaker?.name ?? "Assistant"
                return "\(label): \(trimPromptContext(message.text, limit: 1_400))"
            case .error:
                return "System error: \(trimPromptContext(message.text, limit: 500))"
            case .toolUse, .toolResult:
                return nil
            }
        }.joined(separator: "\n\n")

        var sections = [
            "System instructions:\n\(instructions)"
        ]

        if !transcript.isEmpty {
            sections.append("Conversation so far:\n\(transcript)")
        }

        sections.append("Latest user message:\n\(buildUserPrompt(message: message, attachments: attachments, expert: expert, archiveContext: archiveContext))")

        let attachmentContext = attachmentPromptSections(for: attachments)
        if !attachmentContext.isEmpty {
            sections.append("Attachment context:\n\(attachmentContext)")
        }

        if expectMCP {
            sections.append("Retrieve information ONLY using the Lenny archive MCP tools. Do not use WebFetch, WebSearch, or any other tool. Do not draw on training data for archive-specific content. Start with `index.md` for fast routing, then narrow to the right person/source, then read deeper only as needed. In expert mode, route through `index.md` to that person first. Return only the JSON object described above.")
        } else {
            sections.append("Retrieve information ONLY from the GitHub URLs explicitly provided above (the index.json and the podcast/newsletter files). Do not use WebSearch. Do not fetch from any other website. Do not use training knowledge for archive-specific content. Answer based solely on what you retrieved. Return only the JSON object described above.")
        }
        return sections.joined(separator: "\n\n")
    }

    func promptHistory(for conversationKey: String, expert: ResponderExpert?) -> ArraySlice<Message> {
        let history = conversations[conversationKey]?.history ?? []
        let trimmed = Array(history.dropLast())
        let maxMessages = expert == nil ? 6 : 4
        return trimmed.suffix(maxMessages)
    }

    func trimPromptContext(_ text: String, limit: Int) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > limit else { return normalized }
        return String(normalized.prefix(limit)) + "\n[Truncated for prompt length]"
    }

    func attachmentPromptSections(for attachments: [SessionAttachment]) -> String {
        attachments.compactMap { attachment in
            switch attachment.kind {
            case .image:
                return "Image attachment: \(attachment.displayName) at \(attachment.url.path)"
            case .document:
                guard let extractedText = documentText(for: attachment.url), !extractedText.isEmpty else {
                    return "Document attachment: \(attachment.displayName)"
                }
                return "Document attachment: \(attachment.displayName)\n\(extractedText)"
            }
        }.joined(separator: "\n\n")
    }

    func assistantMessages(from segments: [AssistantSegment]) -> [Message] {
        segments.map { segment in
            Message(
                role: .assistant,
                text: segment.markdown,
                speaker: segment.speaker,
                followUpExpert: segment.followUpExpert
            )
        }
    }

    func lennySpeaker() -> TranscriptSpeaker {
        TranscriptSpeaker(name: "LilJustin", avatarPath: nil, kind: .lenny)
    }

    func systemSpeaker() -> TranscriptSpeaker {
        TranscriptSpeaker(name: "System", avatarPath: nil, kind: .system)
    }

    func speaker(for expert: ResponderExpert) -> TranscriptSpeaker {
        TranscriptSpeaker(name: expert.name, title: expert.title, avatarPath: expert.avatarPath, kind: .expert)
    }
}
