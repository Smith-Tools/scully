---
name: scully
description: Search third-party Swift package documentation and SPM dependencies from Tuist Registry and Swift Package Index. Use for Package.swift analysis, ComposableArchitecture (TCA), Alamofire, RxSwift, Kingfisher, Apollo-iOS, swift-nio, SwiftyBeaver, Nimble, Point-Free, Yams, async-http-client, and other non-Apple packages. Automatically triggers when working with Swift Package Manager, analyzing dependencies, asking about third-party library patterns, or requesting information about TCA, networking libraries, reactive programming, GraphQL, image handling, or other non-Apple frameworks. Does NOT cover Apple frameworks (use sosumi for Apple APIs).
allowed-tools: Bash, Read, Glob, Grep, WebFetch
---

# Scully - Swift Package Documentation Tool

Scully is a comprehensive tool for analyzing Swift packages and accessing their documentation. It works both as a CLI tool and as a Claude Code skill for intelligent documentation discovery.

**Automatically triggered for:**
- ✅ Third-party package questions ("What does Alamofire do?" "How do I use Yams?" "RxSwift tutorials?" "Apollo-iOS GraphQL?")
- ✅ SPM dependency exploration ("Analyze Package.swift" "List dependencies" "Check Tuist Registry packages")
- ✅ Non-Apple library research ("Find swift-nio examples" "ComposableArchitecture patterns" "Point-Free guides" "async-http-client setup")
- ✅ Popular libraries ("Kingfisher caching" "SwiftyBeaver logging" "Nimble testing" "RxSwift reactive patterns")
- ✅ Modern Swift packages ("async-http-client for networking" "apollo-ios for GraphQL" "kingdom patterns")
- ✅ Dependency version management ("What versions does swift-argument-parser support?")
- ✅ Package integration patterns ("How do X and Y third-party libs work together?")
- ✅ Direct scully recommendations ("use scully for search if needed" "check scully for TCA docs")

**Does NOT trigger for:**
- ❌ Apple frameworks (SwiftUI, Combine as Apple API) → use sosumi instead
- ❌ WWDC sessions or Apple documentation → use sosumi instead
- ❌ iOS SDK APIs → use sosumi instead

## Capabilities

- **Dependency Analysis**: Parse Package.swift files and list project dependencies
- **Documentation Access**: Fetch documentation from any Swift package
- **Example Discovery**: Find code examples and playgrounds
- **Smart Summaries**: Generate concise documentation overviews
- **Pattern Extraction**: Identify common usage patterns
- **Caching**: Local caching for faster repeat access

## Usage Examples

### As a Claude Code Skill (Recommended in Claude Code)

Scully auto-triggers when you ask questions about packages:

```
"What does ComposableArchitecture provide?"
  → scully auto-triggers with package capabilities

"Show me examples for Combine error handling"
  → scully auto-triggers with code examples

"How do I use Alamofire for networking?"
  → scully auto-triggers with usage patterns

"Does [Package] have [feature]?"
  → scully auto-triggers with capability check
```

### As a CLI Tool (Recommended in terminal)

Use scully directly from the command line:

```bash
# List all dependencies in current project
scully list

# Get detailed dependency listing with versions and URLs
scully list --detailed

# Access documentation for a specific package
scully docs Alamofire

# Find code examples for a package
scully examples Combine

# Find examples with a specific keyword
scully examples Combine --filter "error handling"

# Generate a summary of package documentation
scully summary SwiftCharts

# Extract common usage patterns
scully patterns ComposableArchitecture

# Filter patterns by frequency threshold
scully patterns ComposableArchitecture --threshold 5
```

### Integration with Smith Tools Workflow

Use scully in combination with smith tools:

```bash
# Step 1: See which packages your project uses
smith dependencies /path/to/project

# Step 2: Use scully CLI to explore packages
scully list --detailed

# Step 3: Get documentation for packages of interest
scully docs ComposableArchitecture
scully examples ComposableArchitecture

# Alternative in Claude Code: Ask about packages
# "What does ComposableArchitecture provide?"
# (scully skill auto-triggers automatically)
```

## Data Sources

- **GitHub Repositories**: Primary source for package information and documentation
- **Swift Package Index**: Package discovery through packages.json
- **Local Caching**: Faster repeat access with intelligent caching

## Features

### Smart Documentation Retrieval
- Automatically finds README files
- Locates DocC documentation when available
- Follows common documentation patterns

### Context-Aware Analysis
- Analyzes current project dependencies
- Provides relevant suggestions based on usage
- Prioritizes frequently used packages

### Efficient Caching
- In-memory cache for immediate access
- Persistent disk cache for between-sessions
- Automatic cache expiration management

## Integration

Scully integrates seamlessly with:
- **Smith Tools ecosystem**: As a standalone CLI tool
- **Claude Code**: As an intelligent skill for documentation access
- **Swift Package Manager**: For manifest analysis
- **GitHub API**: For repository information fetching

## Configuration

Scully can be configured through:
- Environment variables (e.g., `GITHUB_TOKEN` for API access)
- Configuration files in `~/.config/scully/`
- Command-line flags for one-time settings