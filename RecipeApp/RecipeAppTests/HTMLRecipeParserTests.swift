import Testing
import Foundation
@testable import RecipeExtraction

@Suite("HTML Recipe Parser Tests")
struct HTMLRecipeParserTests {

    let parser = HTMLRecipeParser()

    @Test("Parses recipe with itemprop attributes")
    func parseItemPropRecipe() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Recipe - My Blog</title></head>
        <body>
            <article>
                <h1 itemprop="name">Homemade Pizza</h1>
                <p itemprop="description">A delicious homemade pizza recipe.</p>
                <img itemprop="image" src="https://example.com/pizza.jpg">
                <span itemprop="author">Chef Mario</span>
                <span itemprop="recipeYield">4 servings</span>
                <ul>
                    <li itemprop="recipeIngredient">2 cups flour</li>
                    <li itemprop="recipeIngredient">1 cup water</li>
                    <li itemprop="recipeIngredient">1 tsp yeast</li>
                    <li itemprop="recipeIngredient">1 tsp salt</li>
                    <li itemprop="recipeIngredient">Tomato sauce</li>
                    <li itemprop="recipeIngredient">Mozzarella cheese</li>
                </ul>
                <ol itemprop="recipeInstructions">
                    <li>Mix flour, water, yeast, and salt to form dough.</li>
                    <li>Let dough rise for 1 hour.</li>
                    <li>Roll out dough and add toppings.</li>
                    <li>Bake at 450°F for 15 minutes.</li>
                </ol>
            </article>
        </body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.title == "Homemade Pizza")
        #expect(recipe?.description == "A delicious homemade pizza recipe.")
        #expect(recipe?.author == "Chef Mario")
        #expect(recipe?.servings == "4 servings")
        #expect(recipe?.ingredients.count == 6)
        #expect(recipe?.instructions.count == 4)
    }

    @Test("Parses recipe with class-based selectors")
    func parseClassBasedRecipe() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Banana Bread Recipe</title></head>
        <body>
            <div class="recipe">
                <h1 class="recipe-title">Banana Bread</h1>
                <p class="recipe-description">Moist and delicious banana bread.</p>
                <div class="recipe-ingredients">
                    <ul>
                        <li>3 ripe bananas</li>
                        <li>1/3 cup melted butter</li>
                        <li>1 cup sugar</li>
                        <li>1 egg</li>
                        <li>1 tsp vanilla</li>
                        <li>1 tsp baking soda</li>
                        <li>1.5 cups flour</li>
                    </ul>
                </div>
                <div class="recipe-instructions">
                    <ol>
                        <li>Preheat oven to 350°F.</li>
                        <li>Mash bananas in a bowl.</li>
                        <li>Mix in melted butter.</li>
                        <li>Add sugar, egg, and vanilla.</li>
                        <li>Mix in baking soda and flour.</li>
                        <li>Pour into greased loaf pan.</li>
                        <li>Bake for 60-65 minutes.</li>
                    </ol>
                </div>
            </div>
        </body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.title == "Banana Bread")
        #expect(recipe?.ingredients.count == 7)
        #expect(recipe?.instructions.count == 7)
    }

    @Test("Finds lists after ingredient heading")
    func parseListsAfterHeading() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Simple Soup</title></head>
        <body>
            <article>
                <h1>Simple Vegetable Soup</h1>

                <h2>Ingredients</h2>
                <ul>
                    <li>4 cups vegetable broth</li>
                    <li>2 carrots, diced</li>
                    <li>2 celery stalks, diced</li>
                    <li>1 onion, diced</li>
                    <li>Salt and pepper to taste</li>
                </ul>

                <h2>Instructions</h2>
                <ol>
                    <li>Sauté onion, carrots, and celery until soft.</li>
                    <li>Add vegetable broth and bring to boil.</li>
                    <li>Reduce heat and simmer for 20 minutes.</li>
                    <li>Season with salt and pepper.</li>
                </ol>
            </article>
        </body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.title == "Simple Vegetable Soup")
        #expect(recipe?.ingredients.count == 5)
        #expect(recipe?.instructions.count == 4)
    }

    @Test("Extracts time from datetime attribute")
    func parseTimeWithDatetime() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Quick Recipe</title></head>
        <body>
            <h1>Quick Stir Fry</h1>
            <span class="prep-time" itemprop="prepTime" datetime="PT10M">10 mins</span>
            <span class="cook-time" itemprop="cookTime" datetime="PT15M">15 mins</span>
            <h2>Ingredients</h2>
            <ul class="ingredients">
                <li>Vegetables</li>
                <li>Sauce</li>
                <li>Rice</li>
            </ul>
            <h2>Directions</h2>
            <ol class="instructions">
                <li>Prep vegetables</li>
                <li>Stir fry</li>
                <li>Serve over rice</li>
            </ol>
        </body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.prepTime == .seconds(10 * 60))
        #expect(recipe?.cookTime == .seconds(15 * 60))
    }

    @Test("Returns nil for page without recipe content")
    func noRecipeContent() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>About Us</title></head>
        <body>
            <h1>About Our Company</h1>
            <p>We are a company that does things.</p>
            <p>Contact us at email@example.com</p>
        </body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe == nil)
    }

    @Test("Filters out advertisement text from ingredients")
    func filtersAdvertisementText() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <h1>Test Recipe</h1>
            <h2>Ingredients</h2>
            <ul class="ingredients">
                <li>1 cup flour</li>
                <li>Subscribe to our newsletter for more recipes!</li>
                <li>1 cup sugar</li>
                <li>Click here for special offers</li>
                <li>2 eggs</li>
            </ul>
            <h2>Instructions</h2>
            <ol>
                <li>Mix all ingredients together.</li>
                <li>Bake at 350F.</li>
            </ol>
        </body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.ingredients.count == 3)
        #expect(recipe?.ingredients.contains("1 cup flour") == true)
        #expect(recipe?.ingredients.contains("1 cup sugar") == true)
        #expect(recipe?.ingredients.contains("2 eggs") == true)
    }

    @Test("Cleans step numbers from instructions")
    func cleansStepNumbers() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <h1>Numbered Recipe</h1>
            <ul class="ingredients">
                <li>Ingredient 1</li>
                <li>Ingredient 2</li>
            </ul>
            <div class="instructions">
                <p>Step 1: First do this thing.</p>
                <p>Step 2: Then do another thing.</p>
                <p>3. Finally, do the last thing.</p>
            </div>
        </body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        // Instructions should have step numbers removed
        #expect(recipe?.instructions.first?.hasPrefix("Step") == false)
        #expect(recipe?.instructions.first?.hasPrefix("1") == false)
    }

    @Test("Extracts image from og:image meta tag")
    func extractsOGImage() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Recipe with OG Image</title>
            <meta property="og:image" content="https://example.com/recipe-image.jpg">
        </head>
        <body>
            <h1>Recipe Title</h1>
            <ul class="ingredients">
                <li>Item 1</li>
                <li>Item 2</li>
            </ul>
            <ol class="instructions">
                <li>Do something</li>
                <li>Do something else</li>
            </ol>
        </body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.imageURL?.absoluteString == "https://example.com/recipe-image.jpg")
    }

    @Test("Handles WPRM recipe plugin format")
    func parseWPRMRecipe() throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <body>
            <h1>WordPress Recipe</h1>
            <div class="wprm-recipe">
                <div class="wprm-recipe-ingredient">1 cup flour</div>
                <div class="wprm-recipe-ingredient">2 eggs</div>
                <div class="wprm-recipe-ingredient">1 cup milk</div>
                <div class="wprm-recipe-instruction">Mix dry ingredients.</div>
                <div class="wprm-recipe-instruction">Add wet ingredients.</div>
                <div class="wprm-recipe-instruction">Cook on griddle.</div>
            </div>
        </body>
        </html>
        """

        let recipe = try parser.extractRecipe(from: html)

        #expect(recipe != nil)
        #expect(recipe?.ingredients.count == 3)
        #expect(recipe?.instructions.count == 3)
    }
}
