import Foundation
import SwiftSoup

/// Fallback parser that extracts recipe data from HTML using common patterns
public struct HTMLRecipeParser: Sendable {

    public init() {}

    /// Attempt to extract recipe from HTML using common patterns and heuristics
    public func extractRecipe(from html: String, sourceURL: URL? = nil) throws -> ExtractedRecipe? {
        let document = try SwiftSoup.parse(html)

        // Try to find a title
        guard let title = try extractTitle(from: document) else {
            return nil
        }

        var recipe = ExtractedRecipe(title: title, sourceURL: sourceURL)

        // Extract description
        recipe.description = try extractDescription(from: document)

        // Extract image
        recipe.imageURL = try extractImageURL(from: document)

        // Extract ingredients
        recipe.ingredients = try extractIngredients(from: document)

        // Extract instructions
        recipe.instructions = try extractInstructions(from: document)

        // Only return if we found meaningful content
        guard !recipe.ingredients.isEmpty || !recipe.instructions.isEmpty else {
            return nil
        }

        // Try to extract additional metadata
        recipe.author = try extractAuthor(from: document)
        recipe.servings = try extractServings(from: document)
        recipe.prepTime = try extractTime(from: document, type: "prep")
        recipe.cookTime = try extractTime(from: document, type: "cook")
        recipe.totalTime = try extractTime(from: document, type: "total")

        return recipe
    }

    // MARK: - Title Extraction

    private func extractTitle(from document: Document) throws -> String? {
        // Try common recipe title selectors
        let titleSelectors = [
            "h1.recipe-title",
            "h1.entry-title",
            "h1[itemprop=name]",
            ".recipe-header h1",
            ".recipe h1",
            "article h1",
            "h1",
        ]

        for selector in titleSelectors {
            if let element = try document.select(selector).first() {
                let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && text.count < 200 {
                    return text
                }
            }
        }

        // Fallback to page title
        if let title = try document.title().components(separatedBy: "|").first?
            .components(separatedBy: "-").first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }

