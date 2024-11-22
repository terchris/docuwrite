# Project Structure

Bifrost DocuWrite is a system for creating a beautiful PDF document from markdown files (wikis).

## Development in devcontainer

Project is using [devcontainer](https://code.visualstudio.com/docs/remote/containers) for development.
```plaintext
DocuWrite/
│
├── Dockerfile               # Production Dockerfile
├── .devcontainer/
│   ├── Dockerfile           # Development Dockerfile
│   └── devcontainer.json    # VS Code dev container config
├── docker-compose.yml       # For local development
└── .dockerignore            # Specify files to exclude from Docker context
```
