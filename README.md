# KODE/API CLI

The AI coding agent for your terminal.

## Install

### Windows (PowerShell)

```powershell
irm https://cli.kodeapi.com/install.ps1 | iex
```

Or directly from GitHub:

```powershell
irm https://raw.githubusercontent.com/kode-api/cli/main/install.ps1 | iex
```

### Linux / macOS

```bash
curl -fsSL https://cli.kodeapi.com/install | bash
```

Or directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/kode-api/cli/main/install | bash
```

## Usage

```bash
kodeapi            # launch the TUI
kodeapi --version  # print version
```

## Install a specific version

```powershell
# Windows
$env:KODEAPI_VERSION = "1.0.0"; irm https://cli.kodeapi.com/install.ps1 | iex
```

```bash
# Linux / macOS
curl -fsSL https://cli.kodeapi.com/install | bash -s -- --version 1.0.0
```
