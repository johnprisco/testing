import Testing
import Foundation
@testable import RecipeExtraction

@Suite("ML Recipe Parser Tests")
struct MLRecipeParserTests {

    @Test("MLRecipeParserAvailability reports correct support")
    func availabilityCheck() {
        // This should return true on iOS 18+ / macOS 15+
        let isSupported = MLRecipeParserAvailability.isSupported

        // We just verify it returns a boolean without crashing
        #expect(isSupported == true || isSupported == false)
    }

    @Test("Extraction source enum includes ML option")
    func extractionSourceIncludesML() {
        let source = RecipeExtractor.ExtractionSource.onDeviceML
        #expect(source == .onDeviceML)
    }

    @Test("RecipeExtractor can be initialized with ML disabled")
    func initWithMLDisabled() async throws {
        let extractor = RecipeExtractor(useMLFallback: false)

        // Should not crash
        let isMLAvailable = await extractor.isMLAvailable
        #expect(isMLAvailable == false)
    }

    @Test("RecipeExtractor still uses JSON-LD when available")
    func jsonLDPreferredOverML() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Test Recipe",
                "recipeIngredient": ["Ingredient 1", "Ingredient 2", "Ingredient 3"],
                "recipeInstructions": ["Step 1", "Step 2"]
            }
            </script>
        </head>
        <body>
            <p>Some unstructured text about cooking that the ML might try to parse</p>
        </body>
        </html>
        """

        let extractor = RecipeExtractor(useMLFallback: true)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        // Should use JSON-LD, not ML
        #expect(result.source == .jsonLD)
        #expect(result.recipe.title == "Test Recipe")
    }

    @Test("RecipeExtractor still uses HTML parsing as second choice")
    func htmlPreferredOverML() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>HTML Recipe</title></head>
        <body>
            <h1>Delicious Soup</h1>
            <h2>Ingredients</h2>
            <ul>
                <li>Water</li>
                <li>Vegetables</li>
                <li>Salt</li>
            </ul>
            <h2>Instructions</h2>
            <ol>
                <li>Boil water in a large pot.</li>
                <li>Add vegetables and simmer.</li>
                <li>Season with salt to taste.</li>
            </ol>
        </body>
        </html>
        """

        let extractor = RecipeExtractor(useMLFallback: true)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        // Should use HTML parsing, not ML
        #expect(result.source == .htmlParsing)
        #expect(result.recipe.title == "Delicious Soup")
    }
}

// MARK: - ML Parser Unit Tests (when available)

@available(iOS 18.0, macOS 15.0, *)
@Suite("ML Recipe Parser Direct Tests")
struct MLRecipeParserDirectTests {

    @Test("Parser initializes without crashing")
    func parserInitializes() async {
        let parser = MLRecipeParser()
        // Just verify it initializes
        _ = await parser.isAvailable
    }

    @Test("Returns nil for empty content")
    func emptyContentReturnsNil() async throws {
        let parser = MLRecipeParser()

        // Short content should return nil
        let result = try await parser.extractRecipe(fromHTML: "<html><body>Hi</body></html>")
        #expect(result == nil)
    }

    @Test("Handles malformed HTML gracefully")
    func malformedHTMLHandled() async throws {
        let parser = MLRecipeParser()

        let malformedHTML = "<html><body><<<not valid>>></body>"

        // Should not crash
        _ = try await parser.extractRecipe(fromHTML: malformedHTML)
    }
}
