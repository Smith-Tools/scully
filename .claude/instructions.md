# scully Development Workflow

scully is the package documentation explorer. It surfaces what your dependencies provide, their capabilities, and usage examples.

## Context Gathering Workflow

### 1. Understand Your Project Dependencies

Start with project analysis:

```bash
smith dependencies /path/to/your-project
```

This shows:
- Which packages you depend on
- How critical each package is (dependency ranking)
- How many files import each package

### 2. Explore Package Capabilities

When you need to understand what a dependency provides:

scully auto-triggers on package questions to provide:
- Package documentation
- API reference and examples
- Common usage patterns
- Available functionality
- Integration patterns

### 3. Cross-Reference with Other Tools

Combine scully with:
- **smith**: See which packages matter in your project
- **sosumi**: Get Apple docs for frameworks
- **maxwell**: See how you've used packages before

### 4. Learn Package Capabilities

scully provides:
- What the package does and provides
- Code examples from the package
- Common integration patterns
- Best practices for using the package
- Known limitations or gotchas

## Example: Understand ComposableArchitecture

Task: "How do I use ComposableArchitecture for navigation?"

```
Step 1: smith dependencies
   → See TCA is imported 50+ times
   → TCA score 98.5 (critical dependency)

Step 2: scully skill (auto-triggers)
   → Query: "ComposableArchitecture navigation"
   → Get: Available navigation features
   → See: Example implementations

Step 3: sosumi docs NavigationStack
   → Get Apple's NavigationStack API

Step 4: maxwell skill
   → See past TCA navigation implementations

Step 5: Implement
   → Use TCA navigation features
   → Follow Apple patterns
   → Reference past implementations
```

## Example: Choose Between Alternatives

Task: "Should I use Combine or async/await for this?"

```
Step 1: smith dependencies
   → See what's already imported
   → Check version constraints

Step 2: scully skill
   → Query: "Combine vs async/await"
   → Get: When to use each approach

Step 3: sosumi wwdc
   → Get Apple engineering guidance

Step 4: maxwell skill
   → See past decisions in similar situations

Step 5: Decide and implement
   → Informed by package capabilities and past patterns
```

## Example: Learn Package API

Task: "How does this dependency handle errors?"

```
Step 1: scully skill (auto-triggers)
   → Search: "Package name error handling"
   → Get: Available error types
   → See: Example error handling code

Step 2: Implement
   → Follow package's error handling pattern
   → Reference package documentation
```

## Quick Reference

| Need | How scully Helps |
|------|------------------|
| Package capabilities | Shows what package provides |
| Usage examples | Provides code examples |
| Best practices | Surfaces recommended patterns |
| Integration | Explains how to integrate |
| Alternatives | Compares similar packages |

## How scully Works

scully analyzes package documentation:
- Searches package readme files
- Indexes API documentation
- Provides example code
- Explains capabilities
- Shows integration patterns

## Example: scully Discovery

When you ask about a package:

```
Query: "What does ComposableArchitecture provide?"

scully returns:
- Core concepts: Store, Reducer, State, Action
- Navigation: NavigationStackReducer, NavigationPath
- Testing: TestStore for reducer testing
- Examples: Implementation patterns
- Docs: Link to official documentation
```

## Key Principles

✅ **Understand capabilities first**: Know what package provides
✅ **Cross-reference with smith**: See how you use the package
✅ **Use official examples**: Package examples are authoritative
✅ **Combine with personal knowledge**: maxwell shows your past patterns

## Integration with Smith Tools

When you need complete package context:

1. `smith dependencies` → See project dependencies
2. scully skill → Understand package capabilities (auto-triggers)
3. `sosumi docs <framework>` → Get Apple docs for related frameworks
4. maxwell skill → See past implementations using package

## Common Package Queries

- "What does [Package] provide?"
- "How do I use [Package] for [feature]?"
- "Does [Package] have [capability]?"
- "How do I integrate [Package]?"
- "[Package1] vs [Package2] - which should I use?"

## Documentation

For the complete integration architecture, see:
**Smith-Tools/AGENT-INTEGRATION.md**