        return nil
    }

    // MARK: - Description Extraction

    private func extractDescription(from document: Document) throws -> String? {
        let descSelectors = [
            "[itemprop=description]",
            ".recipe-description",
            ".recipe-summary",
            "meta[name=description]",
            "meta[property='og:description']",
        ]

        for selector in descSelectors {
            if let element = try document.select(selector).first() {
                let text: String
                if element.tagName() == "meta" {
                    text = try element.attr("content")
                } else {
                    text = try element.text()
                }
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty && cleaned.count < 1000 {
                    return cleaned
                }
            }
        }

        return nil
    }

    // MARK: - Image Extraction

    private func extractImageURL(from document: Document) throws -> URL? {
        let imageSelectors = [
            "[itemprop=image]",
            ".recipe-image img",
            ".recipe img",
            "article img",
            "meta[property='og:image']",
        ]

        for selector in imageSelectors {
            if let element = try document.select(selector).first() {
                let urlString: String
                if element.tagName() == "meta" {
                    urlString = try element.attr("content")
                } else if element.tagName() == "img" {
                    urlString = try element.attr("src")
                } else {
                    // Could be a container with an img inside
                    if let img = try element.select("img").first() {
                        urlString = try img.attr("src")
                    } else {
                        urlString = try element.attr("src")
                    }
                }

                if let url = URL(string: urlString), urlString.contains("http") {
                    return url
                }
            }
        }

        return nil
    }

    // MARK: - Ingredients Extraction

    private func extractIngredients(from document: Document) throws -> [String] {
        // Try structured selectors first
        let ingredientSelectors = [
            "[itemprop=recipeIngredient]",
            "[itemprop=ingredients]",
            ".recipe-ingredients li",
            ".ingredients li",
            ".ingredient-list li",
            ".wprm-recipe-ingredient",
            ".tasty-recipes-ingredients li",
            "ul.ingredients li",
        ]

        for selector in ingredientSelectors {
            let elements = try document.select(selector)
            if elements.size() > 0 {
                var ingredients: [String] = []
                for element in elements {
                    let text = try element.text()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if isValidIngredient(text) {
                        ingredients.append(text)
                    }
                }
                if ingredients.count >= 2 {
                    return ingredients
                }
            }
        }

        // Try to find ingredient section by heading
        if let ingredients = try extractListAfterHeading(
            document: document,
            headingPatterns: ["ingredient", "you.?ll need", "what you need"]
        ) {
            return ingredients
        }

        return []
    }

    // MARK: - Instructions Extraction

    private func extractInstructions(from document: Document) throws -> [String] {
        // Try structured selectors first
        let instructionSelectors = [
            "[itemprop=recipeInstructions] li",
            "[itemprop=recipeInstructions] p",
            ".recipe-instructions li",
            ".recipe-instructions p",
            ".instructions li",
            ".instructions ol li",
            ".wprm-recipe-instruction",
            ".tasty-recipes-instructions li",
            ".directions li",
            "ol.instructions li",
        ]

        for selector in instructionSelectors {
            let elements = try document.select(selector)
            if elements.size() > 0 {
                var instructions: [String] = []
                for element in elements {
                    let text = try element.text()
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if isValidInstruction(text) {
                        instructions.append(cleanInstruction(text))
                    }
                }
                if instructions.count >= 1 {
                    return instructions
                }
            }
        }

        // Try to find instruction section by heading
        if let instructions = try extractListAfterHeading(
            document: document,
            headingPatterns: ["instruction", "direction", "method", "how to make", "steps"]
        ) {
            return instructions
        }

        return []
    }

    // MARK: - Metadata Extraction

    private func extractAuthor(from document: Document) throws -> String? {
        let authorSelectors = [
            "[itemprop=author]",
            ".recipe-author",
            ".author-name",
            "a[rel=author]",
        ]

        for selector in authorSelectors {
            if let element = try document.select(selector).first() {
                let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && text.count < 100 {
                    return text
                }
            }
        }

        return nil
    }

    private func extractServings(from document: Document) throws -> String? {
        let servingsSelectors = [
            "[itemprop=recipeYield]",
            ".recipe-yield",
            ".recipe-servings",
            ".servings",
        ]

        for selector in servingsSelectors {
            if let element = try document.select(selector).first() {
                let text = try element.text().trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && text.count < 50 {
                    return text
                }
            }
        }

        return nil
    }

    private func extractTime(from document: Document, type: String) throws -> Duration? {
        let selectors: [String]

        switch type {
        case "prep":
            selectors = ["[itemprop=prepTime]", ".prep-time", ".recipe-prep-time"]
        case "cook":
            selectors = ["[itemprop=cookTime]", ".cook-time", ".recipe-cook-time"]
        case "total":
            selectors = ["[itemprop=totalTime]", ".total-time", ".recipe-total-time"]
        default:
            return nil
        }

        for selector in selectors {
            if let element = try document.select(selector).first() {
                // Check for datetime attribute (ISO 8601)
                let datetime = try element.attr("datetime")
                if !datetime.isEmpty, let duration = parseDuration(datetime) {
                    return duration
                }

                // Try to parse from text
                let text = try element.text()
                if let duration = parseTimeText(text) {
                    return duration
                }
            }
        }

        return nil
    }

    // MARK: - Helper Methods

    private func extractListAfterHeading(
        document: Document,
        headingPatterns: [String]
    ) throws -> [String]? {
        let headings = try document.select("h1, h2, h3, h4, h5, h6")

        for heading in headings {
            let headingText = try heading.text().lowercased()

            for pattern in headingPatterns {
                if headingText.contains(pattern) {
                    // Look for the next list element
                    var sibling = try heading.nextElementSibling()
                    while let current = sibling {
                        if current.tagName() == "ul" || current.tagName() == "ol" {
                            let items = try current.select("li")
                            var results: [String] = []
                            for item in items {
                                let text = try item.text()
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                if !text.isEmpty {
                                    results.append(text)
                                }
                            }
                            if results.count >= 2 {
                                return results
                            }
                        }
                        // Stop if we hit another heading
                        if ["h1", "h2", "h3", "h4", "h5", "h6"].contains(current.tagName()) {
                            break
                        }
                        sibling = try current.nextElementSibling()
                    }
                }
            }
        }

        return nil
    }

    private func isValidIngredient(_ text: String) -> Bool {
        // Filter out empty, too short, or too long strings
        guard text.count >= 3 && text.count < 500 else { return false }

        // Filter out common non-ingredient text
        let lowercased = text.lowercased()
        let invalidPatterns = ["advertisement", "subscribe", "newsletter", "click here"]
        for pattern in invalidPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }

        return true
    }

    private func isValidInstruction(_ text: String) -> Bool {
        // Filter out empty or too short strings
        guard text.count >= 10 && text.count < 2000 else { return false }

        // Filter out common non-instruction text
        let lowercased = text.lowercased()
        let invalidPatterns = ["advertisement", "subscribe", "newsletter", "click here", "print recipe"]
        for pattern in invalidPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }

        return true
    }

    private func cleanInstruction(_ text: String) -> String {
        // Remove leading step numbers if present
        let pattern = "^(step\\s*)?\\d+\\.?\\s*:?\\s*"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    private func parseDuration(_ iso8601: String) -> Duration? {
        guard iso8601.hasPrefix("PT") else { return nil }

        var remaining = iso8601.dropFirst(2)
        var totalSeconds: Int64 = 0

        if let hIndex = remaining.firstIndex(of: "H") {
            if let hours = Int64(remaining[..<hIndex]) {
                totalSeconds += hours * 3600
            }
            remaining = remaining[remaining.index(after: hIndex)...]
        }

        if let mIndex = remaining.firstIndex(of: "M") {
            if let minutes = Int64(remaining[..<mIndex]) {
                totalSeconds += minutes * 60
            }
            remaining = remaining[remaining.index(after: mIndex)...]
        }

        if let sIndex = remaining.firstIndex(of: "S") {
            if let seconds = Int64(remaining[..<sIndex]) {
                totalSeconds += seconds
            }
        }

        return totalSeconds > 0 ? .seconds(totalSeconds) : nil
    }

    private func parseTimeText(_ text: String) -> Duration? {
        let lowercased = text.lowercased()
        var totalSeconds: Int64 = 0

        // Match patterns like "1 hour", "30 minutes", "1 hr 30 min"
        let hourPattern = "(\\d+)\\s*(?:hour|hr)s?"
        let minutePattern = "(\\d+)\\s*(?:minute|min)s?"

        if let hourRegex = try? NSRegularExpression(pattern: hourPattern, options: .caseInsensitive) {
            let range = NSRange(lowercased.startIndex..., in: lowercased)
            if let match = hourRegex.firstMatch(in: lowercased, options: [], range: range),
               let hourRange = Range(match.range(at: 1), in: lowercased),
               let hours = Int64(lowercased[hourRange]) {
                totalSeconds += hours * 3600
            }
        }

        if let minuteRegex = try? NSRegularExpression(pattern: minutePattern, options: .caseInsensitive) {
            let range = NSRange(lowercased.startIndex..., in: lowercased)
            if let match = minuteRegex.firstMatch(in: lowercased, options: [], range: range),
               let minuteRange = Range(match.range(at: 1), in: lowercased),
               let minutes = Int64(lowercased[minuteRange]) {
                totalSeconds += minutes * 60
            }
        }

        return totalSeconds > 0 ? .seconds(totalSeconds) : nil
    }
}
