import Testing
import Foundation
@testable import RecipeExtraction

/// Fuzz tests to ensure parsers don't crash with malformed input
@Suite("Fuzz Tests")
struct FuzzTests {

    let jsonLDParser = JSONLDRecipeParser()
    let htmlParser = HTMLRecipeParser()

    // MARK: - Malformed HTML Tests

    @Test("Handles unclosed tags")
    func unclosedTags() throws {
        let inputs = [
            "<html><head><title>Test",
            "<html><body><div><p>Content",
            "<script>var x = 1;</script",
            "<div class='test><p>text</p></div>",
        ]

        for input in inputs {
            // Should not crash
            _ = try? jsonLDParser.extractRecipe(from: input)
            _ = try? htmlParser.extractRecipe(from: input)
        }
    }

    @Test("Handles deeply nested elements")
    func deeplyNested() throws {
        var html = "<html><body>"
        for i in 0..<100 {
            html += "<div class='level\(i)'>"
        }
        html += "Deep content"
        for _ in 0..<100 {
            html += "</div>"
        }
        html += "</body></html>"

        // Should not crash or stack overflow
        _ = try? htmlParser.extractRecipe(from: html)
    }

    @Test("Handles very long strings")
    func veryLongStrings() throws {
        let longString = String(repeating: "a", count: 100_000)
        let html = "<html><head><title>\(longString)</title></head><body><h1>\(longString)</h1></body></html>"

        // Should not crash
        _ = try? htmlParser.extractRecipe(from: html)
    }

    @Test("Handles null bytes")
    func nullBytes() throws {
        let html = "<html><body><h1>Test\0Recipe</h1></body></html>"

        // Should not crash
        _ = try? htmlParser.extractRecipe(from: html)
    }

    @Test("Handles various encodings")
    func variousEncodings() throws {
        let inputs = [
            "<html><body>Café résumé naïve</body></html>",
            "<html><body>日本語テスト</body></html>",
            "<html><body>Emoji: 🍕🥗🍰</body></html>",
            "<html><body>Mixed: Tëst Rëcïpé 日本 🎂</body></html>",
        ]

        for input in inputs {
            _ = try? htmlParser.extractRecipe(from: input)
        }
    }

    // MARK: - Malformed JSON-LD Tests

    @Test("Handles invalid JSON")
    func invalidJSON() throws {
        let inputs = [
            "<script type='application/ld+json'>{not valid json}</script>",
            "<script type='application/ld+json'>{\"@type\": \"Recipe\", incomplete",
            "<script type='application/ld+json'>[{\"@type\": \"Recipe\"}</script>",
            "<script type='application/ld+json'>null</script>",
            "<script type='application/ld+json'>undefined</script>",
            "<script type='application/ld+json'>NaN</script>",
        ]

        for input in inputs {
            // Should return nil, not crash
            let result = try? jsonLDParser.extractRecipe(from: input)
            #expect(result == nil)
        }
    }

    @Test("Handles wrong types in JSON")
    func wrongTypesInJSON() throws {
        let inputs = [
            // name as number
            """
            <script type="application/ld+json">
            {"@type": "Recipe", "name": 12345, "recipeIngredient": ["a"], "recipeInstructions": ["b"]}
            </script>
            """,
            // ingredients as string
            """
            <script type="application/ld+json">
            {"@type": "Recipe", "name": "Test", "recipeIngredient": "single string", "recipeInstructions": ["b"]}
            </script>
            """,
            // prepTime as number
            """
            <script type="application/ld+json">
            {"@type": "Recipe", "name": "Test", "prepTime": 30, "recipeIngredient": ["a"], "recipeInstructions": ["b"]}
            </script>
            """,
            // nested arrays
            """
            <script type="application/ld+json">
            {"@type": "Recipe", "name": "Test", "recipeIngredient": [["nested"]], "recipeInstructions": ["b"]}
            </script>
            """,
        ]

        for input in inputs {
            // Should handle gracefully, not crash
            _ = try? jsonLDParser.extractRecipe(from: input)
        }
    }

    @Test("Handles circular-like structures")
    func circularStructures() throws {
        // JSON can't have true circular refs, but can have deep nesting
        var json = "{\"@type\": \"Recipe\", \"name\": \"Test\""
        for i in 0..<50 {
            json += ", \"nested\(i)\": {\"value\": \"test\""
        }
        for _ in 0..<50 {
            json += "}"
        }
        json += ", \"recipeIngredient\": [\"a\"], \"recipeInstructions\": [\"b\"]}"

        let html = "<script type='application/ld+json'>\(json)</script>"

        // Should not crash
        _ = try? jsonLDParser.extractRecipe(from: html)
    }

