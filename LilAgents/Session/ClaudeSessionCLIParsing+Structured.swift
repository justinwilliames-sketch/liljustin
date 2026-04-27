import Foundation

extension ClaudeSession {
    func structuredResponse(from json: [String: Any]) -> (segments: [AssistantSegment], suggestedExperts: [ResponderExpert], suggestExpertPrompt: Bool)? {
        var segments: [AssistantSegment] = []

        if let rawMessages = json["messages"] as? [[String: Any]] {
            for raw in rawMessages {
                guard let markdown = raw["markdown"] as? String,
                      let speakerName = (raw["speaker"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !speakerName.isEmpty else { continue }
                let kind = ((raw["kind"] as? String) ?? "").lowercased()
                if kind == "expert", let expert = expertSuggestion(named: speakerName) {
                    segments.append(AssistantSegment(speaker: speaker(for: expert), markdown: markdown, followUpExpert: expert))
                } else {
                    let speakerValue = normalize(speakerName) == normalize("LilJustin")
                        ? lennySpeaker()
                        : TranscriptSpeaker(name: speakerName, avatarPath: nil, kind: .system)
                    segments.append(AssistantSegment(speaker: speakerValue, markdown: markdown, followUpExpert: nil))
                }
            }
        }

        if segments.isEmpty, let answerMarkdown = json["answer_markdown"] as? String {
            segments = [AssistantSegment(speaker: lennySpeaker(), markdown: answerMarkdown, followUpExpert: nil)]
        }

        guard !segments.isEmpty else { return nil }

        let explicitExperts = (json["suggested_experts"] as? [String] ?? []).compactMap { expertSuggestion(named: $0) }
        let impliedExperts = segments.compactMap(\.followUpExpert)
        let uniqueExperts = (explicitExperts + impliedExperts).reduce(into: [ResponderExpert]()) { partial, expert in
            if !partial.contains(where: { $0.name == expert.name }) {
                partial.append(expert)
            }
        }
        let suggestExpertPrompt = json["suggest_expert_prompt"] as? Bool ?? !uniqueExperts.isEmpty
        let suggestedExperts = Array(uniqueExperts.prefix(3))
        return (sanitizedOrchestrationSegments(segments, suggestedExperts: suggestedExperts), suggestedExperts, suggestExpertPrompt)
    }

    func sanitizedOrchestrationSegments(_ segments: [AssistantSegment], suggestedExperts: [ResponderExpert]) -> [AssistantSegment] {
        let knownExperts = (suggestedExperts + segments.compactMap(\.followUpExpert)).reduce(into: [ResponderExpert]()) { partial, expert in
            if !partial.contains(where: { $0.name == expert.name }) {
                partial.append(expert)
            }
        }

        guard !knownExperts.isEmpty else { return segments }

        return segments.map { segment in
            guard segment.speaker.kind == .lenny else { return segment }
            let sanitized = sanitizedOrchestrationMarkdown(segment.markdown, experts: knownExperts)
            guard sanitized != segment.markdown else { return segment }
            return AssistantSegment(speaker: segment.speaker, markdown: sanitized, followUpExpert: segment.followUpExpert)
        }
    }

    private func sanitizedOrchestrationMarkdown(_ markdown: String, experts: [ResponderExpert]) -> String {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return markdown }

        let cleaned = trimmed
        let lowered = cleaned.lowercased()
        let mentionedExperts = experts.filter {
            cleaned.localizedCaseInsensitiveContains("@\($0.name)") ||
            cleaned.localizedCaseInsensitiveContains($0.name)
        }
        let shouldCondense = cleaned.contains("@")
            || lowered.contains("bring in")
            || lowered.contains("join")
            || lowered.contains("thoughts on this")
            || lowered.contains("concrete")
            || (mentionedExperts.count >= 2 && cleaned.count > 120)

        guard shouldCondense, !mentionedExperts.isEmpty else { return cleaned }
        return orchestrationSummary(for: mentionedExperts.map(\.name))
    }

    private func orchestrationSummary(for names: [String]) -> String {
        let uniqueNames = names.reduce(into: [String]()) { partial, name in
            if !partial.contains(name) {
                partial.append(name)
            }
        }

        switch uniqueNames.count {
        case 0:
            return "Bringing in a specialist perspective."
        case 1:
            return "Bringing in @\(uniqueNames[0]) for a practical perspective."
        case 2:
            return "Bringing in @\(uniqueNames[0]) and @\(uniqueNames[1]) for practical perspectives."
        default:
            return "Bringing in @\(uniqueNames[0]), @\(uniqueNames[1]), and @\(uniqueNames[2]) for practical perspectives."
        }
    }

    func expertSuggestion(named rawName: String) -> ResponderExpert? {
        guard let canonical = canonicalExpertName(for: rawName),
              let avatarPath = avatarPath(for: canonical) else { return nil }
        let context = "Explicitly suggested by the assistant in the latest answer."
        return makeResponderExpert(name: canonical, avatarPath: avatarPath, archiveContext: context)
    }

    func decodeStructuredAssistantJSONObject(from outputText: String) -> [String: Any]? {
        let normalized = outputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let direct = decodeStructuredAssistantJSONObjectCandidate(normalized) {
            return direct
        }

        if let jsonCandidate = extractStructuredJSONCandidate(from: normalized),
           let decoded = decodeStructuredAssistantJSONObjectCandidate(jsonCandidate) {
            return decoded
        }

        return nil
    }

    private func decodeStructuredAssistantJSONObjectCandidate(_ candidate: String) -> [String: Any]? {
        guard let data = candidate.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let json = object as? [String: Any],
           json["answer_markdown"] is String || json["messages"] is [[String: Any]] {
            return json
        }

        if let wrapped = object as? String {
            let trimmed = wrapped.trimmingCharacters(in: .whitespacesAndNewlines)
            if let nested = decodeStructuredAssistantJSONObjectCandidate(trimmed) {
                return nested
            }
            if let nestedCandidate = extractStructuredJSONCandidate(from: trimmed) {
                return decodeStructuredAssistantJSONObjectCandidate(nestedCandidate)
            }
        }

        return nil
    }

    func extractStructuredJSONCandidate(from outputText: String) -> String? {
        let trimmed = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed
            .replacingOccurrences(of: #"^```json\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^```\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*```$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.hasPrefix("{"), normalized.hasSuffix("}") {
            return normalized
        }

        let characters = Array(normalized)
        for startIndex in characters.indices where characters[startIndex] == "{" {
            var depth = 0
            var inString = false
            var escaping = false

            for index in startIndex..<characters.count {
                let character = characters[index]

                if inString {
                    if escaping {
                        escaping = false
                    } else if character == "\\" {
                        escaping = true
                    } else if character == "\"" {
                        inString = false
                    }
                    continue
                }

                if character == "\"" {
                    inString = true
                    continue
                }

                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        let candidate = String(characters[startIndex...index])
                        if candidate.contains("\"answer_markdown\"") || candidate.contains("\"messages\"") {
                            return candidate
                        }
                        break
                    }
                }
            }
        }

        return nil
    }
}
