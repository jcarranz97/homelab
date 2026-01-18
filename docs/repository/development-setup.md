# Development Setup

This page documents how to set up the development environment for contributing to this homelab documentation.

## Getting Started

### Prerequisites

- **Python 3.8+**: For running MkDocs
- **Git**: For version control
- **Node.js** (optional): For some pre-commit hooks

### Initial Setup

1. **Clone the repository**:

   ```bash
   git clone https://github.com/jcarranz97/homelab.git
   cd homelab
   ```

2. **Create a virtual environment**:

   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**:

   ```bash
   pip install mkdocs-material
   ```

4. **Install development tools**:

   ```bash
   pip install pre-commit
   pre-commit install
   ```

## Development Workflow

### Running the Documentation Locally

Start the development server:

```bash
mkdocs serve
```

The documentation will be available at `http://localhost:8000` with hot reload enabled.
Any changes to markdown files will automatically refresh the browser.

### Making Changes

1. **Create a new branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**: Edit markdown files in the `docs/` directory

3. **Test locally**: Verify changes look good with `mkdocs serve`

4. **Run quality checks**:

   ```bash
   pre-commit run --all-files
   ```

5. **Commit and push**:

   ```bash
   git add .
   git commit -m "Add: description of changes"
   git push origin feature/your-feature-name
   ```

### Building the Documentation

To build static files for deployment:

```bash
mkdocs build
```

This creates a `site/` directory with the built documentation.

## File Structure

```
homelab/
├── docs/                          # Documentation content
│   ├── index.md                  # Homepage
│   ├── infrastructure/           # Infrastructure documentation
│   ├── services/                # Service documentation
│   ├── guides/                  # How-to guides
│   ├── troubleshooting/         # Problem solving
│   ├── reference/               # Quick reference
│   └── repository/              # This section
├── mkdocs.yml                    # MkDocs configuration
├── .pre-commit-config.yaml       # Code quality automation
├── .markdownlint.json           # Markdown linting rules
├── .gitignore                   # Git ignore patterns
└── README.md                    # Repository overview
```

## Documentation Standards

### Markdown Guidelines

- Use **120 characters** maximum line length
- Use **ATX-style headers** (`# Header` not `Header\n======`)
- Include **descriptive alt text** for images
- Use **relative links** for internal references

### Content Organization

- **Clear hierarchy**: Use proper heading levels (H1 → H2 → H3)
- **Consistent structure**: Follow the established section patterns
- **Cross-references**: Link between related sections
- **Code examples**: Include practical, working examples

### File Naming

- Use **kebab-case** for file names: `getting-started.md`
- Keep names **descriptive** but **concise**
- Use **consistent naming** within each section

## Quality Assurance

### Automated Checks

Every commit is automatically checked for:

- Markdown formatting consistency
- Spelling mistakes
- Trailing whitespace
- File formatting

### Manual Review

Before submitting changes:

- [ ] Content is accurate and up-to-date
- [ ] Links work correctly
- [ ] Code examples are tested
- [ ] Screenshots are current (if applicable)
- [ ] Writing is clear and concise

## Troubleshooting Development Issues

### MkDocs Issues

**Problem**: `mkdocs serve` fails to start

```bash
# Solution: Check Python and dependency versions
python --version
pip list | grep mkdocs
```

**Problem**: Changes not reflecting in browser

```bash
# Solution: Hard refresh or restart server
# Ctrl+Shift+R (or Cmd+Shift+R on Mac)
# Or restart: Ctrl+C then mkdocs serve
```

### Pre-commit Issues

**Problem**: Pre-commit hooks failing

```bash
# Solution: Run hooks manually to see details
pre-commit run --all-files --verbose
```

**Problem**: Hook installation issues

```bash
# Solution: Reinstall hooks
pre-commit clean
pre-commit install
```

### Git Issues

**Problem**: Large file warnings

```bash
# Solution: Check what's being committed
git status
git ls-files --others
```

## Contributing Guidelines

### Content Contributions

- **Stay on topic**: Focus on homelab-related content
- **Be practical**: Include real examples and working code
- **Be accurate**: Test configurations before documenting
- **Be helpful**: Write for someone learning the topic

### Style Guidelines

- **Use active voice** where possible
- **Be concise** but thorough
- **Use consistent terminology** throughout
- **Include context** for commands and configurations

### Review Process

1. Changes are reviewed for technical accuracy
2. Writing style and clarity are evaluated
3. Links and code examples are tested
4. Integration with existing content is verified

## Getting Help

### Documentation Issues

- Check existing [troubleshooting guides](../troubleshooting/common-issues.md)
- Review [MkDocs documentation](https://www.mkdocs.org/)
- Look at [Material theme docs](https://squidfunk.github.io/mkdocs-material/)

### Technical Issues

- Check [repository issues](https://github.com/jcarranz97/homelab/issues)
- Review [development tools documentation](code-quality.md)
- Consult the [technologies overview](technologies.md)

---

*This documentation setup follows modern technical writing best practices and ensures consistent,
high-quality documentation for the homelab project.*
