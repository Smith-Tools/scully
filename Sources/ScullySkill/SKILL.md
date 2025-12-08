---
name: scully
description: Search third-party Swift package documentation and analyze Swift Package Manager dependencies. Covers non-Apple packages from Tuist Registry and Swift Package Index including Alamofire, RxSwift, Kingfisher, Apollo-iOS, swift-nio, SwiftyBeaver, Nimble, Point-Free libraries, Yams, async-http-client, and ComposableArchitecture (TCA). Analyzes Package.swift manifests and dependency relationships. Use for package capabilities, integration patterns, code examples, and API documentation. TRIGGERS ON: third-party package questions, SPM dependencies, Package.swift analysis, library documentation, non-Apple framework questions, package integration patterns. Does NOT cover Apple frameworks—use sosumi for SwiftUI, Combine, UIKit, AppKit, Apple documentation, and WWDC sessions.
allowed-tools: Bash, Read, Glob, Grep, WebFetch
---


# Scully - Swift Package Documentation Tool

Scully analyzes Swift packages and provides documentation from cached repositories. It works by finding dependencies, searching cache, detecting DocC documentation, and cloning repositories when needed.

## How to Use This Skill

**IMPORTANT**: When this skill triggers, you MUST run the `scully` CLI command. Do NOT do web searches instead.

### Package Documentation Queries

When user asks about a package (e.g., "What does Alamofire do?", "How do I use RxSwift?"):

```bash
scully docs [PackageName]
```

Limit output size (default: 2000 chars):
```bash
scully docs [PackageName] --limit 5000
```
*Note: Like `sosumi`'s verbosity levels, Scully truncates by default to fit agent context. Use larger limits or `--limit 0` (unlimited) for "full" verbosity.*

This will:
1. Search for the package in the cache
2. Check for DocC documentation
3. Clone the repository if not cached
4. Return README and documentation

### Code Examples

When user asks for examples (e.g., "Show me Kingfisher examples", "Alamofire usage"):

```bash
scully examples [PackageName]
```

Optionally filter examples:
```bash
scully examples [PackageName] --filter "keyword"
```

### Package Summary

When user asks "What does X provide?" or "X capabilities":

```bash
scully summary [PackageName]
```

### Usage Patterns

When user asks about common patterns or best practices:

```bash
scully patterns [PackageName]
```

Optionally filter patterns:
```bash
scully patterns [PackageName] --filter "keyword"
```

Limit the number of patterns (default: 20):
```bash
scully patterns [PackageName] --limit 50
```

### List Project Dependencies

When user asks about project dependencies or Package.swift:

```bash
scully list
```

Or for detailed output:
```bash
scully list --detailed
```

## Automatically Triggered For

- ✅ Third-party package questions ("What does Alamofire do?")
- ✅ Package capabilities ("Does RxSwift support X?")
- ✅ Code examples ("Show me Kingfisher usage")
- ✅ SPM dependencies ("Analyze Package.swift")
- ✅ Non-Apple libraries (swift-nio, Apollo-iOS, etc.)
- ✅ ComposableArchitecture (TCA) questions
- ✅ Point-Free libraries
- ✅ Package integration patterns

## Does NOT Trigger For

- ❌ Apple frameworks → use sosumi instead
- ❌ SwiftUI/Combine (as Apple APIs) → use sosumi
- ❌ WWDC sessions → use sosumi
- ❌ iOS SDK questions → use sosumi

## How Scully Works

1. **Dependency Detection**: Parses Package.swift to find dependencies
2. **Cache Search**: Checks local cache for package information
3. **DocC Detection**: Looks for DocC documentation in the package
4. **Repository Cloning**: Clones repo if not in cache
5. **Documentation Extraction**: Extracts README, guides, and examples

## Data Sources

- **Local Cache**: `~/.scully/cache/` for previously fetched packages
- **GitHub**: Primary source for package repositories
- **Swift Package Index**: Package discovery via packages.json
- **Tuist Registry**: Additional package sources

## Example Workflows

### Understand a Package

User: "What does Alamofire do?"

```bash
scully docs Alamofire
```

Returns: README, key features, API overview

### Find Integration Examples

User: "How do I use Kingfisher for image caching?"

```bash
scully examples Kingfisher --filter "caching"
```

Returns: Code examples showing caching patterns

### Analyze Project Dependencies

User: "What packages does my project use?"

```bash
scully list --detailed
```

Returns: All dependencies with versions and URLs

### Learn Package Patterns

User: "What are common RxSwift patterns?"

```bash
scully patterns RxSwift
```

Returns: Frequently used patterns with examples

## Integration with Smith Tools

Use scully in combination with other Smith tools:

```bash
# Step 1: See which packages your project uses
smith dependencies /path/to/project

# Step 2: Get documentation for packages of interest
scully docs ComposableArchitecture
scully examples ComposableArchitecture

# Step 3: Get Apple framework docs if needed
sosumi docs NavigationStack
```

## Configuration

Scully can be configured through:
- Environment variables (e.g., `GITHUB_TOKEN` for API access)
- Configuration files in `~/.config/scully/`
- Command-line flags for one-time settings

## Cache Management

Scully maintains a local cache at `~/.scully/cache/`:
- Cloned repositories
- Extracted documentation
- Package metadata

Cache expires after 24 hours by default.