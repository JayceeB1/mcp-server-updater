# MCP Server Updater Localization

This directory contains localized versions of the MCP Server Updater script.

## Supported Languages

- English (en) - Default language
- French (fr)

## Adding a New Language

To add support for a new language:

1. Create a new folder with the language code under the `localization` directory (e.g., `localization/es` for Spanish)
2. Copy the main `Update-MCP-Servers.ps1` script to the new folder
3. Translate all strings in the script
4. Update the `config.json` file to include the new language

## Localization Structure

```
localization/
├── config.json           # Localization configuration
├── README.md             # This file
└── fr/                   # French localization
    └── Update-MCP-Servers.ps1  # French version of the script
```

## Configuration

The `config.json` file contains the configuration for each supported language. It specifies:

- The list of supported languages
- The default language
- For each language:
  - The display name
  - The path to the script
  - The date format to use

## Using a Specific Language

To run the script in a specific language, use the `-Language` parameter:

```powershell
.\Update-MCP-Servers.ps1 -Language fr
```

If no language is specified, the script will use the default language specified in the configuration file.
