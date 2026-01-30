import Foundation

/// Main service for extracting recipes from URLs
/// Designed for on-device extraction on iOS
public actor RecipeExtractor {

    private let jsonLDParser: JSONLDRecipeParser
    private let htmlParser: HTMLRecipeParser
    private let urlSession: URLSession

    public enum ExtractionError: Error, LocalizedError {
        case invalidURL
        case networkError(Error)
        case noRecipeFound
        case parsingError(Error)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The URL is invalid"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .noRecipeFound:
                return "No recipe found on this page"
            case .parsingError(let error):
                return "Failed to parse page: \(error.localizedDescription)"
            }
        }
    }

    public struct ExtractionResult: Sendable {
        public let recipe: ExtractedRecipe
        public let source: ExtractionSource
        public let confidence: ExtractionConfidence
    }

    public enum ExtractionSource: Sendable {
        case jsonLD        // Structured data (most reliable)
        case htmlParsing   // Heuristic HTML parsing
    }

    public enum ExtractionConfidence: Sendable {
        case high    // JSON-LD with complete data
        case medium  // JSON-LD partial or good HTML match
        case low     // HTML heuristics only
    }

    public init(urlSession: URLSession = .shared) {
        self.jsonLDParser = JSONLDRecipeParser()
        self.htmlParser = HTMLRecipeParser()
        self.urlSession = urlSession
    }

    /// Extract a recipe from a URL
    /// - Parameter url: The URL of the recipe page
    /// - Returns: Extraction result with recipe, source, and confidence
    public func extractRecipe(from url: URL) async throws -> ExtractionResult {
        // Fetch the HTML content
        let html = try await fetchHTML(from: url)

        // Try extraction strategies in order of reliability
        return try extractRecipe(from: html, sourceURL: url)
    }

    /// Extract a recipe from raw HTML content
    /// - Parameters:
    ///   - html: The HTML content to parse
    ///   - sourceURL: Optional source URL for the recipe
    /// - Returns: Extraction result with recipe, source, and confidence
    public func extractRecipe(from html: String, sourceURL: URL? = nil) throws -> ExtractionResult {
        // Strategy 1: Try JSON-LD structured data (most reliable)
        if let recipe = try? jsonLDParser.extractRecipe(from: html, sourceURL: sourceURL) {
            let confidence = assessJSONLDConfidence(recipe)
            return ExtractionResult(
                recipe: recipe,
                source: .jsonLD,
                confidence: confidence
            )
        }

        // Strategy 2: Fall back to HTML parsing
        if let recipe = try? htmlParser.extractRecipe(from: html, sourceURL: sourceURL) {
            let confidence = assessHTMLConfidence(recipe)
            return ExtractionResult(
                recipe: recipe,
                source: .htmlParsing,
                confidence: confidence
            )
        }

        throw ExtractionError.noRecipeFound
    }

    // MARK: - Private Methods

    private func fetchHTML(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ExtractionError.networkError(
                    NSError(domain: "RecipeExtractor", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                )
            }

            // Try to detect encoding from response
            var encoding = String.Encoding.utf8
            if let encodingName = httpResponse.textEncodingName {
                let cfEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
                if cfEncoding != kCFStringEncodingInvalidId {
                    encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
                }
            }

            guard let html = String(data: data, encoding: encoding)
                    ?? String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1) else {
                throw ExtractionError.parsingError(
                    NSError(domain: "RecipeExtractor", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "Could not decode HTML"])
                )
            }

            return html
        } catch let error as ExtractionError {
            throw error
        } catch {
            throw ExtractionError.networkError(error)
        }
    }

    private func assessJSONLDConfidence(_ recipe: ExtractedRecipe) -> ExtractionConfidence {
        var score = 0

        // Essential fields
        if !recipe.title.isEmpty { score += 2 }
        if recipe.ingredients.count >= 3 { score += 2 }
        if recipe.instructions.count >= 2 { score += 2 }

        // Nice-to-have fields
        if recipe.description != nil { score += 1 }
        if recipe.imageURL != nil { score += 1 }
        if recipe.prepTime != nil || recipe.cookTime != nil { score += 1 }
        if recipe.servings != nil { score += 1 }

        if score >= 8 {
            return .high
        } else if score >= 5 {
            return .medium
        } else {
            return .low
        }
    }

    private func assessHTMLConfidence(_ recipe: ExtractedRecipe) -> ExtractionConfidence {
        var score = 0

        if !recipe.title.isEmpty { score += 1 }
        if recipe.ingredients.count >= 5 { score += 2 }
        if recipe.instructions.count >= 3 { score += 2 }

        // HTML parsing is inherently less reliable
        if score >= 4 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Convenience Extensions

extension RecipeExtractor {
    /// Extract a recipe from a URL string
    public func extractRecipe(from urlString: String) async throws -> ExtractionResult {
        guard let url = URL(string: urlString) else {
            throw ExtractionError.invalidURL
        }
        return try await extractRecipe(from: url)
    }
}
