# Code Quality Tools

This page documents the code quality and automation tools used in this repository to maintain consistent,
high-quality documentation.

## Overview

The homelab documentation uses several automated tools to ensure consistent formatting, catch errors,
and maintain quality standards. These tools run automatically on every commit via git hooks.

## Pre-commit Framework

### What is Pre-commit?

[Pre-commit](https://pre-commit.com/) is a framework for managing and maintaining multi-language pre-commit hooks.
It automatically runs a set of checks every time you commit changes, catching issues before they reach the repository.

### Configuration File: `.pre-commit-config.yaml`

The repository includes a `.pre-commit-config.yaml` file that defines which tools to run:

```yaml
repos:
  # General file quality hooks
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace        # Remove trailing whitespace
      - id: end-of-file-fixer         # Ensure files end with newline
      - id: check-yaml                # Validate YAML files
      - id: check-added-large-files   # Prevent large files
      - id: check-case-conflict       # Check for case conflicts
      - id: check-merge-conflict      # Check for merge conflict markers
      - id: mixed-line-ending         # Ensure consistent line endings

  # Documentation-specific tools
  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.41.0
    hooks:
      - id: markdownlint
        args: ['--fix']

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v4.0.0-alpha.8
    hooks:
      - id: prettier
        files: \.(ya?ml|json)$
        args: ['--write']

  - repo: https://github.com/crate-ci/typos
    rev: v1.24.3
    hooks:
      - id: typos
```

### Why These Tools?

Each tool serves a specific purpose:

- **File Quality**: Prevents common file formatting issues
- **Markdown Linting**: Ensures consistent markdown formatting
- **YAML/JSON Formatting**: Keeps configuration files neat
- **Spell Checking**: Catches typos in documentation

### Installation and Usage

```bash
# Install pre-commit
pip install pre-commit

# Install the hooks
pre-commit install

# Run on all files (optional)
pre-commit run --all-files

# Run on staged files only (happens automatically on commit)
pre-commit run
```

## Markdown Linting: markdownlint

### What is markdownlint?

[Markdownlint](https://github.com/igorshubovych/markdownlint-cli) is a tool that checks markdown files
for style and formatting consistency. It helps maintain readable and well-structured documentation.

### Configuration File: `.markdownlint.json`

The repository includes a `.markdownlint.json` file that customizes the linting rules:

```json
{
  "MD013": {
    "line_length": 120,
    "code_blocks": false,
    "tables": false,
    "headings": false
  },
  "MD036": false,
  "MD040": false,
  "MD041": false,
  "MD033": false
}
```

### Why This Configuration?

#### Line Length (MD013)

- **120 characters**: Modern screens can handle longer lines than the default 80
- **Exclude code blocks**: Long URLs and code shouldn't break arbitrarily
- **Exclude tables**: Table formatting needs flexibility
- **Exclude headings**: Heading readability is more important than length

#### Disabled Rules

- **MD036**: Allow emphasis instead of headings (useful for notes and emphasis)
- **MD040**: Don't require language specification for all code blocks
- **MD041**: Allow documents without top-level headings
- **MD033**: Allow HTML in markdown (needed for complex layouts)

### Common Markdownlint Rules

| Rule | Description | Status |
|------|-------------|---------|
| MD013 | Line length | ✅ Enabled (120 chars) |
| MD022 | Headers surrounded by blank lines | ✅ Enabled |
| MD025 | Single top level header | ✅ Enabled |
| MD036 | Emphasis used as header | ❌ Disabled |
| MD040 | Fenced code language | ❌ Disabled |

### Benefits of Consistent Markdown

- **Readability**: Consistent formatting is easier to read
- **Maintainability**: Standardized structure is easier to maintain
- **Collaboration**: Team members can focus on content, not formatting
- **Professional**: Well-formatted documentation looks more professional

## Spell Checking: typos

### What is typos?

[Typos](https://github.com/crate-ci/typos) is a fast spell checker that finds and corrects common typos
in source code and documentation.

### Why typos over other spell checkers?

- **Fast**: Rust-based tool is extremely fast
- **Developer-focused**: Understands code and technical terms
- **Low false positives**: Smart about technical terminology
- **Easy to configure**: Simple configuration for custom terms

### Usage

```bash
# Check for typos (happens automatically in pre-commit)
typos

# Check specific files
typos docs/

# Fix typos automatically (use with caution)
typos --write-changes
```

## Prettier for YAML/JSON

### What is Prettier?

[Prettier](https://prettier.io/) is an opinionated code formatter that automatically formats files
to ensure consistency.

### Configuration for This Repository

We use Prettier specifically for:

- **YAML files**: `mkdocs.yml`, `.pre-commit-config.yaml`
- **JSON files**: `.markdownlint.json`, any configuration files

### Benefits

- **Consistency**: All YAML/JSON files follow the same formatting rules
- **Automatic**: No need to manually format configuration files
- **Readable**: Clean, consistent indentation and structure

## Benefits of Automated Quality Checks

### For Contributors

- **Immediate Feedback**: Catch issues before they're committed
- **Learning**: Tools help learn best practices
- **Consistency**: Focus on content, not formatting rules

### For Maintainers

- **Quality Assurance**: Consistent quality across all contributions
- **Time Saving**: Less time reviewing formatting issues
- **Professional Standards**: Documentation meets professional standards

### For Readers

- **Better Experience**: Consistent, well-formatted documentation
- **Reliability**: Fewer typos and formatting issues
- **Professional Appearance**: Polished, trustworthy documentation

## Troubleshooting Quality Tools

### Pre-commit Issues

**Problem**: Hooks not running

```bash
# Solution: Ensure hooks are installed
pre-commit install
```

**Problem**: Specific hook failing

```bash
# Solution: Run individual hook for detailed output
pre-commit run markdownlint --all-files --verbose
```

### Markdownlint Issues

**Problem**: Too many line length errors

```bash
# Solution: Check .markdownlint.json configuration
cat .markdownlint.json
# Adjust line_length value if needed
```

**Problem**: False positive rules

```bash
# Solution: Disable specific rules in .markdownlint.json
{
  "MD999": false  // Disable rule MD999
}
```

### Typos Issues

**Problem**: False positive technical terms

```bash
# Solution: Create _typos.toml configuration
[default.extend-words]
kubectl = "kubectl"
homelab = "homelab"
```

## Customizing Tools

### Adding New Pre-commit Hooks

1. Find the hook in the [pre-commit hooks repository](https://pre-commit.com/hooks.html)
2. Add to `.pre-commit-config.yaml`
3. Update hooks: `pre-commit autoupdate`
4. Test: `pre-commit run --all-files`

### Modifying Markdown Rules

1. Edit `.markdownlint.json`
2. Test changes: `markdownlint docs/`
3. Document changes in this file

### Example: Adding a New Rule

```yaml
# In .pre-commit-config.yaml
- repo: https://github.com/pre-commit/mirrors-eslint
  rev: v8.57.0
  hooks:
    - id: eslint
      files: \.js$
```

## Best Practices

### Tool Selection

- **Choose mature tools**: Stick to well-maintained, popular tools
- **Minimal configuration**: Use defaults when possible
- **Document exceptions**: Explain why rules are disabled
- **Regular updates**: Keep tool versions current

### Configuration Management

- **Version control**: Always commit configuration files
- **Document changes**: Explain configuration decisions
- **Test thoroughly**: Run on all files after configuration changes
- **Share knowledge**: Document setup for team members

---

*These quality tools ensure that the homelab documentation maintains high standards of consistency,
accuracy, and professionalism.*
