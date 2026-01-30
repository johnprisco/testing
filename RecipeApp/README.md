# RecipeApp

[![CI](https://github.com/johnprisco/testing/actions/workflows/ci.yml/badge.svg)](https://github.com/johnprisco/testing/actions/workflows/ci.yml)

An iOS 18 app for saving and managing recipes, featuring intelligent on-device recipe extraction from any website.

## Features

- **Smart Recipe Extraction**: Automatically extracts recipes from websites using multiple strategies:
  1. JSON-LD structured data (schema.org/Recipe)
  2. HTML parsing with common patterns
  3. On-device ML fallback (iOS 18+ with Apple Silicon)

- **100% On-Device**: All extraction happens locally—no server required
- **SwiftData Persistence**: Modern data storage with iOS 17+ SwiftData
- **Confidence Scoring**: Know how reliable the extraction is

## Requirements

- iOS 18.0+ / macOS 15.0+
- Xcode 16.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/johnprisco/testing.git", from: "1.0.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Usage

### Basic Extraction

```swift
import RecipeExtraction

let extractor = RecipeExtractor()

// Extract from URL
let result = try await extractor.extractRecipe(from: recipeURL)

print(result.recipe.title)           // "Chocolate Chip Cookies"
print(result.recipe.ingredients)     // ["2 cups flour", "1 cup sugar", ...]
print(result.recipe.instructions)    // ["Preheat oven...", "Mix dry ingredients...", ...]
print(result.source)                 // .jsonLD, .htmlParsing, or .onDeviceML
print(result.confidence)             // .high, .medium, or .low
```

### Convert to SwiftData Model

```swift
// Convert extracted recipe to SwiftData model for persistence
let recipe = result.recipe.toRecipe()
modelContext.insert(recipe)
```

### Check ML Availability

```swift
let extractor = RecipeExtractor()

if await extractor.isMLAvailable {
    print("On-device ML extraction is available")
}

// Disable ML fallback for faster/deterministic results
let fastExtractor = RecipeExtractor(useMLFallback: false)
```

## Architecture

```
RecipeApp/
├── Models/
│   ├── Recipe.swift              # SwiftData models
│   └── ExtractedRecipe.swift     # Extraction DTOs
├── Services/
│   ├── RecipeExtractor.swift     # Main extraction orchestrator
│   ├── JSONLDRecipeParser.swift  # Schema.org JSON-LD parser
│   ├── HTMLRecipeParser.swift    # Fallback HTML parser
│   └── MLRecipeParser.swift      # Foundation Models parser (iOS 18+)
└── Package.swift
```

## Testing

```bash
# Run all tests
cd RecipeApp
swift test

# Run specific test suite
swift test --filter PerformanceTests

# Run with verbose output
swift test -v --parallel
```

### Test Coverage

| Suite | Tests | Description |
|-------|-------|-------------|
| Unit Tests | 30+ | Individual component validation |
| Fixture Tests | 11 | Real-world HTML samples |
| Snapshot Tests | 8 | Regression detection |
| Fuzz Tests | 15 | Crash resistance |
| Performance Tests | 8 | Speed benchmarks |

## Extraction Strategies

### 1. JSON-LD (Preferred)

Most recipe websites include structured data following the [schema.org Recipe specification](https://schema.org/Recipe). This provides the most reliable extraction.

### 2. HTML Parsing (Fallback)

When no structured data exists, the parser looks for common patterns:
- Microdata attributes (`itemprop="recipeIngredient"`)
- Common CSS classes (`.ingredients`, `.instructions`)
- Semantic structure (headings followed by lists)

### 3. On-Device ML (Final Fallback)

On iOS 18+ devices with Apple Silicon (A17+/M1+), Foundation Models can extract recipes from unstructured text when other methods fail.

## License

MIT License - see LICENSE file for details.
