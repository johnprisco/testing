import Testing
import Foundation
@testable import RecipeExtraction

@Suite("Recipe Extractor Tests")
struct RecipeExtractorTests {

    @Test("Prefers JSON-LD over HTML parsing")
    func prefersJSONLD() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "JSON-LD Recipe Title",
                "recipeIngredient": ["Ingredient from JSON-LD"],
                "recipeInstructions": ["Instruction from JSON-LD"]
            }
            </script>
        </head>
        <body>
            <h1>HTML Recipe Title</h1>
            <ul class="ingredients">
                <li>Ingredient from HTML</li>
            </ul>
            <ol class="instructions">
                <li>Instruction from HTML</li>
            </ol>
        </body>
        </html>
        """

        let extractor = RecipeExtractor()
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        #expect(result.source == .jsonLD)
        #expect(result.recipe.title == "JSON-LD Recipe Title")
        #expect(result.recipe.ingredients.first == "Ingredient from JSON-LD")
    }

    @Test("Falls back to HTML when no JSON-LD")
    func fallsBackToHTML() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>HTML Only Recipe</title></head>
        <body>
            <h1>Pure HTML Recipe</h1>
            <h2>Ingredients</h2>
            <ul>
                <li>First ingredient</li>
                <li>Second ingredient</li>
                <li>Third ingredient</li>
            </ul>
            <h2>Instructions</h2>
            <ol>
                <li>First step of the recipe instructions.</li>
                <li>Second step of the recipe instructions.</li>
            </ol>
        </body>
        </html>
        """

        let extractor = RecipeExtractor()
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        #expect(result.source == .htmlParsing)
        #expect(result.recipe.title == "Pure HTML Recipe")
    }

    @Test("Throws error when no recipe found")
    func throwsWhenNoRecipe() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>About Page</title></head>
        <body>
            <h1>About Us</h1>
            <p>We are a company.</p>
        </body>
        </html>
        """

        let extractor = RecipeExtractor()

        await #expect(throws: RecipeExtractor.ExtractionError.self) {
            try await extractor.extractRecipe(from: html, sourceURL: nil)
        }
    }

    @Test("High confidence for complete JSON-LD recipe")
    func highConfidenceComplete() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Complete Recipe",
                "description": "A complete recipe with all fields",
                "image": "https://example.com/image.jpg",
                "prepTime": "PT15M",
                "cookTime": "PT30M",
                "recipeYield": "4 servings",
                "recipeIngredient": [
                    "Ingredient 1",
                    "Ingredient 2",
                    "Ingredient 3",
                    "Ingredient 4"
                ],
                "recipeInstructions": [
                    "Step 1",
                    "Step 2",
                    "Step 3"
                ]
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let extractor = RecipeExtractor()
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        #expect(result.confidence == .high)
    }

    @Test("Medium confidence for partial JSON-LD recipe")
    func mediumConfidencePartial() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Minimal Recipe",
                "recipeIngredient": ["One ingredient", "Two", "Three"],
                "recipeInstructions": ["Just one step", "And another"]
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let extractor = RecipeExtractor()
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        #expect(result.confidence == .medium || result.confidence == .low)
    }

    @Test("Sets source URL on extracted recipe")
    func setsSourceURL() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Test Recipe",
                "recipeIngredient": ["Test"],
                "recipeInstructions": ["Test"]
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let sourceURL = URL(string: "https://example.com/recipe/123")!
        let extractor = RecipeExtractor()
        let result = try await extractor.extractRecipe(from: html, sourceURL: sourceURL)

        #expect(result.recipe.sourceURL == sourceURL)
    }

    @Test("Invalid URL string throws error")
    func invalidURLThrows() async throws {
        let extractor = RecipeExtractor()

        await #expect(throws: RecipeExtractor.ExtractionError.self) {
            _ = try await extractor.extractRecipe(from: "not a valid url")
        }
    }
}
