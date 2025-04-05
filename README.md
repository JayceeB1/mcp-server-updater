# MCP Server Updater

A PowerShell tool to analyze and update Model Context Protocol (MCP) servers for Claude Desktop.

![MCP Server Updater Banner](https://raw.githubusercontent.com/JayceeB1/mcp-server-updater/main/assets/banner.svg)

## 🌟 Features

- **Automatic MCP Server Detection**: Reads your Claude Desktop configuration to find all configured MCP servers
- **Smart Repository Analysis**: Detects Git repositories even if they're in parent directories
- **Multi-Technology Support**: Handles various project types including Node.js, Python, Go, Java, Rust, .NET, and C/C++
- **Detailed Reporting**: Provides comprehensive analysis of all your MCP servers
- **Safe Updates**: Creates backup branches before applying updates
- **Intelligent Build Process**: Automatically runs the correct build commands based on project type
- **Localization Support**: Available in multiple languages (English, French)

## 📋 Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Git installed and in your PATH
- Claude Desktop installed
- Package managers for your MCP servers (npm, pip, etc.)

## 🚀 Quick Start

1. Download the latest release or clone this repository:
   ```
   git clone https://github.com/JayceeB1/mcp-server-updater.git
   ```
   
2. Run the script from PowerShell:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Update-MCP-Servers.ps1
   ```
   
3. To enable update mode:
   ```powershell
   .\Update-MCP-Servers.ps1 -Update
   ```
   
4. To use a specific language:
   ```powershell
   .\Update-MCP-Servers.ps1 -Language fr
   ```

## 📊 What It Does

The tool performs these operations:

1. **Analysis Phase**:
   - Reads the Claude Desktop configuration file to identify all MCP servers
   - Detects the location of each server on disk
   - Finds the Git repository associated with each server
   - Determines the project type and required build tools
   - Checks if updates are available from the remote repository

2. **Reporting Phase**:
   - Displays detailed information about each server
   - Shows which servers can be updated
   - Generates a detailed JSON report

3. **Update Phase** (optional):
   - Creates backup branches to preserve your current state
   - Pulls the latest changes from remote repositories
   - Installs dependencies using the appropriate package manager
   - Builds the updated code using the correct build system

## 🛠️ Supported Project Types

| Type | Detection Method | Update Commands |
|------|-----------------|-----------------|
| Node.js | package.json | npm install, npm run build |
| TypeScript | tsconfig.json | npm install, npm run build |
| Python | requirements.txt, Pipfile, setup.py | pip install, pipenv install |
| Go | go.mod | go mod download, go build |
| Java | pom.xml, gradlew | mvn clean install, ./gradlew build |
| Rust | Cargo.toml | cargo build |
| .NET | *.csproj | dotnet restore, dotnet build |
| C/C++ | Makefile, CMakeLists.txt | make, cmake |

## 🔧 Configuration

No special configuration is required. The script automatically reads your Claude Desktop configuration from:

```
%APPDATA%\Claude\claude_desktop_config.json
```

## 🌐 Localization

The tool supports multiple languages:

- English (default)
- French (français)

To run the script in a specific language:

```powershell
.\Update-MCP-Servers.ps1 -Language fr
```

See the [localization README](localization/README.md) for details on how to add support for additional languages.

## 🔍 Advanced Usage

### Command Line Arguments

```powershell
.\Update-MCP-Servers.ps1 [-Update] [-ForceUpdate] [-Language <en|fr>]
```

- `-Update`: Enables the update phase (you'll still be asked for confirmation)
- `-ForceUpdate`: Updates servers without asking for confirmation
- `-Language`: Sets the display language (en=English, fr=French)

### Environment Variables

- `MCP_UPDATER_BACKUP_DIR`: Custom location for backups
- `MCP_UPDATER_LOG_LEVEL`: Set to DEBUG for more verbose logging

## 🚀 Main Improvements

Compared to basic update methods, this tool provides:

1. **Intelligent Git Repository Detection** - Searches parent directories to find Git repositories
2. **Enhanced User Interface** - Clear display with color coding
3. **Multi-language Support** - English and French, easily extensible
4. **Command Line Options** - Flexible options for updates and language selection
5. **Deep Project Analysis** - Automatic detection of project type and appropriate build commands
6. **Local Changes Protection** - Creates backup branches before updating
7. **Cross-platform Compatibility** - Works with various types of MCP servers (Node.js, Python, etc.)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📣 Acknowledgements

This tool was created with the help of Claude, an AI assistant from Anthropic.

## 📝 Other Languages

- [README in French](README.fr.md)