    @Test("Handles extremely large JSON")
    func largeJSON() throws {
        var ingredients: [String] = []
        for i in 0..<1000 {
            ingredients.append("Ingredient \(i)")
        }

        var instructions: [String] = []
        for i in 0..<500 {
            instructions.append("Step \(i): Do something with the ingredients.")
        }

        let json = """
        {
            "@type": "Recipe",
            "name": "Giant Recipe",
            "recipeIngredient": \(try! JSONEncoder().encode(ingredients).base64EncodedString()),
            "recipeInstructions": \(try! JSONEncoder().encode(instructions).base64EncodedString())
        }
        """
        // Actually use proper JSON
        let properJSON = """
        {
            "@type": "Recipe",
            "name": "Giant Recipe",
            "recipeIngredient": [\(ingredients.map { "\"\($0)\"" }.joined(separator: ","))],
            "recipeInstructions": [\(instructions.map { "\"\($0)\"" }.joined(separator: ","))]
        }
        """

        let html = "<script type='application/ld+json'>\(properJSON)</script>"

        // Should not crash, may be slow
        _ = try? jsonLDParser.extractRecipe(from: html)
    }

    // MARK: - Edge Case Inputs

    @Test("Handles empty input")
    func emptyInput() throws {
        let inputs = ["", " ", "\n", "\t", "\r\n"]

        for input in inputs {
            let jsonResult = try? jsonLDParser.extractRecipe(from: input)
            let htmlResult = try? htmlParser.extractRecipe(from: input)
            #expect(jsonResult == nil)
            #expect(htmlResult == nil)
        }
    }

    @Test("Handles binary-like content")
    func binaryContent() throws {
        // Simulate binary garbage
        var bytes = Data()
        for _ in 0..<1000 {
            bytes.append(UInt8.random(in: 0...255))
        }
        let garbage = String(data: bytes, encoding: .utf8) ?? ""

        // Should not crash
        _ = try? jsonLDParser.extractRecipe(from: garbage)
        _ = try? htmlParser.extractRecipe(from: garbage)
    }

    @Test("Handles script injection attempts")
    func scriptInjection() throws {
        let inputs = [
            "<script>alert('xss')</script><script type='application/ld+json'>{\"@type\":\"Recipe\",\"name\":\"<script>alert(1)</script>\"}</script>",
            "<html><body><h1 onclick='alert(1)'>Recipe</h1></body></html>",
            "<img src=x onerror=alert(1)>",
        ]

        for input in inputs {
            // Should not crash (XSS is handled at display layer, not parsing)
            _ = try? jsonLDParser.extractRecipe(from: input)
            _ = try? htmlParser.extractRecipe(from: input)
        }
    }

    // MARK: - Randomized Fuzz Tests

    @Test("Random mutations don't crash JSON-LD parser")
    func randomMutationsJSONLD() throws {
        let baseHTML = """
        <script type="application/ld+json">
        {"@type":"Recipe","name":"Test","recipeIngredient":["a","b"],"recipeInstructions":["c"]}
        </script>
        """

        for _ in 0..<100 {
            var mutated = baseHTML
            let mutation = Int.random(in: 0..<5)

            switch mutation {
            case 0:
                // Remove random character
                if let index = mutated.indices.randomElement() {
                    mutated.remove(at: index)
                }
            case 1:
                // Insert random character
                if let index = mutated.indices.randomElement() {
                    mutated.insert(Character(UnicodeScalar(Int.random(in: 32..<127))!), at: index)
                }
            case 2:
                // Duplicate random section
                let start = mutated.index(mutated.startIndex, offsetBy: Int.random(in: 0..<mutated.count/2))
                let end = mutated.index(start, offsetBy: min(10, mutated.distance(from: start, to: mutated.endIndex)))
                let section = mutated[start..<end]
                mutated.insert(contentsOf: section, at: start)
            case 3:
                // Truncate
                let newLength = Int.random(in: 1..<mutated.count)
                mutated = String(mutated.prefix(newLength))
            default:
                // Reverse a section
                break
            }

            // Should not crash
            _ = try? jsonLDParser.extractRecipe(from: mutated)
        }
    }

    @Test("Random mutations don't crash HTML parser")
    func randomMutationsHTML() throws {
        let baseHTML = """
        <html><body><h1>Recipe</h1><ul class="ingredients"><li>A</li></ul><ol class="instructions"><li>B</li></ol></body></html>
        """

        for _ in 0..<100 {
            var mutated = baseHTML
            let mutation = Int.random(in: 0..<4)

            switch mutation {
            case 0:
                if let index = mutated.indices.randomElement() {
                    mutated.remove(at: index)
                }
            case 1:
                if let index = mutated.indices.randomElement() {
                    mutated.insert("<", at: index)
                }
            case 2:
                if let index = mutated.indices.randomElement() {
                    mutated.insert(">", at: index)
                }
            default:
                let newLength = Int.random(in: 1..<mutated.count)
                mutated = String(mutated.prefix(newLength))
            }

            // Should not crash
            _ = try? htmlParser.extractRecipe(from: mutated)
        }
    }
}
