import Foundation

/// In-app retrieval over the Orbit guides corpus.
///
/// At build time we bundle the full export from
/// `https://get.yourorbit.team/api/guides/export` as `orbit-guides.json`
/// (~850 KB, ~95 guides × ~9 KB markdown each). On first access the
/// JSON is parsed once and cached for the process lifetime — the file
/// is small enough that holding it in memory is cheaper than re-decoding
/// per turn.
///
/// `relevantGuides(for:topK:)` does a lightweight keyword-overlap score
/// (no embeddings, no network, no extra deps) and returns the top-K
/// guides. The caller then injects truncated markdown excerpts into the
/// per-turn prompt so the model can ground its answer in actual guide
/// content rather than just citing slugs from a manifest.
///
/// The corpus is refreshed on demand by re-running
/// `Scripts/refresh-orbit-guides.sh` and committing the new JSON.
enum OrbitGuidesCorpus {
    struct Entry: Decodable {
        let slug: String
        let title: String
        let summary: String
        let category: String
        let canonicalUrl: String
        let primarySkill: String
        let markdown: String
        let targetQuery: String?
    }

    private struct Payload: Decodable {
        let count: Int
        let guides: [Entry]
    }

    /// Lazily-loaded entry list. Empty if the bundle is missing or the
    /// JSON is malformed — retrieval just returns nothing in that case
    /// rather than blowing up the whole prompt-build path.
    static let entries: [Entry] = loadFromBundle()

    /// Top-K guides ordered by descending relevance to `query`. Returns
    /// at most `topK` items; may return fewer (or zero) if no guide has
    /// a non-zero score. Score is computed over title, summary, slug,
    /// targetQuery, and a leading slice of the markdown body — wide
    /// enough to catch keyword matches in the lede without paying full
    /// document scan cost.
    static func relevantGuides(for query: String, topK: Int = 3) -> [Entry] {
        let tokens = tokenise(query)
        guard !tokens.isEmpty, !entries.isEmpty else { return [] }

        let scored: [(Entry, Int)] = entries.map { entry in
            let haystack = "\(entry.title)  \(entry.summary)  \(entry.slug)  \(entry.targetQuery ?? "")  \(entry.markdown.prefix(2_000))".lowercased()
            var score = 0
            for token in tokens {
                if haystack.contains(token) {
                    // Title hits are worth more — they signal direct
                    // topical match rather than incidental keyword overlap.
                    let titleHit = entry.title.lowercased().contains(token)
                    let summaryHit = entry.summary.lowercased().contains(token)
                    score += titleHit ? 5 : (summaryHit ? 3 : 1)
                }
            }
            return (entry, score)
        }

        return scored
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map(\.0)
    }

    /// Render a compact prompt section the model can consume verbatim.
    /// Each guide is truncated to `excerptLimit` characters so 3 guides
    /// stay well under the 5–6 KB the per-turn prompt budget can spare.
    static func promptSection(for query: String, topK: Int = 3, excerptLimit: Int = 1_400) -> String {
        let hits = relevantGuides(for: query, topK: topK)
        guard !hits.isEmpty else { return "" }

        var lines: [String] = []
        lines.append("RELEVANT ORBIT GUIDE EXCERPTS — use these to ground your answer. Quote sparingly; cite the slug in the Sources block. Don't paste the excerpt back at the user.")
        lines.append("")
        for hit in hits {
            lines.append("--- \(hit.slug) — \(hit.title)")
            lines.append("URL: \(hit.canonicalUrl)")
            lines.append("Summary: \(hit.summary)")
            lines.append("")
            lines.append(truncate(hit.markdown, to: excerptLimit))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Internals

    private static func loadFromBundle() -> [Entry] {
        guard let url = Bundle.main.url(forResource: "orbit-guides", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        do {
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            return payload.guides
        } catch {
            return []
        }
    }

    /// Cheap query tokeniser. Lowercases, splits on non-alphanumerics,
    /// strips short noise tokens and a small stop list. Not a real
    /// tokenizer — just enough to score keyword overlap honestly.
    private static func tokenise(_ raw: String) -> [String] {
        let lower = raw.lowercased()
        let chunks = lower.split { ch in
            !(ch.isLetter || ch.isNumber)
        }.map(String.init)

        let stop: Set<String> = [
            "the", "and", "for", "with", "what", "how", "why", "when",
            "where", "are", "is", "this", "that", "you", "your", "from",
            "have", "has", "been", "any", "some", "there", "about", "into",
            "out", "but", "can", "should", "would", "could", "will", "just",
            "really", "very", "much", "more", "less", "than", "then", "them",
            "they", "their", "ours", "our", "i", "me", "my", "we", "us",
        ]

        return chunks.compactMap { token in
            let cleaned = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleaned.count >= 3, !stop.contains(cleaned) else { return nil }
            return cleaned
        }
    }

    private static func truncate(_ markdown: String, to limit: Int) -> String {
        let normalised = markdown.replacingOccurrences(of: "\r\n", with: "\n")
        guard normalised.count > limit else { return normalised }
        // Cut at a paragraph or sentence boundary near the limit, not
        // mid-word — keeps the excerpt readable for the model.
        let head = String(normalised.prefix(limit))
        if let cutoff = head.range(of: "\n\n", options: .backwards) {
            return String(head[..<cutoff.lowerBound]) + "\n\n[…guide continues at canonical URL…]"
        }
        if let cutoff = head.range(of: ". ", options: .backwards) {
            return String(head[..<cutoff.upperBound]) + " […guide continues at canonical URL…]"
        }
        return head + "…"
    }
}
