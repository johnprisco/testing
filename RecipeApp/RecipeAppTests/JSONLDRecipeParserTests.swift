import Testing
import Foundation
@testable import RecipeExtraction

@Suite("JSON-LD Recipe Parser Tests")
struct JSONLDRecipeParserTests {

    let parser = JSONLDRecipeParser()

    @Test("Parses complete recipe from JSON-LD")
    func parseCompleteRecipe() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@context": "https://schema.org/",
                "@type": "Recipe",
                "name": "Classic Chocolate Chip Cookies",
                "description": "The best homemade chocolate chip cookies recipe.",
                "image": "https://example.com/cookies.jpg",
                "author": {
                    "@type": "Person",
                    "name": "Jane Baker"
                },
                "datePublished": "2024-01-15",
                "prepTime": "PT15M",
                "cookTime": "PT12M",
                "totalTime": "PT27M",
                "recipeYield": "24 cookies",
                "recipeCategory": "Dessert",
                "recipeCuisine": "American",
                "recipeIngredient": [
                    "2 1/4 cups all-purpose flour",
                    "1 tsp baking soda",
                    "1 tsp salt",
                    "1 cup butter, softened",
                    "3/4 cup granulated sugar",
                    "3/4 cup packed brown sugar",
                    "2 large eggs",
                    "2 tsp vanilla extract",
                    "2 cups chocolate chips"
                ],
                "recipeInstructions": [
                    {
                        "@type": "HowToStep",
                        "text": "Preheat oven to 375°F (190°C)."
                    },
                    {
                        "@type": "HowToStep",
                        "text": "Mix flour, baking soda, and salt in a bowl."
                    },
                    {
                        "@type": "HowToStep",
                        "text": "Beat butter and sugars until creamy."
                    },
                    {
                        "@type": "HowToStep",
                        "text": "Add eggs and vanilla to butter mixture."
                    },
                    {
                        "@type": "HowToStep",
                        "text": "Gradually blend in flour mixture. Stir in chocolate chips."
                    },
                    {
                        "@type": "HowToStep",
                        "text": "Drop rounded tablespoons onto ungreased cookie sheets."
                    },
                    {
                        "@type": "HowToStep",
                        "text": "Bake for 9 to 11 minutes or until golden brown."
                    }
                ],
                "nutrition": {
                    "@type": "NutritionInformation",
                    "calories": "150 calories",
                    "fatContent": "8g",
                    "carbohydrateContent": "20g",
                    "proteinContent": "2g"
                }
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.title == "Classic Chocolate Chip Cookies")
        #expect(recipe?.description == "The best homemade chocolate chip cookies recipe.")
        #expect(recipe?.imageURL?.absoluteString == "https://example.com/cookies.jpg")
        #expect(recipe?.author == "Jane Baker")
        #expect(recipe?.ingredients.count == 9)
        #expect(recipe?.instructions.count == 7)
        #expect(recipe?.prepTime == .seconds(15 * 60))
        #expect(recipe?.cookTime == .seconds(12 * 60))
        #expect(recipe?.totalTime == .seconds(27 * 60))
        #expect(recipe?.yield == "24 cookies")
        #expect(recipe?.category == "Dessert")
        #expect(recipe?.cuisine == "American")
        #expect(recipe?.nutrition?.calories == "150 calories")
        #expect(recipe?.nutrition?.fatContent == "8g")
    }

    @Test("Parses recipe from @graph array")
    func parseRecipeFromGraph() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@context": "https://schema.org",
                "@graph": [
                    {
                        "@type": "WebPage",
                        "name": "Recipe Page"
                    },
                    {
                        "@type": "Recipe",
                        "name": "Simple Pasta",
                        "recipeIngredient": ["200g pasta", "Salt", "Olive oil"],
                        "recipeInstructions": ["Boil water", "Cook pasta", "Drain and serve"]
                    }
                ]
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.title == "Simple Pasta")
        #expect(recipe?.ingredients.count == 3)
        #expect(recipe?.instructions.count == 3)
    }

    @Test("Handles string instructions array")
    func parseStringInstructions() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Quick Salad",
                "recipeIngredient": ["Lettuce", "Tomatoes", "Dressing"],
                "recipeInstructions": [
                    "Wash and chop lettuce.",
                    "Slice tomatoes.",
                    "Combine and add dressing."
                ]
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.instructions.count == 3)
        #expect(recipe?.instructions[0] == "Wash and chop lettuce.")
    }

    @Test("Handles multiple @type values")
    func parseMultipleTypes() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": ["Recipe", "HowTo"],
                "name": "Multi-Type Recipe",
                "recipeIngredient": ["Ingredient 1"],
                "recipeInstructions": ["Step 1"]
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.title == "Multi-Type Recipe")
    }

    @Test("Parses duration correctly")
    func parseDurations() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Duration Test",
                "prepTime": "PT1H30M",
                "cookTime": "PT45M",
                "totalTime": "PT2H15M",
                "recipeIngredient": ["Test"],
                "recipeInstructions": ["Test"]
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.prepTime == .seconds(90 * 60))  // 1h 30m
        #expect(recipe?.cookTime == .seconds(45 * 60))  // 45m
        #expect(recipe?.totalTime == .seconds(135 * 60)) // 2h 15m
    }

    @Test("Returns nil for non-recipe JSON-LD")
    func noRecipeInJSONLD() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Article",
                "name": "Blog Post",
                "author": "Someone"
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe == nil)
    }

    @Test("Returns nil for page without JSON-LD")
    func noJSONLD() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Regular Page</title></head>
        <body><p>Just a regular page</p></body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe == nil)
    }

    @Test("Handles malformed JSON gracefully")
    func malformedJSON() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            { this is not valid json }
            </script>
        </head>
        <body></body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe == nil)
    }

    @Test("Extracts keywords from comma-separated string")
    func parseKeywordsString() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Tagged Recipe",
                "keywords": "easy, quick, weeknight, healthy",
                "recipeIngredient": ["Test"],
                "recipeInstructions": ["Test"]
            }
            </script>
        </head>
        <body></body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.keywords.count == 4)
        #expect(recipe?.keywords.contains("easy") == true)
        #expect(recipe?.keywords.contains("healthy") == true)
    }
}
