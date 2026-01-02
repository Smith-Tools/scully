# Scully

Swift ecosystem analysis and documentation tool

## Stability Status
✅ **Production Ready** - Recent critical fixes ensure reliable operation
- Fixed hanging issues during documentation fetching
- Added proper timeout handling (30s/60s)
- Implemented fallback to GitHub HTTP API
- All pipeline modes working correctly

## Overview

Scully is a comprehensive tool for analyzing Swift packages and accessing their documentation. It operates both as a standalone Smith Tool and as a Claude Code skill, making it easy to explore the Swift ecosystem and understand package dependencies.

## Features

- **Dependency Analysis**: Parse Package.swift files and list project dependencies (automatic fallback to `smith` for Xcode/Unknown projects)
- **Documentation Access**: Fetch documentation from any Swift package
- **DocC Extraction**: Generic DocC fetch via `smith-doc-inspector`
- **Example Discovery**: Find code examples and playgrounds
- **Smart Summaries**: Generate concise documentation overviews
- **Pattern Extraction**: Identify common usage patterns
- **Efficient Caching**: Local caching for faster repeat access

## Installation

### As a Smith Tool

```bash
cd scully
swift build -c release
```

### As a Claude Code Skill

Copy the skill to your Claude skills directory:
```bash
cp -r Sources/ScullySkill ~/.claude/skills/scully
```

## Usage

### CLI (Smith Tool)

```bash
# List dependencies in current project
scully list

# Detailed listing with versions
scully list --detailed

# Access documentation
scully docs Alamofire

# Find specific version
scully docs Alamofire@5.8.0

# Find code examples
scully examples Combine

# Generate documentation summary
scully summary Alamofire

# Extract usage patterns
scully patterns SwiftCharts
scully patterns ComposableArchitecture --filter "navigation" --limit 10

# JSON output
scully list --format json

# Pipe from smith (Unified Analysis)
smith dependencies --format=json | scully docs --limit 5000
```

### Claude Code Skill

```
List dependencies in current project
Show documentation for Alamofire
Find examples for Combine
Generate summary for SwiftCharts
Extract patterns from Alamofire
```

## Architecture

Scully is built with a modular architecture:

- **ScullyCLI**: Command-line interface for standalone operation
- **ScullyCore**: Core functionality and data models
- **ScullyAnalysis**: Package manifest analysis
- **ScullyFetch**: Content acquisition from GitHub and SPI
- **ScullyProcess**: Documentation processing and summarization
- **ScullyDatabase**: Caching and search functionality
- **ScullySkill**: Claude Code skill integration

## Data Sources

- **GitHub Repositories**: Primary source for package information
- **Swift Package Index**: Package discovery through packages.json

## Development

### Building

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Development Mode

```bash
swift run scully --help
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Integration with Smith Tools

Scully is part of the Smith Tools ecosystem and integrates seamlessly with other tools like:

- **Smith CLI**: Unified Smith Tools interface
- **Smith Validation**: TCA validation and analysis
- **Maxwell**: Personal knowledge and discoveries
- **Smith Doc Inspector**: Generic DocC fetch and repo example discovery

## Configuration

Scully can be configured through:

- Environment variables (e.g., `GITHUB_TOKEN` for API access)
- RAG database location via `SMITH_RAG_HOME` (defaults to `~/.smith/rag`)
- Configuration files in `~/.config/scully/`
- Command-line flags for one-time settings
