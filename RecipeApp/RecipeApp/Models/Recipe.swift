import Foundation
import SwiftData

/// A recipe extracted from a website or entered manually
@Model
public final class Recipe {
    public var id: UUID
    public var title: String
    public var summary: String?
    public var sourceURL: URL?
    public var imageURL: URL?

    @Relationship(deleteRule: .cascade)
    public var ingredients: [Ingredient]

    @Relationship(deleteRule: .cascade)
    public var instructions: [Instruction]

    public var prepTime: Duration?
    public var cookTime: Duration?
    public var totalTime: Duration?
    public var servings: String?
    public var yield: String?

    public var author: String?
    public var datePublished: Date?
    public var dateAdded: Date

    public var cuisine: String?
    public var category: String?
    public var keywords: [String]

    @Relationship(deleteRule: .cascade)
    public var nutrition: NutritionInfo?

    public var notes: String?
    public var isFavorite: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        sourceURL: URL? = nil,
        imageURL: URL? = nil,
        ingredients: [Ingredient] = [],
        instructions: [Instruction] = [],
        prepTime: Duration? = nil,
        cookTime: Duration? = nil,
        totalTime: Duration? = nil,
        servings: String? = nil,
        yield: String? = nil,
        author: String? = nil,
        datePublished: Date? = nil,
        dateAdded: Date = Date(),
        cuisine: String? = nil,
        category: String? = nil,
        keywords: [String] = [],
        nutrition: NutritionInfo? = nil,
        notes: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
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
        self.dateAdded = dateAdded
        self.cuisine = cuisine
        self.category = category
        self.keywords = keywords
        self.nutrition = nutrition
        self.notes = notes
        self.isFavorite = isFavorite
    }
}

/// An ingredient with optional quantity and unit
@Model
public final class Ingredient {
    public var id: UUID
    public var text: String
    public var quantity: String?
    public var unit: String?
    public var name: String?
    public var notes: String?
    public var order: Int

    public init(
        id: UUID = UUID(),
        text: String,
        quantity: String? = nil,
        unit: String? = nil,
        name: String? = nil,
        notes: String? = nil,
        order: Int = 0
    ) {
        self.id = id
        self.text = text
        self.quantity = quantity
        self.unit = unit
        self.name = name
        self.notes = notes
        self.order = order
    }
}

/// A single instruction step
@Model
public final class Instruction {
    public var id: UUID
    public var stepNumber: Int
    public var text: String
    public var imageURL: URL?

    public init(
        id: UUID = UUID(),
        stepNumber: Int,
        text: String,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.stepNumber = stepNumber
        self.text = text
        self.imageURL = imageURL
    }
}

/// Nutrition information per serving
@Model
public final class NutritionInfo {
    public var id: UUID
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
        id: UUID = UUID(),
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
        self.id = id
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
