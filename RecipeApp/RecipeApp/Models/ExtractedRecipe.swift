import Foundation

/// Raw recipe data extracted from a webpage, before conversion to SwiftData model
public struct ExtractedRecipe: Sendable, Equatable {
    public var title: String
    public var description: String?
    public var sourceURL: URL?
    public var imageURL: URL?
    public var ingredients: [String]
    public var instructions: [String]
    public var prepTime: Duration?
    public var cookTime: Duration?
    public var totalTime: Duration?
    public var servings: String?
    public var yield: String?
    public var author: String?
    public var datePublished: Date?
    public var cuisine: String?
    public var category: String?
    public var keywords: [String]
    public var nutrition: ExtractedNutrition?

    public init(
        title: String,
        description: String? = nil,
        sourceURL: URL? = nil,
        imageURL: URL? = nil,
        ingredients: [String] = [],
        instructions: [String] = [],
        prepTime: Duration? = nil,
        cookTime: Duration? = nil,
        totalTime: Duration? = nil,
        servings: String? = nil,
        yield: String? = nil,
        author: String? = nil,
        datePublished: Date? = nil,
        cuisine: String? = nil,
        category: String? = nil,
        keywords: [String] = [],
        nutrition: ExtractedNutrition? = nil
    ) {
        self.title = title
        self.description = description
        self.sourceURL = sourceURL
        self.imageURL = imageURL
        self.ingredients = ingredients
        self.instructions = instructions
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.totalTime = totalTime
        self.servings = servings
        self.yield = yield
        self.author = author
        self.datePublished = datePublished
        self.cuisine = cuisine
        self.category = category
        self.keywords = keywords
        self.nutrition = nutrition
    }
}

/// Raw nutrition data extracted from a webpage
public struct ExtractedNutrition: Sendable, Equatable {
    public var calories: String?
    public var fatContent: String?
    public var saturatedFatContent: String?
    public var carbohydrateContent: String?
    public var sugarContent: String?
    public var fiberContent: String?
    public var proteinContent: String?
    public var sodiumContent: String?
    public var cholesterolContent: String?

    public init(
        calories: String? = nil,
        fatContent: String? = nil,
        saturatedFatContent: String? = nil,
        carbohydrateContent: String? = nil,
        sugarContent: String? = nil,
        fiberContent: String? = nil,
        proteinContent: String? = nil,
        sodiumContent: String? = nil,
        cholesterolContent: String? = nil
    ) {
        self.calories = calories
        self.fatContent = fatContent
        self.saturatedFatContent = saturatedFatContent
        self.carbohydrateContent = carbohydrateContent
        self.sugarContent = sugarContent
        self.fiberContent = fiberContent
        self.proteinContent = proteinContent
        self.sodiumContent = sodiumContent
        self.cholesterolContent = cholesterolContent
    }
}

// MARK: - Conversion to SwiftData Model

extension ExtractedRecipe {
    /// Convert extracted recipe data to a SwiftData Recipe model
    public func toRecipe() -> Recipe {
        let recipe = Recipe(
            title: title,
            summary: description,
            sourceURL: sourceURL,
            imageURL: imageURL,
            prepTime: prepTime,
            cookTime: cookTime,
            totalTime: totalTime,
            servings: servings,
            yield: yield,
            author: author,
            datePublished: datePublished,
            cuisine: cuisine,
            category: category,
            keywords: keywords
        )

        recipe.ingredients = ingredients.enumerated().map { index, text in
            Ingredient(text: text, order: index)
        }

        recipe.instructions = instructions.enumerated().map { index, text in
            Instruction(stepNumber: index + 1, text: text)
        }

        if let nutrition = nutrition {
            recipe.nutrition = NutritionInfo(
                calories: nutrition.calories,
                fatContent: nutrition.fatContent,
                saturatedFatContent: nutrition.saturatedFatContent,
                carbohydrateContent: nutrition.carbohydrateContent,
                sugarContent: nutrition.sugarContent,
                fiberContent: nutrition.fiberContent,
                proteinContent: nutrition.proteinContent,
                sodiumContent: nutrition.sodiumContent,
                cholesterolContent: nutrition.cholesterolContent
            )
        }

        return recipe
    }
}
