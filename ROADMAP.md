# Scully Roadmap

## Future Enhancements

### Agent Context Optimization
- **Pagination/Offset Support**: Implement `--offset` and `--limit` flags across all text-heavy commands (`docs`, `examples`, `patterns`).
  - *Goal*: Allow agents to "scroll" through large content (like long READMEs or extensive pattern lists) without exceeding token context windows in a single turn.
  - *Design*: Standard offset-based pagination (e.g., `--offset 5000 --limit 2000` to read chars 5000-7000).

### Feature Requests
- [x] Add `--limit` to `docs` command (Implemented v1.1)
- [x] Add `--limit` and `--filter` to `patterns` command (Implemented v1.1)
