{
    "name": "DevContainer Toolbox",
    "image": "docker.io/mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/devcontainers/features/node:1": {
            "version": "latest"
        },
        "ghcr.io/devcontainers/features/python:1": {
            "version": "3.11"
        },
        "ghcr.io/devcontainers/features/powershell:1": {},
        "ghcr.io/devcontainers/features/azure-cli:1": {},
        "ghcr.io/devcontainers/features/common-utils:2": {
            "upgradePackages": true
        }
    },
    "runArgs": [
        "--platform=linux/amd64",
        "--cap-add=NET_ADMIN",
        "--device=/dev/net/tun:/dev/net/tun",
        "--cap-add=NET_RAW",
        "--privileged"
    ],
    "customizations": {
        "vscode": {
            "extensions": [
                "ms-vscode.azure-account",
                "ms-vscode.azurecli",
                "ms-vscode.powershell",
                "yzhang.markdown-all-in-one",
                "bierner.markdown-mermaid",
                "yzane.markdown-pdf",
                "redhat.vscode-yaml",
                "donjayamanne.githistory",
                "dbaeumer.vscode-eslint"
            ]
        }
    },
    "mounts": [
        "source=${localEnv:HOME}${localEnv:USERPROFILE}/.azure,target=/home/vscode/.azure,type=bind,consistency=cached",
        "source=${localEnv:HOME}${localEnv:USERPROFILE}/.ssh,target=/home/vscode/.ssh,type=bind,consistency=cached"
    ],
    "workspaceFolder": "/workspace",
    "remoteUser": "vscode",
    "remoteEnv": {
        "PYTHONPATH": "${containerWorkspaceFolder}",
        "NODE_ENV": "development",
        "AZURE_DEFAULTS_GROUP": "operations"
    },
    "shutdownAction": "stopContainer",
    "updateRemoteUserUID": true,
    "init": true
}
