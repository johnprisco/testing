import Foundation

/// Main service for extracting recipes from URLs
/// Designed for on-device extraction on iOS
public actor RecipeExtractor {

    private let jsonLDParser: JSONLDRecipeParser
    private let htmlParser: HTMLRecipeParser
    private let urlSession: URLSession
    private let useMLFallback: Bool

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
        case onDeviceML    // Foundation Models extraction
    }

    public enum ExtractionConfidence: Sendable {
        case high    // JSON-LD with complete data
        case medium  // JSON-LD partial, good HTML match, or ML extraction
        case low     // Minimal data extracted
    }

    /// Initialize the recipe extractor
    /// - Parameters:
    ///   - urlSession: URL session for network requests
    ///   - useMLFallback: Whether to use on-device ML as final fallback (iOS 18+)
    public init(urlSession: URLSession = .shared, useMLFallback: Bool = true) {
        self.jsonLDParser = JSONLDRecipeParser()
        self.htmlParser = HTMLRecipeParser()
        self.urlSession = urlSession
        self.useMLFallback = useMLFallback
    }

    /// Check if on-device ML extraction is available
    public var isMLAvailable: Bool {
        get async {
            guard useMLFallback else { return false }

            if #available(iOS 18.0, macOS 15.0, *) {
                let parser = MLRecipeParser()
                return await parser.isAvailable
            }
            return false
        }
    }

    /// Extract a recipe from a URL
    /// - Parameter url: The URL of the recipe page
    /// - Returns: Extraction result with recipe, source, and confidence
    public func extractRecipe(from url: URL) async throws -> ExtractionResult {
        // Fetch the HTML content
        let html = try await fetchHTML(from: url)

        // Try extraction strategies in order of reliability
        return try await extractRecipe(from: html, sourceURL: url)
    }

    /// Extract a recipe from raw HTML content
    /// - Parameters:
    ///   - html: The HTML content to parse
    ///   - sourceURL: Optional source URL for the recipe
    /// - Returns: Extraction result with recipe, source, and confidence
    public func extractRecipe(from html: String, sourceURL: URL? = nil) async throws -> ExtractionResult {
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

        // Strategy 3: Fall back to on-device ML (iOS 18+)
        if useMLFallback {
            if let result = try await extractWithML(html: html, sourceURL: sourceURL) {
                return result
            }
        }

        throw ExtractionError.noRecipeFound
    }

    // MARK: - ML Extraction

    private func extractWithML(html: String, sourceURL: URL?) async throws -> ExtractionResult? {
        guard #available(iOS 18.0, macOS 15.0, *) else {
            return nil
        }

        let mlParser = MLRecipeParser()

        guard await mlParser.isAvailable else {
            return nil
        }

        if let recipe = try await mlParser.extractRecipe(fromHTML: html, sourceURL: sourceURL) {
            let confidence = assessMLConfidence(recipe)
            return ExtractionResult(
                recipe: recipe,
                source: .onDeviceML,
                confidence: confidence
            )
        }

        return nil
    }

    // MARK: - Network

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

    // MARK: - Confidence Assessment

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

    private func assessMLConfidence(_ recipe: ExtractedRecipe) -> ExtractionConfidence {
        var score = 0

        // ML extraction can be quite good when it works
        if !recipe.title.isEmpty { score += 2 }
        if recipe.ingredients.count >= 3 { score += 2 }
        if recipe.instructions.count >= 2 { score += 2 }

        // ML is less reliable than JSON-LD but can be better than HTML heuristics
        if score >= 5 {
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
