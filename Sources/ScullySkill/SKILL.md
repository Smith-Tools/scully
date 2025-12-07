# Scully - Swift Package Documentation Skill

Scully is a Claude Code skill that provides comprehensive Swift package documentation and usage examples. It auto-triggers when you ask questions about packages and their capabilities.

## Capabilities

- **Dependency Analysis**: Parse Package.swift files and list project dependencies
- **Documentation Access**: Fetch documentation from any Swift package
- **Example Discovery**: Find code examples and playgrounds
- **Smart Summaries**: Generate concise documentation overviews
- **Pattern Extraction**: Identify common usage patterns
- **Caching**: Local caching for faster repeat access

## Usage Examples

### As a Claude Code Skill (Recommended)

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

### Integration with Smith Tools Workflow

Use scully skill in combination with smith:

```bash
# Step 1: See which packages your project uses
smith dependencies /path/to/project

# Step 2: Ask about a package (scully auto-triggers)
"What does ComposableArchitecture provide?"

# Step 3: Get package documentation and examples from scully skill
# (Returns: capabilities, examples, usage patterns, integration guides)
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