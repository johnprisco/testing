import Foundation
import SwiftSoup

/// Parses JSON-LD structured data (schema.org/Recipe) from HTML
public struct JSONLDRecipeParser: Sendable {

    public init() {}

    /// Extract recipe from JSON-LD script tags in HTML
    public func extractRecipe(from html: String, sourceURL: URL? = nil) throws -> ExtractedRecipe? {
        let document = try SwiftSoup.parse(html)

        // Find all JSON-LD script tags
        let scripts = try document.select("script[type=application/ld+json]")

        for script in scripts {
            let jsonText = try script.html()

            guard let data = jsonText.data(using: .utf8) else { continue }

            do {
                // Try to parse as a single object or array
                let json = try JSONSerialization.jsonObject(with: data)

                if let recipe = extractRecipeFromJSON(json, sourceURL: sourceURL) {
                    return recipe
                }
            } catch {
                // Invalid JSON, try next script tag
                continue
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    private func extractRecipeFromJSON(_ json: Any, sourceURL: URL?) -> ExtractedRecipe? {
        // Handle array of objects (some sites wrap in @graph)
        if let array = json as? [[String: Any]] {
            for item in array {
                if let recipe = parseRecipeObject(item, sourceURL: sourceURL) {
                    return recipe
                }
            }
        }

        // Handle single object
        if let dict = json as? [String: Any] {
            // Check for @graph array
            if let graph = dict["@graph"] as? [[String: Any]] {
                for item in graph {
                    if let recipe = parseRecipeObject(item, sourceURL: sourceURL) {
                        return recipe
                    }
                }
            }

            // Try parsing as direct recipe object
            if let recipe = parseRecipeObject(dict, sourceURL: sourceURL) {
                return recipe
            }
        }

        return nil
    }

    private func parseRecipeObject(_ dict: [String: Any], sourceURL: URL?) -> ExtractedRecipe? {
        // Check if this is a Recipe type
        guard let type = dict["@type"] else { return nil }

        let isRecipe: Bool
        if let typeString = type as? String {
            isRecipe = typeString == "Recipe"
        } else if let typeArray = type as? [String] {
            isRecipe = typeArray.contains("Recipe")
        } else {
            return nil
        }

        guard isRecipe else { return nil }

        // Extract title (required)
        guard let title = dict["name"] as? String, !title.isEmpty else {
            return nil
        }

        var recipe = ExtractedRecipe(title: title, sourceURL: sourceURL)

        // Description
        recipe.description = dict["description"] as? String

        // Image
        if let imageURL = extractImageURL(from: dict["image"]) {
            recipe.imageURL = imageURL
        }

        // Ingredients
        recipe.ingredients = extractStringArray(from: dict["recipeIngredient"])
            .map { cleanText($0) }
            .filter { !$0.isEmpty }

        // Instructions
        recipe.instructions = extractInstructions(from: dict["recipeInstructions"])

        // Times
        recipe.prepTime = parseDuration(dict["prepTime"] as? String)
        recipe.cookTime = parseDuration(dict["cookTime"] as? String)
        recipe.totalTime = parseDuration(dict["totalTime"] as? String)

        // Servings/Yield
        recipe.servings = extractServings(from: dict)
        recipe.yield = dict["recipeYield"] as? String
            ?? (dict["recipeYield"] as? [String])?.first

        // Author
        recipe.author = extractAuthor(from: dict["author"])

        // Date
        if let dateString = dict["datePublished"] as? String {
            recipe.datePublished = parseDate(dateString)
        }

        // Category/Cuisine
        recipe.category = dict["recipeCategory"] as? String
            ?? (dict["recipeCategory"] as? [String])?.first
        recipe.cuisine = dict["recipeCuisine"] as? String
            ?? (dict["recipeCuisine"] as? [String])?.first

        // Keywords
        if let keywords = dict["keywords"] as? String {
            recipe.keywords = keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        } else if let keywords = dict["keywords"] as? [String] {
            recipe.keywords = keywords
        }

        // Nutrition
        if let nutritionDict = dict["nutrition"] as? [String: Any] {
            recipe.nutrition = parseNutrition(nutritionDict)
        }

        return recipe
    }

    private func extractImageURL(from value: Any?) -> URL? {
        if let urlString = value as? String {
            return URL(string: urlString)
        }
        if let dict = value as? [String: Any], let urlString = dict["url"] as? String {
            return URL(string: urlString)
        }
        if let array = value as? [Any], let first = array.first {
            return extractImageURL(from: first)
        }
        return nil
    }

    private func extractStringArray(from value: Any?) -> [String] {
        if let array = value as? [String] {
            return array
        }
        if let string = value as? String {
            return [string]
        }
        return []
    }

    private func extractInstructions(from value: Any?) -> [String] {
        var instructions: [String] = []

        if let array = value as? [Any] {
            for item in array {
                if let text = item as? String {
                    instructions.append(cleanText(text))
                } else if let dict = item as? [String: Any] {
                    // HowToStep or HowToSection
                    if let text = dict["text"] as? String {
                        instructions.append(cleanText(text))
                    } else if let name = dict["name"] as? String {
                        instructions.append(cleanText(name))
                    }
                    // Handle HowToSection with itemListElement
                    if let items = dict["itemListElement"] as? [[String: Any]] {
                        for item in items {
                            if let text = item["text"] as? String {
                                instructions.append(cleanText(text))
                            }
                        }
                    }
                }
            }
        } else if let text = value as? String {
            // Single instruction or HTML content
            instructions = text.components(separatedBy: .newlines)
                .map { cleanText($0) }
                .filter { !$0.isEmpty }
        }

        return instructions.filter { !$0.isEmpty }
    }

    private func extractServings(from dict: [String: Any]) -> String? {
        if let yield = dict["recipeYield"] {
            if let yieldArray = yield as? [Any] {
                // Look for a numeric value
                for item in yieldArray {
                    if let num = item as? Int {
                        return "\(num)"
                    }
                    if let str = item as? String, str.first?.isNumber == true {
                        return str
                    }
                }
                return (yieldArray.first as? String)
            }
            if let yieldString = yield as? String {
                return yieldString
            }
            if let yieldInt = yield as? Int {
                return "\(yieldInt)"
            }
        }
        return nil
    }

    private func extractAuthor(from value: Any?) -> String? {
        if let name = value as? String {
            return name
        }
        if let dict = value as? [String: Any] {
            return dict["name"] as? String
        }
        if let array = value as? [Any], let first = array.first {
            return extractAuthor(from: first)
        }
        return nil
    }

    private func parseDuration(_ iso8601: String?) -> Duration? {
        guard let iso8601 = iso8601, iso8601.hasPrefix("PT") else { return nil }

        var remaining = iso8601.dropFirst(2) // Remove "PT"
        var totalSeconds: Int64 = 0

        // Parse hours
        if let hIndex = remaining.firstIndex(of: "H") {
            if let hours = Int64(remaining[..<hIndex]) {
                totalSeconds += hours * 3600
            }
            remaining = remaining[remaining.index(after: hIndex)...]
        }

        // Parse minutes
        if let mIndex = remaining.firstIndex(of: "M") {
            if let minutes = Int64(remaining[..<mIndex]) {
                totalSeconds += minutes * 60
            }
            remaining = remaining[remaining.index(after: mIndex)...]
        }

        // Parse seconds
        if let sIndex = remaining.firstIndex(of: "S") {
            if let seconds = Int64(remaining[..<sIndex]) {
                totalSeconds += seconds
            }
        }

        return totalSeconds > 0 ? .seconds(totalSeconds) : nil
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            ISO8601DateFormatter(),
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        // Try basic date formats
        let dateFormatter = DateFormatter()
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss", "MMMM d, yyyy"]
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    private func parseNutrition(_ dict: [String: Any]) -> ExtractedNutrition {
        ExtractedNutrition(
            calories: dict["calories"] as? String,
            fatContent: dict["fatContent"] as? String,
            saturatedFatContent: dict["saturatedFatContent"] as? String,
            carbohydrateContent: dict["carbohydrateContent"] as? String,
            sugarContent: dict["sugarContent"] as? String,
            fiberContent: dict["fiberContent"] as? String,
            proteinContent: dict["proteinContent"] as? String,
            sodiumContent: dict["sodiumContent"] as? String,
            cholesterolContent: dict["cholesterolContent"] as? String
        )
    }

    private func cleanText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
