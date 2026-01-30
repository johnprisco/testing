import Testing
import Foundation
@testable import RecipeExtraction

/// Performance tests to ensure extraction is fast enough for on-device use
@Suite("Performance Tests")
struct PerformanceTests {

    // MARK: - Test Data

    let simpleJSONLD = """
    <!DOCTYPE html>
    <html>
    <head>
        <script type="application/ld+json">
        {
            "@type": "Recipe",
            "name": "Simple Recipe",
            "recipeIngredient": ["Flour", "Sugar", "Eggs"],
            "recipeInstructions": ["Mix", "Bake"]
        }
        </script>
    </head>
    <body></body>
    </html>
    """

    let complexJSONLD: String = {
        var ingredients: [String] = []
        for i in 1...30 {
            ingredients.append("Ingredient \(i) - 1 cup")
        }

        var instructions: [[String: String]] = []
        for i in 1...20 {
            instructions.append([
                "@type": "HowToStep",
                "text": "Step \(i): This is a detailed instruction that explains what to do in this step of the recipe preparation process."
            ])
        }

        let instructionsJSON = instructions.map { dict in
            "{\"@type\": \"\(dict["@type"]!)\", \"text\": \"\(dict["text"]!)\"}"
        }.joined(separator: ",")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@context": "https://schema.org",
                "@type": "Recipe",
                "name": "Complex Gourmet Recipe",
                "description": "A complex recipe with many ingredients and detailed instructions for testing performance.",
                "image": "https://example.com/image.jpg",
                "author": {"@type": "Person", "name": "Chef Test"},
                "datePublished": "2024-01-15",
                "prepTime": "PT45M",
                "cookTime": "PT2H",
                "totalTime": "PT2H45M",
                "recipeYield": "8 servings",
                "recipeCategory": "Main Course",
                "recipeCuisine": "International",
                "keywords": "complex, gourmet, testing, performance",
                "recipeIngredient": [\(ingredients.map { "\"\($0)\"" }.joined(separator: ","))],
                "recipeInstructions": [\(instructionsJSON)],
                "nutrition": {
                    "@type": "NutritionInformation",
                    "calories": "500 kcal",
                    "fatContent": "20g",
                    "proteinContent": "25g",
                    "carbohydrateContent": "50g"
                }
            }
            </script>
        </head>
        <body>
            <h1>Complex Gourmet Recipe</h1>
        </body>
        </html>
        """
    }()

    let largeHTML: String = {
        var html = "<!DOCTYPE html><html><head><title>Large Page</title></head><body>"
        html += "<header><nav>"
        for i in 1...20 {
            html += "<a href='/page\(i)'>Link \(i)</a>"
        }
        html += "</nav></header>"

        // Add lots of content before the recipe
        for i in 1...50 {
            html += "<div class='content-block'><h2>Section \(i)</h2><p>\(String(repeating: "Lorem ipsum dolor sit amet. ", count: 20))</p></div>"
        }

        html += "<article><h1>The Recipe</h1>"
        html += "<h2>Ingredients</h2><ul>"
        for i in 1...15 {
            html += "<li itemprop='recipeIngredient'>Ingredient \(i)</li>"
        }
        html += "</ul>"
        html += "<h2>Instructions</h2><ol>"
        for i in 1...10 {
            html += "<li>Step \(i): Detailed instruction text here.</li>"
        }
        html += "</ol></article>"

        // Add more content after
        for i in 1...30 {
            html += "<div class='comment'><p>Comment \(i): Great recipe!</p></div>"
        }

        html += "<footer><p>Copyright 2024</p></footer></body></html>"
        return html
    }()

    // MARK: - JSON-LD Parser Performance

    @Test("JSON-LD parser handles simple recipe quickly")
    func jsonLDSimplePerformance() throws {
        let parser = JSONLDRecipeParser()

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<100 {
            _ = try parser.extractRecipe(from: simpleJSONLD)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let averageMs = (elapsed / 100) * 1000
        #expect(averageMs < 10, "Simple JSON-LD parsing should take less than 10ms on average, took \(averageMs)ms")
    }

    @Test("JSON-LD parser handles complex recipe in reasonable time")
    func jsonLDComplexPerformance() throws {
        let parser = JSONLDRecipeParser()

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<50 {
            _ = try parser.extractRecipe(from: complexJSONLD)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let averageMs = (elapsed / 50) * 1000
        #expect(averageMs < 50, "Complex JSON-LD parsing should take less than 50ms on average, took \(averageMs)ms")
    }

    // MARK: - HTML Parser Performance

    @Test("HTML parser handles large page in reasonable time")
    func htmlLargePagePerformance() throws {
        let parser = HTMLRecipeParser()

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<20 {
            _ = try parser.extractRecipe(from: largeHTML)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let averageMs = (elapsed / 20) * 1000
        #expect(averageMs < 100, "Large HTML parsing should take less than 100ms on average, took \(averageMs)ms")
    }

    @Test("HTML parser doesn't degrade with page size")
    func htmlScalingPerformance() throws {
        let parser = HTMLRecipeParser()

        // Create pages of increasing size
        let sizes = [10, 50, 100]
        var times: [Int: Double] = [:]

        for size in sizes {
            var html = "<html><body><h1>Recipe</h1><ul class='ingredients'>"
            for i in 1...size {
                html += "<li>Ingredient \(i)</li>"
            }
            html += "</ul><ol class='instructions'>"
            for i in 1...size {
                html += "<li>Step \(i)</li>"
            }
            html += "</ol></body></html>"

            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<10 {
                _ = try parser.extractRecipe(from: html)
            }
            times[size] = (CFAbsoluteTimeGetCurrent() - start) / 10
        }

        // Time should scale roughly linearly, not exponentially
        // 100 items should not take more than 20x the time of 10 items
        if let time10 = times[10], let time100 = times[100] {
            let ratio = time100 / time10
            #expect(ratio < 20, "Performance should scale reasonably. 100 items took \(ratio)x longer than 10 items")
        }
    }

    // MARK: - Full Extractor Performance

    @Test("Full extraction pipeline is fast enough for interactive use")
    func fullExtractionPerformance() async throws {
        let extractor = RecipeExtractor(useMLFallback: false)

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<20 {
            _ = try await extractor.extractRecipe(from: complexJSONLD, sourceURL: nil)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let averageMs = (elapsed / 20) * 1000
        // Should be fast enough that user doesn't notice delay
        #expect(averageMs < 100, "Full extraction should take less than 100ms on average, took \(averageMs)ms")
    }

    @Test("Extraction with HTML fallback is still responsive")
    func htmlFallbackPerformance() async throws {
        let extractor = RecipeExtractor(useMLFallback: false)

        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<10 {
            _ = try await extractor.extractRecipe(from: largeHTML, sourceURL: nil)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        let averageMs = (elapsed / 10) * 1000
        #expect(averageMs < 200, "HTML fallback extraction should take less than 200ms on average, took \(averageMs)ms")
    }

    // MARK: - Memory Tests

    @Test("Parsing doesn't retain excessive memory")
    func memoryUsage() throws {
        let parser = JSONLDRecipeParser()

        // Parse many times and ensure we're not leaking
        for _ in 0..<1000 {
            _ = try parser.extractRecipe(from: complexJSONLD)
        }

        // If we got here without running out of memory, we're good
        // In a real scenario, you'd use Instruments or XCTest's memory metrics
    }

    // MARK: - Concurrent Performance

    @Test("Parser handles concurrent requests")
    func concurrentPerformance() async throws {
        let parser = JSONLDRecipeParser()

        let start = CFAbsoluteTimeGetCurrent()

        await withTaskGroup(of: ExtractedRecipe?.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    try? parser.extractRecipe(from: self.simpleJSONLD)
                }
            }

            var count = 0
            for await result in group {
                if result != nil {
                    count += 1
                }
            }
            #expect(count == 100, "All concurrent parses should succeed")
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - start
        #expect(elapsed < 5, "100 concurrent parses should complete in less than 5 seconds, took \(elapsed)s")
    }
}
