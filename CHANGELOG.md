# Changelog

All notable changes to the MCP Server Updater will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-04-05

### Changed
- **Simplified Execution:** Removed `-Update` and `-ForceUpdate` command-line arguments. The script now always analyzes servers, checks for updates, and prompts the user for confirmation if updates are found.
- **Refactored Localization:** Replaced the previous localization system (duplicate scripts) with PowerShell's standard localization mechanism. User-facing strings are now stored in `.psd1` files within language-specific subdirectories under the `Strings` folder (e.g., `Strings\en-US`, `Strings\fr-FR`). This makes adding new languages much easier.
- **Improved Update Logic:** The update process is now triggered only after user confirmation via a prompt.

### Removed
- Removed the `-Update` and `-ForceUpdate` command-line arguments.
- Removed the entire `localization` directory and its contents (`config.json`, language-specific script copies).


## [1.0.0] - 2025-04-05

### Added
- Initial release of the MCP Server Updater
- Automatic detection of MCP servers from Claude Desktop configuration
- Smart repository analysis with parent directory search
- Multi-technology support (Node.js, Python, Go, Java, Rust, .NET, C/C++)
- Detailed reporting of MCP servers status
- Safe updates with backup branch creation
- Intelligent build process based on project type
- Localization support with English and French languages
- Command line arguments for update mode and language selection
- Comprehensive documentation in README files


### Changed
- Scripts (`Update-MCP-Servers.ps1` and `localization/fr/Update-MCP-Servers.ps1`) now automatically create the log directory and files if they are missing.
- Fixed a syntax error in log messages within both scripts.
