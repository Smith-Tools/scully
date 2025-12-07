# Scully + Smith Integration

## Clean Separation of Concerns

### Smith: Project Analysis
- Detects project type (Xcode/SPM)
- Analyzes dependency graphs
- Finds circular dependencies
- Parses `Package.resolved`
- **Outputs**: JSON list of dependencies

### Scully: Documentation Fetching
- Finds local DocC (SPM checkouts, build artifacts)
- Caches documentation
- Fetches from GitHub
- Searches Swift Package Index
- **Inputs**: Package names (from args or stdin)
- **Outputs**: Documentation

## Usage Patterns

### Pattern 1: Single Package
```bash
# Get docs for one package
scully docs Alamofire
```

### Pattern 2: Batch Mode (Auto-detected! 🎯)
```bash
# Smith analyzes project, scully fetches docs
# No --batch flag needed - it auto-detects piped input!
smith dependencies --format=json | scully docs
```

### Pattern 3: Save and Reuse
```bash
# Save dependency list
smith dependencies --format=json > deps.json

# Fetch docs later (auto-detects stdin)
cat deps.json | scully docs
```

## How It Works

### Auto-Detection (CLIG-Compliant)
Scully automatically detects whether stdin is:
- **Interactive (TTY)**: Expects package name as argument
- **Piped data**: Reads JSON from stdin

No flags needed - it just works! ✨

## How It Works

### Step 1: Smith Analyzes
```bash
$ smith dependencies --format=json
{
  "dependencies": [
    {"name": "Alamofire", "version": "5.8.0", ...},
    {"name": "RxSwift", "version": "6.6.0", ...}
  ]
}
```

### Step 2: Scully Fetches Docs
```bash
$ smith dependencies --format=json | scully docs

📦 Fetching documentation for 2 packages...

─────────────────────────────────────────────────
📚 Alamofire
─────────────────────────────────────────────────
# Alamofire

Elegant HTTP Networking in Swift

## Features

- Chainable Request / Response Methods
- URL / JSON Parameter Encoding
...

🔗 Source: /path/to/.build/checkouts/Alamofire/README.md

─────────────────────────────────────────────────
📚 RxSwift
─────────────────────────────────────────────────
# RxSwift: ReactiveX for Swift

RxSwift is a Swift version of Rx...
...

✅ Batch documentation fetch complete
```

## Performance

### Local Documentation (Instant ⚡)
Priority search order:
1. **SPM checkouts** (`.build/checkouts/[package]/`)
2. **Build artifacts** (`.build/*/[package].doccarchive`)
3. **Cached clones** (`~/Library/Scully/Cache/clones/`)
4. **DerivedData** (Xcode builds)

### Remote Fetching (When Needed)
1. **Package list cache** (24-hour expiry)
2. **GitHub fetch** (only if not local)

## Migration from Old Pattern

### Before (Smith did everything)
```bash
smith dependencies --with-docs  # ❌ Deprecated
```

### After (Clean separation with auto-detection)
```bash
smith dependencies --format=json | scully docs  # ✅ CLIG-compliant
```

## Why This Design?

### Follows CLIG Guidelines
- ✅ **Simple parts that work together**: Each tool does ONE thing
- ✅ **Composability**: Standard JSON piping
- ✅ **No tight coupling**: Tools work independently
- ✅ **Human-first**: Clear, focused commands

### Clear Responsibilities
- **Smith**: "What packages does my project use?"
- **Scully**: "Show me documentation for these packages"

### Future-Proof
- Smith can focus on analysis features
- Scully can add more documentation sources
- Easy to add new tools to the pipeline
