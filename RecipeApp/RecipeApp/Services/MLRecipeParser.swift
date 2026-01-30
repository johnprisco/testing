import Foundation
import FoundationModels

/// Recipe parser using on-device Foundation Models (iOS 18+)
/// Falls back gracefully on unsupported devices
@available(iOS 18.0, macOS 15.0, *)
public actor MLRecipeParser {

    private var session: LanguageModelSession?

    public init() {}

    /// Check if on-device ML extraction is available
    public var isAvailable: Bool {
        get async {
            do {
                let availability = LanguageModelSession.Availability.current
                return availability == .available
            }
        }
    }

    /// Extract recipe from plain text using on-device LLM
    public func extractRecipe(from text: String, sourceURL: URL? = nil) async throws -> ExtractedRecipe? {
        guard await isAvailable else {
            return nil
        }

        // Initialize session if needed
        if session == nil {
            session = LanguageModelSession()
        }

        guard let session = session else {
            return nil
        }

        // Create a structured prompt for recipe extraction
        let prompt = buildExtractionPrompt(for: text)

        do {
            let response = try await session.respond(to: prompt)
            return parseResponse(response.content, sourceURL: sourceURL)
        } catch {
            // Model unavailable or other error - return nil to allow other fallbacks
            return nil
        }
    }

    /// Extract recipe from HTML by first cleaning it to plain text
    public func extractRecipe(fromHTML html: String, sourceURL: URL? = nil) async throws -> ExtractedRecipe? {
        let plainText = extractPlainText(from: html)

        // Only proceed if we have meaningful content
        guard plainText.count > 100 else {
            return nil
        }

        return try await extractRecipe(from: plainText, sourceURL: sourceURL)
    }

    // MARK: - Private Methods

    private func buildExtractionPrompt(for text: String) -> String {
        """
        Extract the recipe from the following text. Return ONLY a valid JSON object with this exact structure (no markdown, no explanation):
        {
            "title": "Recipe Name",
            "description": "Brief description",
            "ingredients": ["ingredient 1", "ingredient 2"],
            "instructions": ["step 1", "step 2"],
            "prepTime": "15 minutes",
            "cookTime": "30 minutes",
            "servings": "4",
            "cuisine": "Italian",
            "category": "Main Dish"
        }

        If a field is not found, omit it from the JSON. The title and ingredients are required.

        Text to extract from:
        ---
        \(text.prefix(8000))
        ---

        JSON:
        """
    }

    private func parseResponse(_ response: String, sourceURL: URL?) -> ExtractedRecipe? {
        // Find JSON in the response (model might include extra text)
        guard let jsonStart = response.firstIndex(of: "{"),
              let jsonEnd = response.lastIndex(of: "}") else {
            return nil
        }

        let jsonString = String(response[jsonStart...jsonEnd])

        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        do {
            let decoded = try JSONDecoder().decode(MLRecipeResponse.self, from: data)
            return decoded.toExtractedRecipe(sourceURL: sourceURL)
        } catch {
            return nil
        }
    }

    private func extractPlainText(from html: String) -> String {
        // Simple HTML tag removal - the ML model can handle some noise
        var text = html

        // Remove script and style content
        let patterns = [
            "<script[^>]*>[\\s\\S]*?</script>",
            "<style[^>]*>[\\s\\S]*?</style>",
            "<nav[^>]*>[\\s\\S]*?</nav>",
            "<footer[^>]*>[\\s\\S]*?</footer>",
            "<header[^>]*>[\\s\\S]*?</header>",
            "<!--[\\s\\S]*?-->",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ")
            }
        }

        // Remove remaining HTML tags
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            let range = NSRange(text.startIndex..., in: text)
            text = tagRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ")
        }

        // Decode HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")

        // Normalize whitespace
        if let whitespaceRegex = try? NSRegularExpression(pattern: "\\s+", options: []) {
            let range = NSRange(text.startIndex..., in: text)
            text = whitespaceRegex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: " ")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Response Model

private struct MLRecipeResponse: Decodable {
    let title: String
    let description: String?
    let ingredients: [String]
    let instructions: [String]?
    let prepTime: String?
    let cookTime: String?
    let servings: String?
    let cuisine: String?
    let category: String?

    func toExtractedRecipe(sourceURL: URL?) -> ExtractedRecipe? {
        // Require at least title and some ingredients
        guard !title.isEmpty, !ingredients.isEmpty else {
            return nil
        }

        return ExtractedRecipe(
            title: title,
            description: description,
            sourceURL: sourceURL,
            ingredients: ingredients,
            instructions: instructions ?? [],
            prepTime: parseTimeString(prepTime),
            cookTime: parseTimeString(cookTime),
            servings: servings,
            cuisine: cuisine,
            category: category
        )
    }

    private func parseTimeString(_ timeString: String?) -> Duration? {
        guard let timeString = timeString?.lowercased() else { return nil }

        var totalMinutes = 0

        // Extract hours
        if let hourMatch = timeString.range(of: "(\\d+)\\s*h", options: .regularExpression) {
            let numStr = timeString[hourMatch].filter { $0.isNumber }
            if let hours = Int(numStr) {
                totalMinutes += hours * 60
            }
        }

        // Extract minutes
        if let minMatch = timeString.range(of: "(\\d+)\\s*m", options: .regularExpression) {
            let numStr = timeString[minMatch].filter { $0.isNumber }
            if let mins = Int(numStr) {
                totalMinutes += mins
            }
        }

        // Try plain number (assume minutes)
        if totalMinutes == 0, let mins = Int(timeString.filter { $0.isNumber }) {
            totalMinutes = mins
        }

        return totalMinutes > 0 ? .seconds(totalMinutes * 60) : nil
    }
}

// MARK: - Availability Wrapper

/// Wrapper to check ML availability without @available requirements spreading everywhere
public struct MLRecipeParserAvailability {
    public static var isSupported: Bool {
        if #available(iOS 18.0, macOS 15.0, *) {
            return true
        }
        return false
    }
}
