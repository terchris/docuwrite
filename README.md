# DocuWrite

DocuWrite extends [docuwrite-base](https://github.com/terchris/docuwrite-base) with additional document processing tools. It maintains all the functionality of docuwrite-base while adding custom commands.

For base functionality and requirements, see the [docuwrite-base documentation](https://github.com/terchris/docuwrite-base).

## Architecture Support

docuwrite supports both x86_64 (AMD64) and ARM64 architectures. The container images are built automatically for both architectures and published to GitHub Container Registry. Docker will automatically select the correct architecture for your system.

## Installation

Pull the container from GitHub Container Registry:

```bash
# Latest version
docker pull ghcr.io/terchris/docuwrite:latest

# Specific version
docker pull ghcr.io/terchris/docuwrite:0.1.1
```

After you have pulled the container we give it a tag so that it is easier to use.

```bash
docker tag ghcr.io/terchris/docuwrite:latest docuwrite
```

Once the container is installed, you can use the `docuwrite` container to generate diagrams, documents, and presentations. The container mounts your project directory and processes the input files based on the selected tool. See the [docuwrite-base documentation](https://github.com/terchris/docuwrite-base) for the base commands.

Commands added by DocuWrite (all prefixed with `docuwrite-`):

```bash
docker run --rm docuwrite docuwrite-hello
docker run --rm docuwrite docuwrite-hello --verbose
```

## Development

### Prerequisites
- VS Code with Dev Containers extension
- Container runtime (Docker, Podman, or Rancher Desktop)
- Node.js and TypeScript (handled by dev container)

### Development Workflow

1. Clone and open in VS Code dev container:
```bash
git clone https://github.com/yourusername/docuwrite.git
cd docuwrite
code .
```
Then use "Reopen in Container" when prompted.

2. Build and Test:
```bash
# In dev container: Build TypeScript
./scripts/build-ts.sh

# On host: Build and test container
./scripts/build-test-docker.sh
```

### Adding New Commands

1. Create TypeScript Command:
```typescript
// src/cli/typescript/commands/docuwrite-newcmd.ts
interface NewCmdOptions {
    // Command options
}

async function newCmd(options: NewCmdOptions): Promise<void> {
    // Command implementation
}

export { newCmd, NewCmdOptions };
```

2. Create Bash Wrapper:
```bash
# src/cli/bash/docuwrite-newcmd.sh
#!/bin/bash
node /usr/local/docuwrite/cli/commands/docuwrite-newcmd.js "$@"
```

3. Add Command to Entrypoint:
```bash
# docker/docuwrite-entrypoint.sh
# Update DOCUWRITE_COMMANDS array:
declare -A DOCUWRITE_COMMANDS
DOCUWRITE_COMMANDS=(
    ["docuwrite-hello"]="Test command that outputs hello"
    ["docuwrite-newcmd"]="Description of new command"
)
```

4. Add Tests:
```typescript
// tests/cli/typescript/docuwrite-newcmd.test.ts
import { newCmd } from '../../../src/cli/typescript/commands/docuwrite-newcmd';

describe('docuwrite-newcmd', () => {
    // Test implementations
});
```

## Release Process

Releases are triggered automatically by GitHub Actions when creating a new release:

1. Update version in package.json
2. Push changes and create tag:
```bash
git add .
git commit -m "Prepare release v0.1.0"
git tag v0.1.0
git push origin main v0.1.0
```

3. Create release on GitHub:
- Go to Releases
- Create new release from tag
- Add release notes
- Publish release

This triggers GitHub Actions to:
- Build TypeScript code
- Build container for AMD64 and ARM64
- Push to GitHub Container Registry with tags:
  - `:latest`
  - `:0.1.0` (version)
  - `:0.1` (major.minor)

## License

MIT License

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.