import Testing
import Foundation
@testable import RecipeExtraction

/// Tests using real-world HTML fixtures
@Suite("Fixture-Based Tests")
struct FixtureTests {

    // MARK: - Helper

    func loadFixture(_ name: String) throws -> String {
        // Get the bundle for the test target
        let testBundle = Bundle(for: BundleToken.self)

        // Try to find fixture in bundle
        if let url = testBundle.url(forResource: name, withExtension: "html", subdirectory: "Fixtures") {
            return try String(contentsOf: url, encoding: .utf8)
        }

        // Fallback: try relative path (for SPM)
        let fixturesPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).html")

        return try String(contentsOf: fixturesPath, encoding: .utf8)
    }

    // MARK: - WPRM Style Recipe Tests

    @Test("Parses WPRM-style recipe with full JSON-LD")
    func parseWPRMStyleRecipe() async throws {
        let html = try loadFixture("WPRMStyleRecipe")

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        #expect(result.source == .jsonLD)
        #expect(result.confidence == .high)
        #expect(result.recipe.title == "The Best Chocolate Chip Cookies")
        #expect(result.recipe.ingredients.count == 9)
        #expect(result.recipe.instructions.count == 6)
        #expect(result.recipe.prepTime == .seconds(20 * 60))
        #expect(result.recipe.cookTime == .seconds(12 * 60))
        #expect(result.recipe.category == "Dessert")
        #expect(result.recipe.cuisine == "American")
        #expect(result.recipe.author == "Jane Baker")
        #expect(result.recipe.keywords.contains("cookies"))
        #expect(result.recipe.nutrition?.calories == "150 kcal")
    }

    @Test("Extracts image from array format")
    func extractImageFromArray() async throws {
        let html = try loadFixture("WPRMStyleRecipe")

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        // Should get first image from array
        #expect(result.recipe.imageURL != nil)
        #expect(result.recipe.imageURL?.absoluteString.contains("cookies") == true)
    }

    // MARK: - Graph Format Tests

    @Test("Parses recipe from @graph array")
    func parseGraphFormatRecipe() async throws {
        let html = try loadFixture("GraphFormatRecipe")

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        #expect(result.source == .jsonLD)
        #expect(result.recipe.title == "Classic Beef Stew")
        #expect(result.recipe.ingredients.count == 13)
        #expect(result.recipe.author == "Chef Michael")
        #expect(result.recipe.prepTime == .seconds(30 * 60))
        #expect(result.recipe.cookTime == .seconds(150 * 60)) // 2h 30m
    }

    @Test("Handles HowToSection with itemListElement")
    func parseHowToSections() async throws {
        let html = try loadFixture("GraphFormatRecipe")

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        // Should flatten all sections into instructions
        #expect(result.recipe.instructions.count >= 6)
        #expect(result.recipe.instructions.first?.contains("beef") == true)
    }

    // MARK: - HTML-Only Tests

    @Test("Falls back to HTML parsing when no JSON-LD")
    func parseHTMLOnlyRecipe() async throws {
        let html = try loadFixture("HTMLOnlyRecipe")

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        #expect(result.source == .htmlParsing)
        #expect(result.recipe.title == "Grandma's Apple Pie")
        #expect(result.recipe.ingredients.count == 12)
        #expect(result.recipe.instructions.count == 9)
        #expect(result.recipe.author == "Grandma Rose")
    }

    @Test("Extracts times from datetime attributes")
    func extractTimesFromDatetime() async throws {
        let html = try loadFixture("HTMLOnlyRecipe")

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        #expect(result.recipe.prepTime == .seconds(45 * 60))
        #expect(result.recipe.cookTime == .seconds(55 * 60))
    }

    @Test("Filters out advertisement content")
    func filtersAdvertisements() async throws {
        let html = try loadFixture("HTMLOnlyRecipe")

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        // Should not include "Subscribe to newsletter" or "Advertisement"
        let allText = result.recipe.ingredients.joined() + result.recipe.instructions.joined()
        #expect(!allText.lowercased().contains("subscribe"))
        #expect(!allText.lowercased().contains("advertisement"))
    }

    // MARK: - Minimal Recipe Tests

    @Test("Handles minimal JSON-LD recipe")
    func parseMinimalRecipe() async throws {
        let html = try loadFixture("MinimalRecipe")

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        #expect(result.source == .jsonLD)
        #expect(result.recipe.title == "Quick Pasta")
        #expect(result.recipe.ingredients.count == 4)
        // Single string instruction should be parsed
        #expect(result.recipe.instructions.count >= 1)
    }

    @Test("Low confidence for minimal data")
    func lowConfidenceForMinimal() async throws {
        let html = try loadFixture("MinimalRecipe")

        let extractor = RecipeExtractor(useMLFallback: false)
        let result = try await extractor.extractRecipe(from: html, sourceURL: nil)

        // Minimal data should result in lower confidence
        #expect(result.confidence == .low || result.confidence == .medium)
    }
}

// Helper class to get test bundle
private class BundleToken {}
