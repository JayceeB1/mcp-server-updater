# MCP Server Updater

A PowerShell tool to analyze and update Model Context Protocol (MCP) servers for Claude Desktop.

![MCP Server Updater Banner](https://raw.githubusercontent.com/JayceeB1/mcp-server-updater/main/assets/banner.svg)

## 🌟 Features

- **Automatic MCP Server Detection**: Reads your Claude Desktop configuration to find all configured MCP servers.
- **Smart Repository Analysis**: Detects Git repositories even if they're in parent directories.
- **Multi-Technology Support**: Handles various project types including Node.js, Python, Go, Java, Rust, .NET, and C/C++.
- **Detailed Reporting**: Provides comprehensive analysis of all your MCP servers.
- **Automatic Update Check**: Identifies servers with available updates.
- **User-Confirmed Updates**: Prompts for confirmation before applying updates.
- **Safe Updates**: Creates backup branches before applying updates (if local changes exist).
- **Intelligent Build Process**: Automatically runs the correct build commands based on project type after updating.
- **Standardized Localization**: Uses PowerShell's standard localization system (`.psd1` files), easily extensible.

## 📋 Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Git installed and in your PATH
- Claude Desktop installed
- Package managers for your MCP servers (npm, pip, etc.)

## 🚀 Quick Start

1.  Download the latest release or clone this repository:
    ```
    git clone https://github.com/JayceeB1/mcp-server-updater.git
    cd mcp-server-updater
    ```

2.  Run the script from PowerShell:
    ```powershell
    # Allow script execution (if needed, run PowerShell as Admin)
    # Set-ExecutionPolicy RemoteSigned -Scope CurrentUser 
    
    # Run the updater
    .\Update-MCP-Servers.ps1 
    ```
    The script will analyze your servers, report the status, and ask if you want to update any servers that have pending changes.

3.  To use a specific language (e.g., French):
    ```powershell
    .\Update-MCP-Servers.ps1 -Language fr-FR 
    ```
    *(See the Localization section for more details)*

## 📊 What It Does

The tool performs these operations sequentially:

1.  **Analysis Phase**:
    - Reads the Claude Desktop configuration file (`%APPDATA%\Claude\claude_desktop_config.json`) to identify all MCP servers.
    - Detects the location of each server on disk.
    - Finds the Git repository associated with each server (searching parent directories if needed).
    - Determines the project type and required build tools.
    - Checks if updates are available from the remote repository (`git fetch` + `git rev-list`).

2.  **Reporting Phase**:
    - Displays detailed information and the update status for each server.
    - Generates a detailed JSON report (`mcp-detailed-analysis.json`).
    - Generates an operations log (`mcp-updater-log.txt`).

3.  **Update Confirmation Phase**:
    - If any servers have updates available, it lists them.
    - Prompts the user for confirmation (`Y/N`) before proceeding with updates.

4.  **Update Phase** (if confirmed by the user):
    - For each server confirmed for update:
        - Backs up uncommitted local changes using `git stash` (optional, if changes exist).
        - Pulls the latest changes from the remote repository (`git pull`).
        - Installs dependencies using the appropriate package manager (npm, pip, etc.).
        - Builds the updated code using the correct build system (npm run build, mvn install, etc.).
    - Reports the success or failure of each update.

## 🛠️ Supported Project Types

| Type       | Detection Method                  | Update Commands                     |
| :--------- | :-------------------------------- | :---------------------------------- |
| Node.js    | `package.json`                    | `npm install`, `npm run build`      |
| TypeScript | `tsconfig.json`                   | `npm install`, `npm run build`      |
| Python     | `requirements.txt`, `Pipfile`, `setup.py` | `pip install`, `pipenv install` |
| Go         | `go.mod`                          | `go mod download`, `go build`       |
| Java       | `pom.xml`, `gradlew`              | `mvn clean install`, `./gradlew build` |
| Rust       | `Cargo.toml`                      | `cargo build`                       |
| .NET       | `*.csproj`                        | `dotnet restore`, `dotnet build`    |
| C/C++      | `Makefile`, `CMakeLists.txt`      | `make`, `cmake`                     |

## 🔧 Configuration

No special configuration is required for the script itself. It automatically reads your Claude Desktop configuration from:

```
%APPDATA%\Claude\claude_desktop_config.json
```

Ensure this file correctly lists your MCP servers.

## 🌐 Localization

The tool uses PowerShell's standard localization mechanism. User-facing strings are stored in `.psd1` files within language-specific subdirectories under the `Strings` folder (e.g., `Strings\en-US`, `Strings\fr-FR`).

- **Supported Languages:**
    - English (`en-US`) - Default
    - French (`fr-FR`)

- **Language Selection:**
    1.  **Parameter:** Use the `-Language` parameter with a supported culture code (e.g., `.\Update-MCP-Servers.ps1 -Language fr-FR`).
    2.  **System Default:** If `-Language` is not provided, the script attempts to use your system's current UI culture (`$PSUICulture.Name`).
    3.  **Fallback:** If neither the specified language nor the system culture has a corresponding `.psd1` file, it falls back to `en-US`.

- **Adding a New Language:**
    1.  Create a new subdirectory in `Strings` using the appropriate culture code (e.g., `es-ES` for Spanish).
    2.  Copy `Strings\en-US\Update-MCP-Servers.psd1` into your new directory.
    3.  Translate the string values within the copied `.psd1` file.
    4.  You can now use the new language via the `-Language` parameter (e.g., `-Language es-ES`).

## 🔍 Advanced Usage

### Command Line Arguments

```powershell
.\Update-MCP-Servers.ps1 [-Language <cultureCode>]
```

- `-Language <cultureCode>`: Sets the display language. Use standard culture codes like `en-US`, `fr-FR`, etc.

*(Note: `-Update` and `-ForceUpdate` arguments have been removed. The script now automatically checks for updates and prompts for confirmation.)*

### Environment Variables

- `MCP_UPDATER_BACKUP_DIR`: (Not currently implemented) Custom location for backups.
- `MCP_UPDATER_LOG_LEVEL`: (Not currently implemented) Set to DEBUG for more verbose logging.

## 🚀 Main Improvements

Compared to basic update methods, this tool provides:

1.  **Intelligent Git Repository Detection** - Searches parent directories.
2.  **Enhanced User Interface** - Clear display with color coding.
3.  **Standardized Localization** - Easily extensible using `.psd1` files.
4.  **Simplified Execution** - No complex arguments needed for basic operation.
5.  **Deep Project Analysis** - Automatic detection of project type and build commands.
6.  **Local Changes Protection** - Stashes local changes before updating.
7.  **Cross-platform Compatibility** - Works with various types of MCP servers.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Consider adding translations for new languages!

## ☕ Support Development

If you find this module useful, consider buying me a coffee to support further development!

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jayceeB1)

Your support is greatly appreciated and helps keep this project maintained and improved!

## 📣 Acknowledgements

This tool was created with the help of Claude, an AI assistant from Anthropic.

## 📝 Other Languages

- [README in French](README.fr.md)
