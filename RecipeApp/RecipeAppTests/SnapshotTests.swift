import Testing
import Foundation
@testable import RecipeExtraction

/// Snapshot tests to detect unintended changes in extraction behavior
/// These tests verify specific field values haven't changed between runs
@Suite("Snapshot Tests")
struct SnapshotTests {

    // MARK: - JSON-LD Extraction Snapshots

    @Test("JSON-LD extraction produces expected structure")
    func jsonLDExtractionSnapshot() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Test Recipe",
                "description": "A test recipe for snapshots",
                "prepTime": "PT10M",
                "cookTime": "PT20M",
                "recipeYield": "4 servings",
                "recipeIngredient": [
                    "1 cup flour",
                    "2 eggs",
                    "1/2 cup milk"
                ],
                "recipeInstructions": [
                    {"@type": "HowToStep", "text": "Mix ingredients."},
                    {"@type": "HowToStep", "text": "Bake at 350F."}
                ]
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let parser = JSONLDRecipeParser()
        let recipe = try parser.extractRecipe(from: html)

        // Snapshot assertions - these should remain stable
        #expect(recipe?.title == "Test Recipe")
        #expect(recipe?.description == "A test recipe for snapshots")
        #expect(recipe?.prepTime == .seconds(600))
        #expect(recipe?.cookTime == .seconds(1200))
        #expect(recipe?.servings == "4 servings")
        #expect(recipe?.ingredients == ["1 cup flour", "2 eggs", "1/2 cup milk"])
        #expect(recipe?.instructions == ["Mix ingredients.", "Bake at 350F."])
    }

    @Test("Duration parsing produces consistent results")
    func durationParsingSnapshot() throws {
        let testCases: [(String, Int64)] = [
            ("PT5M", 5 * 60),
            ("PT1H", 60 * 60),
            ("PT1H30M", 90 * 60),
            ("PT2H15M", 135 * 60),
            ("PT45S", 45),
            ("PT1H30M45S", 90 * 60 + 45),
        ]

        for (input, expectedSeconds) in testCases {
            let html = """
            <html>
            <head>
                <script type="application/ld+json">
                {"@type": "Recipe", "name": "Test", "prepTime": "\(input)", "recipeIngredient": ["a"], "recipeInstructions": ["b"]}
                </script>
            </head>
            </html>
            """

            let parser = JSONLDRecipeParser()
            let recipe = try parser.extractRecipe(from: html)

            #expect(recipe?.prepTime == .seconds(expectedSeconds),
                   "Duration \(input) should parse to \(expectedSeconds) seconds")
        }
    }

    // MARK: - HTML Extraction Snapshots

    @Test("HTML extraction produces expected structure")
    func htmlExtractionSnapshot() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Simple Cake</title></head>
        <body>
            <article>
                <h1>Simple Cake</h1>
                <h2>Ingredients</h2>
                <ul>
                    <li>2 cups flour</li>
                    <li>1 cup sugar</li>
                    <li>3 eggs</li>
                </ul>
                <h2>Instructions</h2>
                <ol>
                    <li>Preheat oven to 350F.</li>
                    <li>Mix all ingredients.</li>
                    <li>Bake for 30 minutes.</li>
                </ol>
            </article>
        </body>
        </html>
        """

        let parser = HTMLRecipeParser()
        let recipe = try parser.extractRecipe(from: html)

        // Snapshot assertions
        #expect(recipe?.title == "Simple Cake")
        #expect(recipe?.ingredients.count == 3)
        #expect(recipe?.ingredients.contains("2 cups flour") == true)
        #expect(recipe?.instructions.count == 3)
        #expect(recipe?.instructions.first?.contains("Preheat") == true)
    }

    // MARK: - Extraction Priority Snapshots

    @Test("Extraction priority is JSON-LD first")
    func extractionPrioritySnapshot() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {"@type": "Recipe", "name": "JSON Recipe", "recipeIngredient": ["A"], "recipeInstructions": ["B"]}
            </script>
        </head>
        <body>
            <h1>HTML Recipe</h1>
            <ul class="ingredients"><li>C</li><li>D</li></ul>
            <ol class="instructions"><li>E</li><li>F</li></ol>
        </body>
        </html>
        """

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        // Should always prefer JSON-LD
        #expect(result.source == .jsonLD)
        #expect(result.recipe.title == "JSON Recipe")
    }

    // MARK: - Edge Case Snapshots

    @Test("Empty fields are handled consistently")
    func emptyFieldsSnapshot() throws {
        let html = """
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Minimal",
                "description": "",
                "prepTime": "",
                "recipeIngredient": ["One thing"],
                "recipeInstructions": ["Do it"]
            }
            </script>
        </head>
        </html>
        """

        let parser = JSONLDRecipeParser()
        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe?.title == "Minimal")
        #expect(recipe?.description == "")  // Empty string, not nil
        #expect(recipe?.prepTime == nil)     // Empty duration becomes nil
    }

    @Test("Unicode content is preserved")
    func unicodeSnapshot() throws {
        let html = """
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "日本のラーメン",
                "recipeIngredient": ["麺 200g", "チャーシュー 4枚", "ネギ 適量"],
                "recipeInstructions": ["スープを温める", "麺を茹でる"]
            }
            </script>
        </head>
        </html>
        """

        let parser = JSONLDRecipeParser()
        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe?.title == "日本のラーメン")
        #expect(recipe?.ingredients.first == "麺 200g")
    }

    @Test("Special characters in ingredients preserved")
    func specialCharactersSnapshot() throws {
        let html = """
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Test",
                "recipeIngredient": [
                    "1½ cups flour",
                    "¼ tsp salt",
                    "2–3 eggs",
                    "100°F water"
                ],
                "recipeInstructions": ["Mix"]
            }
            </script>
        </head>
        </html>
        """

        let parser = JSONLDRecipeParser()
        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe?.ingredients.contains("1½ cups flour") == true)
        #expect(recipe?.ingredients.contains("¼ tsp salt") == true)
        #expect(recipe?.ingredients.contains("2–3 eggs") == true)
    }
}
