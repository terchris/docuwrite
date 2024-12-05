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
│   │   │   │   └── docuwrite-hello.ts  # Hello world test command
│   │   │   ├── utils/           # Shared utilities
│   │   │   └── types/           # TypeScript type definitions
│   │   └── bash/                 # Bash script tools
│   │       └── docuwrite-hello.sh   # Hello world test wrapper
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
│   │   │   └── docuwrite-hello.test.ts  # Tests for hello command
│   │   └── bash/               # Bash script tests
│   └── fixtures/                 # Test fixture files
├── scripts/                       # Build and test scripts
│   ├── build-ts.sh               # TypeScript build script (run in devcontainer)
│   └── build-test-docker.sh      # Docker build and test script (run on host)
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
- `src/cli/typescript/commands/docuwrite-hello.ts`: Test command implementing basic hello world functionality
- `src/cli/bash/docuwrite-hello.sh`: Bash wrapper script for hello command

### Docker
- `docker/docuwrite-entrypoint.sh`: Extended entrypoint script that preserves base functionality and adds DocuWrite commands
- `docker/Dockerfile.prod`: Production container configuration

### Tests
- `tests/cli/typescript/docuwrite-hello.test.ts`: Tests for hello world command
- `tests/fixtures/`: Directory for test input files and expected outputs

### Scripts
- `scripts/build-ts.sh`: Script for building TypeScript code (must be run inside dev container)
- `scripts/build-test-docker.sh`: Script for building and testing Docker container (must be run on host machine)

## Build Outputs

### Development Container
- Full TypeScript development environment
- Based on docuwrite-base
- Includes all source files and development tools
- Used for TypeScript development and testing

### Production Container
- Extends docuwrite-base
- Contains only compiled JavaScript and bash scripts
- Preserves all original docuwrite-base functionality
- Adds DocuWrite commands like docuwrite-hello

## Workflow

1. Development is done in the dev container
2. `build-ts.sh` is run inside the dev container to compile TypeScript to JavaScript
3. `build-test-docker.sh` is run on the host machine to build and test the production container
4. Production container includes only the compiled code
5. GitHub Actions handles multi-architecture builds