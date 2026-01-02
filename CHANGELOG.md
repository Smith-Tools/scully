# Changelog

All notable changes to Scully will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Critical Fix**: Fixed GitHubFetcher hanging issue that caused scully to get stuck when fetching documentation
  - Added proper timeout handling (30s for requests, 60s for resources)
  - Implemented fallback to GitHub HTTP API when gh CLI is not available
  - Fixed process execution to use proper async/await patterns
  - Improved error handling for network operations
  - Now works reliably in all scenarios: pipeline mode, project-deps mode, and single package mode

### Changed
- GitHubFetcher now uses hybrid approach: prefers gh CLI if available, falls back to HTTP API
- Network operations now have explicit timeouts to prevent indefinite hanging
- Better error messages for GitHub API failures
- DocC fetching now routes through `smith-doc-inspector`
- RAG database paths now use SmithRAG defaults (respects `SMITH_RAG_HOME`)

### Technical Details
The hanging issue was caused by:
1. Process-based GitHub CLI calls without timeouts
2. Poor command argument parsing
3. Synchronous Process.waitUntilExit() calls
4. No fallback mechanism when gh CLI was unavailable

The fix ensures scully will never hang and provides reliable documentation fetching regardless of environment.

## [1.1.0] - 2025-12-07

### Added
- Added `--limit` parameter to `docs` command for truncating output
- Added `--limit` and `--filter` parameters to `patterns` command
- Enhanced batch mode documentation fetching from Smith CLI

### Changed
- Improved local documentation discovery in SPM checkouts
- Better error handling for missing documentation

### Fixed
- Fixed JSON parsing issues with Smith CLI output
- Improved auto-detection of piped vs interactive input

## [1.0.0] - 2025-12-06

### Added
- Initial release of Scully - Swift ecosystem documentation tool
- Core features:
  - Package dependency analysis
  - Documentation fetching from GitHub
  - Local DocC discovery
  - Code example extraction
  - Usage pattern analysis
  - Documentation summarization
- Claude Code skill integration
- Support for batch documentation fetching via Smith CLI
- Local caching system for faster repeat access
