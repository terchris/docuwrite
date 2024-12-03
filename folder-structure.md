# DocuWrite Project Structure

```
docuwrite/
├── .devcontainer/                  # Development container configuration
│   ├── devcontainer.json          # VSCode devcontainer settings
│   └── Dockerfile.dev             # Development environment setup
├── .github/
│   └── workflows/                 # GitHub Actions workflows
│       └── docker-image.yml       # Multi-arch container build
├── src/
│   ├── cli/                       # Command-line tools
│   │   ├── typescript/            # TypeScript source files
│   │   │   ├── commands/         # Individual CLI commands
│   │   │   │   └── markdownToHtml.ts  # Example command
│   │   │   ├── utils/           # Shared utilities
│   │   │   └── types/           # TypeScript type definitions
│   │   └── bash/                 # Bash script tools
│   │       └── docuwrite-md2html.sh # Wrapper for markdown to HTML command
│   └── web/                       # Future Next.js web interface
├── dist/                          # Compiled JavaScript output
│   └── cli/                       # Compiled CLI tools
│       └── commands/             # Compiled command files
├── docker/
│   ├── Dockerfile.prod           # Production container build
│   └── docuwrite-entrypoint.sh   # Extended entrypoint script
├── tests/
│   ├── cli/                      # CLI tool tests
│   │   ├── typescript/          # TypeScript tests
│   │   │   └── markdownToHtml.test.ts  # Tests for markdown command
│   │   └── bash/               # Bash script tests
│   └── fixtures/                 # Test fixture files
├── .gitignore                     # Git ignore file
├── package.json                   # Node.js package configuration
├── tsconfig.json                  # TypeScript configuration
└── README.md                      # Project documentation
```

## Key Files Description

### Configuration Files
- `devcontainer.json`: Configures VS Code development container settings
- `Dockerfile.dev`: Development environment with TypeScript tools
- `Dockerfile.prod`: Production build that extends docuwrite-base
- `tsconfig.json`: TypeScript compiler configuration
- `package.json`: Node.js project configuration and scripts

### Source Code
- `src/cli/typescript/commands/markdownToHtml.ts`: Example TypeScript command for converting markdown to HTML
- `src/cli/bash/docuwrite-md2html`: Bash wrapper script for the markdown converter

### Docker
- `docker/docuwrite-entrypoint.sh`: Extended entrypoint script that preserves base functionality
- `docker/Dockerfile.prod`: Production container configuration

### Tests
- `tests/cli/typescript/markdownToHtml.test.ts`: Tests for the markdown converter
- `tests/fixtures/`: Directory for test input files and expected outputs

## Build Outputs

### Development Container
- Full TypeScript development environment
- Based on docuwrite-base
- Includes all source files and development tools

### Production Container
- Extends docuwrite-base
- Contains only compiled JavaScript and bash scripts
- Preserves all original docuwrite-base functionality
- Adds new document processing commands

## Workflow

1. Development is done in the dev container
2. TypeScript files are compiled to JavaScript in `dist/`
3. Production container includes only the compiled code
4. GitHub Actions handles multi-architecture builds