# Scully - Swift Package Documentation Tool

Scully is a comprehensive tool for analyzing Swift packages and accessing their documentation. It works both as a CLI tool and as a Claude Code skill for intelligent documentation discovery.

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