#!/usr/bin/env pwsh
#Requires -Version 5.0

# MCP Servers Updater
# Created: 05/04/2025
# Author: Claude & JayceeB1
# This script analyzes MCP servers and can update them if needed

# Define script parameters
param (
    # Specifies the language for UI messages. Defaults to 'en-US' or system culture if available.
    [string]$Language
)

# Set UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8



# --- Localization Setup ---
# Initialize $LocalizedStrings to $null to handle cases where loading fails
$LocalizedStrings = $null
try {
    # Determine UI Culture
    $stringsBasePath = Join-Path $PSScriptRoot "Strings"
    $availableCultures = Get-ChildItem -Path $stringsBasePath -ErrorAction SilentlyContinue | Where-Object {$_.PSIsContainer} | ForEach-Object {$_.Name}
    $defaultCulture = "en-US" # Fallback language

    if ($null -eq $availableCultures -or $availableCultures.Count -eq 0) {
         Write-Warning "No language resource directories found in '$stringsBasePath'. Using hardcoded English strings."
    } else {
        # Determine the target culture based on parameter, system UI, or default
        $targetCulture = $defaultCulture # Start with default
        if ($PSBoundParameters.ContainsKey('Language') -and $Language -in $availableCultures) {
            $targetCulture = $Language
        } elseif ($PSUICulture.Name -in $availableCultures) {
            $targetCulture = $PSUICulture.Name
        } elseif (-not ($availableCultures -contains $defaultCulture)) {
             # If default isn't available either, pick the first one found
            $targetCulture = $availableCultures[0] 
        }
        
        # Attempt to load the strings using the determined culture and base directory
        try {
            # Use -BaseDirectory to specify the 'Strings' folder
            Import-LocalizedData -BindingVariable LocalizedStrings -UICulture $targetCulture -FileName "Update-MCP-Servers.psd1" -BaseDirectory $stringsBasePath -ErrorAction Stop
            # Write-Log is not available yet, so use Write-Host for initial feedback if needed
            # Write-Host "Loaded language: $targetCulture"
        } catch {
            Write-Warning "Failed to load localized strings for culture '$targetCulture' from '$stringsBasePath'. Error: $_. Attempting fallback."
            $LocalizedStrings = $null # Ensure it's null if loading failed
        }
    }
} catch {
    # Catch errors in the culture detection logic itself
    Write-Warning "An error occurred during language detection: $_. Attempting fallback."
    $LocalizedStrings = $null
}

# Fallback mechanism: If $LocalizedStrings is still null, load English strings directly as a fallback
if ($null -eq $LocalizedStrings) {
    $fallbackPath = Join-Path $stringsBasePath "en-US\Update-MCP-Servers.psd1"
    if (Test-Path $fallbackPath) {
        try {
            # Use Invoke-Expression carefully, ensure the .psd1 file is trusted
            $LocalizedStrings = Invoke-Expression (Get-Content $fallbackPath -Raw)
            Write-Warning "Using fallback English strings from $fallbackPath."
        } catch {
             Write-Error "FATAL: Failed to load fallback English strings from $fallbackPath. Error: $_"
             # Consider exiting or handling this fatal error appropriately
             exit 1 
        }
    } else {
        Write-Error "FATAL: Fallback English resource file not found at $fallbackPath. Cannot proceed."
        # Consider exiting or handling this fatal error appropriately
        exit 1
    }
}
# --- End Localization Setup ---


# Configuration
$configPath = "$env:APPDATA\Claude\claude_desktop_config.json"
$logFile = "$env:USERPROFILE\Documents\MCP-Scripts\mcp-updater-log.txt"
$detailedLogFile = "$env:USERPROFILE\Documents\MCP-Scripts\mcp-detailed-analysis.json"

# Ensure log directory and files exist
$logDirectory = Split-Path -Path $logFile -Parent
if (-not (Test-Path -Path $logDirectory -PathType Container)) {
    Write-Host ($LocalizedStrings.CreatingLogDir -f $logDirectory) -ForegroundColor Yellow
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path -Path $logFile)) {
    Write-Host ($LocalizedStrings.CreatingLogFile -f $logFile) -ForegroundColor Yellow
    New-Item -Path $logFile -ItemType File -Force | Out-Null
}
if (-not (Test-Path -Path $detailedLogFile)) {
    Write-Host ($LocalizedStrings.CreatingDetailedLogFile -f $detailedLogFile) -ForegroundColor Yellow
    New-Item -Path $detailedLogFile -ItemType File -Force | Out-Null
}

# Initialize log file
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

# Structure to store detailed analysis
$detailedAnalysis = @{}

# Function to write to log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    if ([string]::IsNullOrEmpty($Message)) {
        # This is internal, not localized
        $Message = "[Empty Message]"
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logMessage
}

# Function to display colored messages
function Write-ColorOutput {
    param(
        [string]$Message = "[Empty Message]",
        
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White"
    )
    
    if ([string]::IsNullOrEmpty($Message)) {
        # This is internal, not localized
        $Message = "[Empty Message]"
    }
    
    Write-Host $Message -ForegroundColor $ForegroundColor
    Write-Log $Message
}

# Function to check if a path is a Git repository (also checks parent directories)
function Test-GitRepository {
    param (
        [string]$Path,
        [switch]$FindRoot = $false
    )
    
    $currentPath = $Path
    
    while ($null -ne $currentPath -and $currentPath -ne "") {
        if (Test-Path (Join-Path $currentPath ".git")) {
            if ($FindRoot) {
                return $currentPath  # Return the root path of the repo
            } else {
                return $true  # Just return true
            }
        }
        
        # Go up one level
        $parentPath = [System.IO.Path]::GetDirectoryName($currentPath)
        
        # If we're already at the root, exit the loop
        if ($parentPath -eq $currentPath) {
            break
        }
        
        $currentPath = $parentPath
    }
    
    if ($FindRoot) {
        return $null  # No repo found, return null
    } else {
        return $false  # No repo found, return false
    }
}

# Function to extract the remote URL of a Git repository
function Get-GitRemoteUrl {
    param (
        [string]$Path
    )
    
    Push-Location $Path
    try {
        # First try to get the origin URL with git config
        $remote = git config --get remote.origin.url 2>$null
        if ($remote) {
            return $remote
        }
        
        # If the previous command fails, try with git remote -v
        $remote = git remote -v | Select-String -Pattern "^origin.*\(fetch\)$" | ForEach-Object { $_ -replace "origin\s+([^\s]+).*", '$1' }
        if ($remote) {
            return $remote
        } else {
            # If origin doesn't exist, try to get any remote
            $remote = git remote -v | Select-String -Pattern "\(fetch\)$" | ForEach-Object { $_ -replace "([^\s]+)\s+([^\s]+).*", '$2' } | Select-Object -First 1
            return $remote
        }
    } catch {
        Write-Log "Error extracting remote URL: $_" -Level "ERROR"
        return $null
    } finally {
        Pop-Location
    }
}

# Function to extract the owner and repository name from a GitHub URL
function Get-GitHubRepoInfo {
    param (
        [string]$Url
    )
    
    if ($Url -match "github\.com[\/:]([^\/]+)\/([^\/\.]+)") {
        return @{
            Owner = $matches[1]
            Repo = $matches[2] -replace "\.git$", ""
        }
    }
    return $null
}

# Function to identify the project type
function Get-ProjectType {
    param (
        [string]$Path
    )
    
    $projectInfo = @{
        HasPackageJson = Test-Path (Join-Path $Path "package.json")
        HasPipfile = Test-Path (Join-Path $Path "Pipfile")
        HasRequirements = Test-Path (Join-Path $Path "requirements.txt")
        HasSetupPy = Test-Path (Join-Path $Path "setup.py")
        HasGoMod = Test-Path (Join-Path $Path "go.mod")
        HasMakefile = Test-Path (Join-Path $Path "Makefile")
        HasCMakeLists = Test-Path (Join-Path $Path "CMakeLists.txt")
        HasGradlew = Test-Path (Join-Path $Path "gradlew")
        HasMaven = Test-Path (Join-Path $Path "pom.xml")
        HasCargo = Test-Path (Join-Path $Path "Cargo.toml")
        HasDotnetProj = (Get-ChildItem -Path $Path -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue).Count -gt 0
    }
    
    # Determine the main project type
    if ($projectInfo.HasPackageJson) {
        # Read package.json for more information
        try {
            $packageJson = Get-Content (Join-Path $Path "package.json") -Raw | ConvertFrom-Json
            $projectInfo.PackageName = $packageJson.name
            $projectInfo.PackageVersion = $packageJson.version
            $projectInfo.HasTypescript = Test-Path (Join-Path $Path "tsconfig.json")
            $projectInfo.HasBuildScript = $null -ne $packageJson.scripts?.build # Keep safe navigation
            $projectInfo.BuildCommand = if ($projectInfo.HasBuildScript) { "npm run build" } else { $null }
            $projectInfo.DependenciesCount = if ($packageJson.dependencies) { ($packageJson.dependencies | Get-Member -MemberType NoteProperty).Count } else { 0 }
        } catch {
            Write-Log "Error reading package.json: $_" -Level "ERROR"
        }
        return @{
            Type = "Node.js"
            Language = if ($projectInfo.HasTypescript) { "TypeScript" } else { "JavaScript" }
            Details = $projectInfo
        }
    } elseif ($projectInfo.HasPipfile -or $projectInfo.HasRequirements -or $projectInfo.HasSetupPy) {
        return @{
            Type = "Python"
            Language = "Python"
            Details = $projectInfo
        }
    } elseif ($projectInfo.HasGoMod) {
        return @{
            Type = "Go"
            Language = "Go"
            Details = $projectInfo
        }
    } elseif ($projectInfo.HasMaven -or $projectInfo.HasGradlew) {
        return @{
            Type = "JVM"
            Language = "Java"
            Details = $projectInfo
        }
    } elseif ($projectInfo.HasCargo) {
        return @{
            Type = "Rust"
            Language = "Rust"
            Details = $projectInfo
        }
    } elseif ($projectInfo.HasDotnetProj) {
        return @{
            Type = ".NET"
            Language = "C#"
            Details = $projectInfo
        }
    } elseif ($projectInfo.HasMakefile -or $projectInfo.HasCMakeLists) {
        return @{
            Type = "C/C++"
            Language = "C/C++"
            Details = $projectInfo
        }
    } else {
        # Try to detect by file extensions
        $extensions = @{
            ".js" = @{ Type = "Node.js"; Language = "JavaScript" }
            ".ts" = @{ Type = "Node.js"; Language = "TypeScript" }
            ".py" = @{ Type = "Python"; Language = "Python" }
            ".go" = @{ Type = "Go"; Language = "Go" }
            ".java" = @{ Type = "JVM"; Language = "Java" }
            ".rs" = @{ Type = "Rust"; Language = "Rust" }
            ".cs" = @{ Type = ".NET"; Language = "C#" }
            ".c" = @{ Type = "C/C++"; Language = "C" }
            ".cpp" = @{ Type = "C/C++"; Language = "C++" }
        }
        
        foreach ($ext in $extensions.Keys) {
            $count = (Get-ChildItem -Path $Path -Filter "*$ext" -Recurse -ErrorAction SilentlyContinue).Count
            if ($count -gt 0) {
                return @{
                    Type = $extensions[$ext].Type
                    Language = $extensions[$ext].Language
                    Details = @{ DetectedByExtension = $ext; FileCount = $count }
                }
            }
        }
        
        return @{
            Type = "Unknown"
            Language = "Unknown"
            Details = $projectInfo
        }
    }
}

# Function to analyze a Git repository without making changes
function Test-GitRepositoryUpdate {
    param (
        [string]$Path,
        [string]$McpName
    )
    
    # Get the root path of the Git repository
    $gitRoot = Test-GitRepository -Path $Path -FindRoot
    
    if (-not $gitRoot) {
        Write-ColorOutput ($LocalizedStrings.PathNotGitRepo -f $Path) "Red"
        return @{
            IsGitRepo = $false
            Error = $LocalizedStrings.PathNotGitRepo -f $Path # Use localized string for error consistency
        }
    }
    
    $analysis = @{
        IsGitRepo = $true
        Path = $Path
        GitRoot = $gitRoot
        McpName = $McpName
        CurrentDateTime = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
    
    Push-Location $gitRoot
    try {
        # Get the remote URL
        $remoteUrl = Get-GitRemoteUrl -Path $gitRoot
        $analysis.RemoteUrl = $remoteUrl
        
        if ($remoteUrl -and $remoteUrl -match "github\.com") {
            $repoInfo = Get-GitHubRepoInfo -Url $remoteUrl
            $analysis.GitHubOwner = $repoInfo.Owner
            $analysis.GitHubRepo = $repoInfo.Repo
        }
        
        # Get the current branch
        $analysis.CurrentBranch = git rev-parse --abbrev-ref HEAD
        
        # Get the current version
        $analysis.CurrentVersion = git describe --tags --always 2>$null
        if (-not $analysis.CurrentVersion) {
            $analysis.CurrentVersion = git rev-parse --short HEAD
        }
        
        # Check for uncommitted changes
        $status = git status --porcelain
        # This comparison seems correct as $status contains output or is $null/empty
        $analysis.HasLocalChanges = $null -ne $status -and $status.Length -gt 0 
        
        # Fetch the latest changes (without applying them)
        git fetch origin 2>$null
        
        # Check for updates
        try {
            # Check if the remote branch exists
            $remoteBranchExists = git ls-remote --heads origin $analysis.CurrentBranch | Out-String
            
            if (-not $remoteBranchExists) {
                $analysis.UpdateStatus = $LocalizedStrings.StatusRemoteBranchNotFound
                $analysis.IsUpToDate = $false
            } else {
                $behind = git rev-list --count HEAD..origin/$($analysis.CurrentBranch) 2>$null
                $ahead = git rev-list --count origin/$($analysis.CurrentBranch)..HEAD 2>$null
                
                # Already correct
                if ($null -eq $behind -or $null -eq $ahead) {
                    $analysis.UpdateStatus = $LocalizedStrings.StatusErrorCheckingUpdates
                    $analysis.IsUpToDate = $false
                } else {
                    $analysis.Behind = [int]$behind
                    $analysis.Ahead = [int]$ahead
                    $analysis.IsUpToDate = $behind -eq 0
                    $analysis.HasLocalCommits = $ahead -gt 0
                    
                    if ($behind -eq 0) {
                        $analysis.UpdateStatus = $LocalizedStrings.StatusUpToDate
                    } else {
                        $analysis.UpdateStatus = $LocalizedStrings.StatusUpdatesAvailable -f $behind
                    }
                }
            }
        } catch {
            Write-Log "Error checking for updates: $_" -Level "ERROR"
            $analysis.UpdateStatus = $LocalizedStrings.StatusErrorCheckingUpdates
            $analysis.IsUpToDate = $false
        }
        
        # Identify the project type
        $projectType = Get-ProjectType -Path $gitRoot
        $analysis.ProjectType = $projectType.Type
        $analysis.Language = $projectType.Language
        $analysis.ProjectDetails = $projectType.Details
        
        return $analysis
    } catch {
        Write-ColorOutput ($LocalizedStrings.ErrorAnalyzingRepo -f $_) "Red"
        Write-Log "Error analyzing ${Path}: $_" -Level "ERROR"
        
        return @{
            IsGitRepo = $true
            Error = $_.Exception.Message
        }
    } finally {
        Pop-Location
    }
}

# Function to update a Git repository
function Update-GitRepository {
    param (
        [string]$Path,
        [string]$McpName,
        [hashtable]$Analysis
    )
    
    $gitRoot = $Analysis.GitRoot
    
    if ($null -eq $gitRoot) {
        Write-ColorOutput ($LocalizedStrings.PathNotGitRepo -f $Path) "Red" # Re-use string
        return $false
    }
    
    Push-Location $gitRoot
    try {
        Write-ColorOutput ($LocalizedStrings.UpdatingServer -f $McpName) "Cyan"
        
        # Backup uncommitted changes if necessary
        if ($Analysis.HasLocalChanges) {
            $backupBranch = "backup-" + (Get-Date -Format "yyyyMMdd-HHmmss")
            git stash
            git branch $backupBranch
            Write-ColorOutput ($LocalizedStrings.LocalChangesBackedUp -f $backupBranch) "Yellow"
        }
        
        # Get the current version
        $currentVersion = $Analysis.CurrentVersion
        
        # Pull changes
        Write-ColorOutput ($LocalizedStrings.RunningGitPull -f $Analysis.CurrentBranch) "Gray"
        $pullResult = git pull origin $Analysis.CurrentBranch 2>&1
        $pullSuccess = $LASTEXITCODE -eq 0
        
        if (-not $pullSuccess) {
            Write-ColorOutput ($LocalizedStrings.ErrorUpdating -f $pullResult) "Red"
            return $false
        }
        
        # Get the new version
        $newVersion = git describe --tags --always 2>$null
        if ($null -eq $newVersion) {
            $newVersion = git rev-parse --short HEAD
        }
        
        Write-ColorOutput ($LocalizedStrings.ServerUpdated -f $McpName, $currentVersion, $newVersion) "Green"
        
        # Perform actions specific to the project type
        switch ($Analysis.ProjectType) {
            "Node.js" {
                Write-ColorOutput $LocalizedStrings.InstallingNodeDeps "Gray"
                npm install
                
                if ($Analysis.ProjectDetails.HasBuildScript) {
                    Write-ColorOutput $LocalizedStrings.BuildingProject "Gray"
                    npm run build
                }
            }
            "Python" {
                if ($Analysis.ProjectDetails.HasPipfile) {
                    Write-ColorOutput $LocalizedStrings.InstallingPipenvDeps "Gray"
                    pipenv install
                } elseif ($Analysis.ProjectDetails.HasRequirements) {
                    Write-ColorOutput $LocalizedStrings.InstallingPipDeps "Gray"
                    pip install -r requirements.txt
                } elseif ($Analysis.ProjectDetails.HasSetupPy) {
                    Write-ColorOutput $LocalizedStrings.InstallingPythonPackage "Gray"
                    pip install -e .
                }
            }
            "Go" {
                Write-ColorOutput $LocalizedStrings.InstallingGoDeps "Gray"
                go mod download
                Write-ColorOutput $LocalizedStrings.BuildingGoProject "Gray"
                go build
            }
            "JVM" {
                if ($Analysis.ProjectDetails.HasMaven) {
                    Write-ColorOutput $LocalizedStrings.BuildingMavenProject "Gray"
                    mvn clean install
                } elseif ($Analysis.ProjectDetails.HasGradlew) {
                    Write-ColorOutput $LocalizedStrings.BuildingGradleProject "Gray"
                    ./gradlew build
                }
            }
            "Rust" {
                Write-ColorOutput $LocalizedStrings.BuildingRustProject "Gray"
                cargo build
            }
            ".NET" {
                Write-ColorOutput $LocalizedStrings.RestoringNetDeps "Gray"
                dotnet restore
                Write-ColorOutput $LocalizedStrings.BuildingNetProject "Gray"
                dotnet build
            }
            "C/C++" {
                if ($Analysis.ProjectDetails.HasCMakeLists) {
                    Write-ColorOutput $LocalizedStrings.GeneratingCMakeProject "Gray"
                    cmake -B build
                    Write-ColorOutput $LocalizedStrings.BuildingCMakeProject "Gray"
                    cmake --build build
                } elseif ($Analysis.ProjectDetails.HasMakefile) {
                    Write-ColorOutput $LocalizedStrings.BuildingMakeProject "Gray"
                    make
                }
            }
        }
        
        return $true
    } catch {
        Write-ColorOutput ($LocalizedStrings.ErrorUpdating -f $_) "Red"
        return $false
    } finally {
        Pop-Location
    }
}

# Function to detect the path of an MCP server from its configuration
function Get-McpPath {
    param (
        [string]$Command,
        [array]$Arguments
    )
    
    # If the first argument is a path to a JavaScript, Python, TypeScript, or executable file
    if ($Arguments -and $Arguments[0] -match "\.(js|py|exe|ts|mjs)$") {
        $scriptPath = $Arguments[0]
        
        # Convert the path to an absolute path if necessary
        if (-not [System.IO.Path]::IsPathRooted($scriptPath)) {
            try {
                $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
            } catch {
                Write-Log "Error converting path '$scriptPath' to absolute path: $_" -Level "ERROR"
                return $null
            }
        }
        
        # Check if the path exists
        if (-not (Test-Path $scriptPath)) {
            Write-Log "Script path '$scriptPath' does not exist." -Level "WARN"
            # Continue anyway, as the path might be relative to another directory
        }
        
        # Get the parent directory
        $directory = [System.IO.Path]::GetDirectoryName($scriptPath)
        
        # Go up one level if we're in a subdirectory like "dist"
        $buildFolders = @("dist", "build", "lib", "out", "bin", "target", "release", "debug")
        if ([System.IO.Path]::GetFileName($directory) -in $buildFolders) {
            $directory = [System.IO.Path]::GetDirectoryName($directory)
        }
        
        return $directory
    }
    
    # If the command is "npx", try to find the package path
    if ($Command -eq "npx" -and $Arguments -and $Arguments.Count -gt 0) {
        # The package is likely the first argument after "-y" if present
        $packageArg = if ($Arguments[0] -eq "-y") { $Arguments[1] } else { $Arguments[0] }
        
        # If it's a local path, return it
        if ($packageArg -and ($packageArg.StartsWith("./") -or $packageArg.StartsWith("../") -or [System.IO.Path]::IsPathRooted($packageArg))) {
            return $packageArg
        }
        
        # Otherwise, it's probably an npm package
        return $null
    }
    
    return $null
}

# Main function to analyze all MCP servers
function Test-AllMcpServers {
    param (
        [switch]$Update = $false
    )
    
    # Check that the configuration file exists
    if (-not (Test-Path $configPath)) {
        Write-ColorOutput ($LocalizedStrings.ConfigNotFound -f $configPath) "Red"
        return
    }
    
    # Read the configuration
    try {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    } catch {
        Write-ColorOutput ($LocalizedStrings.ErrorReadingConfig -f $_) "Red"
        return
    }
    
    # Check that MCP servers are configured
    if ($null -eq $config.mcpServers -or ($config.mcpServers | Get-Member -MemberType NoteProperty).Count -eq 0) {
        Write-ColorOutput $LocalizedStrings.NoServersConfigured "Yellow"
        return
    }
    
    # Process each MCP server
    $serverCount = ($config.mcpServers | Get-Member -MemberType NoteProperty).Count
    $analyzedCount = 0
    $skippedCount = 0
    $failedCount = 0
    
    Write-ColorOutput $LocalizedStrings.AnalyzingServersTitle "Cyan"
    Write-ColorOutput ($LocalizedStrings.ServersDetected -f $serverCount) "Cyan"
    # Removed empty Write-ColorOutput for spacing
    
    foreach ($mcpName in ($config.mcpServers | Get-Member -MemberType NoteProperty).Name) {
        $mcpConfig = $config.mcpServers.$mcpName
        
        Write-ColorOutput ($LocalizedStrings.AnalyzingServer -f $mcpName) "White"
        Write-Log "===== Starting analysis of MCP server '$mcpName' =====" -Level "INFO"
        
        # Collect basic server information
        $serverInfo = @{
            Name = $mcpName
            Command = $mcpConfig.command
            Args = $mcpConfig.args
            Environment = if ($mcpConfig.env) { $mcpConfig.env } else { @{} }
        }
        
        # Get the MCP server path
        $mcpPath = Get-McpPath -Command $mcpConfig.command -Arguments $mcpConfig.args
        
        if ($null -eq $mcpPath) {
            Write-ColorOutput ($LocalizedStrings.UnableToDeterminePath -f $mcpName) "Yellow"
            Write-Log "Unable to determine path for '$mcpName'." -Level "WARN"
            
            $serverInfo.Status = "SKIPPED"
            $serverInfo.Error = $LocalizedStrings.UnableToDeterminePath -f $mcpName # Use localized string
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $skippedCount++
            continue
        }
        
        if (-not (Test-Path $mcpPath)) {
            Write-ColorOutput ($LocalizedStrings.DetectedPathNotExist -f $mcpPath) "Yellow"
            Write-Log "Detected path '$mcpPath' does not exist for '$mcpName'." -Level "WARN"
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "SKIPPED"
            $serverInfo.Error = $LocalizedStrings.DetectedPathNotExist -f $mcpPath # Use localized string
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $skippedCount++
            continue
        }
        
        Write-ColorOutput ($LocalizedStrings.DetectedPath -f $mcpPath) "Gray"
        Write-Log "Detected path for '$mcpName': $mcpPath" -Level "INFO"
        
        # Check if it's a Git repository by also checking parent directories
        if (-not (Test-GitRepository $mcpPath)) {
            Write-ColorOutput $LocalizedStrings.NotAGitRepo "Yellow"
            Write-Log "Path '$mcpPath' is not a Git repository (or any parent directory)." -Level "WARN"
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "SKIPPED"
            $serverInfo.IsGitRepo = $false
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $skippedCount++
            continue
        }
        
        # Analyze the repository
        Write-ColorOutput $LocalizedStrings.AnalyzingGitRepo "Gray"
        $analysisResult = Test-GitRepositoryUpdate -Path $mcpPath -McpName $mcpName
        
        if ($analysisResult.Error) {
            # No change needed for IsNullOrEmpty
            $errorMsg = if ([string]::IsNullOrEmpty($analysisResult.Error)) { $LocalizedStrings.UnknownError } else { $analysisResult.Error }
            Write-ColorOutput ($LocalizedStrings.ErrorAnalyzingRepoDetailed -f $errorMsg) "Red"
            Write-Log "Error analyzing repository '$mcpPath': $errorMsg" -Level "ERROR"
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "FAILED"
            $serverInfo.Error = $errorMsg
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $failedCount++
        } else {
            # Update status
            $updateStatus = $analysisResult.UpdateStatus
            Write-ColorOutput ($LocalizedStrings.UpdateStatus -f $updateStatus) -ForegroundColor $(if ($analysisResult.IsUpToDate) { "Green" } else { "Yellow" })
            
            # Project type
            $projectType = $analysisResult.ProjectType
            $language = $analysisResult.Language
            Write-ColorOutput ($LocalizedStrings.DetectedProjectType -f $projectType, $language) "Gray"
            
            # Build instructions
            if ($analysisResult.ProjectDetails.HasBuildScript) {
                Write-ColorOutput ($LocalizedStrings.BuildScriptDetected -f $analysisResult.ProjectDetails.BuildCommand) "Gray"
            }
            
            # Local changes
            if ($analysisResult.HasLocalChanges) {
                Write-ColorOutput $LocalizedStrings.WarningLocalChanges "Yellow"
            }
            
            # Language-specific update commands
            switch ($projectType) {
                "Node.js" {
                    Write-ColorOutput $LocalizedStrings.NodeUpdateCommands "Gray"
                    Write-ColorOutput $LocalizedStrings.GitPullCommand "Gray"
                    Write-ColorOutput $LocalizedStrings.NpmInstallCommand "Gray"
                    if ($analysisResult.ProjectDetails.HasBuildScript) {
                        Write-ColorOutput ($LocalizedStrings.NpmBuildCommand -f $analysisResult.ProjectDetails.BuildCommand) "Gray"
                    }
                }
                "Python" {
                    Write-ColorOutput $LocalizedStrings.PythonUpdateCommands "Gray"
                    Write-ColorOutput $LocalizedStrings.GitPullCommand "Gray"
                    if ($analysisResult.ProjectDetails.HasPipfile) {
                        Write-ColorOutput $LocalizedStrings.PipenvInstallCommand "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasRequirements) {
                        Write-ColorOutput $LocalizedStrings.PipInstallRequirementsCommand "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasSetupPy) {
                        Write-ColorOutput $LocalizedStrings.PipInstallEditableCommand "Gray"
                    }
                }
                "Go" {
                    Write-ColorOutput $LocalizedStrings.GoUpdateCommands "Gray"
                    Write-ColorOutput $LocalizedStrings.GitPullCommand "Gray"
                    Write-ColorOutput $LocalizedStrings.GoModDownloadCommand "Gray"
                    Write-ColorOutput $LocalizedStrings.GoBuildCommand "Gray"
                }
                "JVM" {
                    Write-ColorOutput $LocalizedStrings.JvmUpdateCommands "Gray"
                    Write-ColorOutput $LocalizedStrings.GitPullCommand "Gray"
                    if ($analysisResult.ProjectDetails.HasMaven) {
                        Write-ColorOutput $LocalizedStrings.MvnCleanInstallCommand "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasGradlew) {
                        Write-ColorOutput $LocalizedStrings.GradlewBuildCommand "Gray"
                    }
                }
                "Rust" {
                    Write-ColorOutput $LocalizedStrings.RustUpdateCommands "Gray"
                    Write-ColorOutput $LocalizedStrings.GitPullCommand "Gray"
                    Write-ColorOutput $LocalizedStrings.CargoBuildCommand "Gray"
                }
                ".NET" {
                    Write-ColorOutput $LocalizedStrings.NetUpdateCommands "Gray"
                    Write-ColorOutput $LocalizedStrings.GitPullCommand "Gray"
                    Write-ColorOutput $LocalizedStrings.DotnetRestoreCommand "Gray"
                    Write-ColorOutput $LocalizedStrings.DotnetBuildCommand "Gray"
                }
                "C/C++" {
                    Write-ColorOutput $LocalizedStrings.CUpdateCommands "Gray"
                    Write-ColorOutput $LocalizedStrings.GitPullCommand "Gray"
                    if ($analysisResult.ProjectDetails.HasCMakeLists) {
                        Write-ColorOutput $LocalizedStrings.CMakeGenerateCommand "Gray"
                        Write-ColorOutput $LocalizedStrings.CMakeBuildCommand "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasMakefile) {
                        Write-ColorOutput $LocalizedStrings.MakeCommand "Gray"
                    }
                }
                default {
                    Write-ColorOutput $LocalizedStrings.UnrecognizedProjectType "Gray"
                    Write-ColorOutput $LocalizedStrings.GitPullCommand "Gray"
                }
            }
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "ANALYZED"
            $serverInfo.Analysis = $analysisResult
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $analyzedCount++
        }
        
        # Removed empty Write-ColorOutput for spacing
        Write-Log "===== End of analysis of MCP server '$mcpName' =====" -Level "INFO"
    }
    
    # Display summary
    Write-ColorOutput $LocalizedStrings.AnalysisSummaryTitle "Cyan"
    Write-ColorOutput ($LocalizedStrings.ServersDetected -f $serverCount) "White"
    Write-ColorOutput ($LocalizedStrings.ServersAnalyzed -f $analyzedCount) "Green"
    Write-ColorOutput ($LocalizedStrings.ServersSkipped -f $skippedCount) "Yellow"
    Write-ColorOutput ($LocalizedStrings.ServersFailed -f $failedCount) "Red"
    # Removed empty Write-ColorOutput for spacing
    
    # Save detailed analysis as JSON
    $detailedAnalysisJson = ConvertTo-Json -InputObject $detailedAnalysis -Depth 6
    Set-Content -Path $detailedLogFile -Value $detailedAnalysisJson
    
    Write-ColorOutput ($LocalizedStrings.DetailedLogSaved -f $detailedLogFile) "Gray"
    Write-ColorOutput ($LocalizedStrings.LogSaved -f $logFile) "Gray"
    
    # Offer to update if requested and if servers to update are detected
    # Offer to update if servers to update are detected
        $serversToUpdate = @()
        
        foreach ($mcpName in $detailedAnalysis.Keys) {
            $serverInfo = $detailedAnalysis[$mcpName]
            
            if ($serverInfo.Status -eq "ANALYZED" -and -not $serverInfo.Analysis.IsUpToDate) {
                $serversToUpdate += $mcpName
            }
        }
        
        if ($serversToUpdate.Count -gt 0) {
            # Removed empty Write-ColorOutput for spacing
            Write-ColorOutput ($LocalizedStrings.ServersToUpdateTitle -f $serversToUpdate.Count) "Cyan"
            
            foreach ($mcpName in $serversToUpdate) {
                $behind = $detailedAnalysis[$mcpName].Analysis.Behind
                Write-ColorOutput ($LocalizedStrings.ServerUpdateInfo -f $mcpName, $behind) "Yellow"
            }
            
            Write-ColorOutput ""
            $confirmation = Read-Host $LocalizedStrings.UpdatePrompt
            
            if ($confirmation -eq "Y" -or $confirmation -eq "y") {
                $updatedCount = 0
                $updateFailedCount = 0
                
                foreach ($mcpName in $serversToUpdate) {
                    $serverInfo = $detailedAnalysis[$mcpName]
                    
                    Write-ColorOutput ($LocalizedStrings.UpdatingServer -f $mcpName) "Cyan"
                    Write-Log "===== Start updating MCP server '$mcpName' =====" -Level "INFO"
                    
                    $updateResult = Update-GitRepository -Path $serverInfo.Path -McpName $mcpName -Analysis $serverInfo.Analysis
                    
                    if ($updateResult) {
                        $updatedCount++
                        Write-Log "Successfully updated MCP server '$mcpName'" -Level "INFO"
                    } else {
                        $updateFailedCount++
                        Write-Log "Failed to update MCP server '$mcpName'" -Level "ERROR"
                    }
                    
                    Write-ColorOutput ""
                    Write-Log "===== Finished updating MCP server '$mcpName' =====" -Level "INFO"
                }
                
                Write-ColorOutput $LocalizedStrings.UpdateSummaryTitle "Cyan"
                Write-ColorOutput ($LocalizedStrings.ServersUpdated -f $updatedCount) "Green"
                Write-ColorOutput ($LocalizedStrings.ServersUpdateFailed -f $updateFailedCount) "Red"
                # Removed empty Write-ColorOutput for spacing
                Write-ColorOutput $LocalizedStrings.RestartRequired "Cyan"
            } else {
                Write-ColorOutput $LocalizedStrings.UpdateCanceled "Yellow"
            }
        } else {
            # Removed empty Write-ColorOutput for spacing
            Write-ColorOutput $LocalizedStrings.AllServersUpToDate "Green"
        }
    # End of update offer block
}

# Main entry point
# Param block and localization setup moved to the top of the script (lines 8-68)

try {
    # Set error handler to intercept empty string errors
    $ErrorActionPreference = "Continue"
    
    Write-ColorOutput $LocalizedStrings.StartingUpdater "Cyan"
    Write-Log "=== Starting MCP Server Updater ===" -Level "INFO"
    
    # Create MCP-Scripts directory if it doesn't exist
    $scriptsDir = [System.IO.Path]::GetDirectoryName($logFile)
    if (-not (Test-Path $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    }
    
    # Run the analysis and update process
    # The Test-AllMcpServers function now handles the update check and prompt internally
    Test-AllMcpServers
    
    Write-ColorOutput $LocalizedStrings.UpdaterCompleted "Cyan"
    Write-Log "=== MCP Server Updater Completed ===" -Level "INFO"
    
    # Wait for user to press a key before closing
    Write-ColorOutput $LocalizedStrings.PressAnyKey "Gray"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} catch {
    # Handle specific error related to empty strings
    if ($_.Exception.Message -match "empty string") {
        Write-Host $LocalizedStrings.EmptyStringErrorIgnored -ForegroundColor Yellow
        Write-Log "Empty string error detected and ignored: $_" -Level "WARN"
    } else {
        Write-ColorOutput ($LocalizedStrings.UnexpectedError -f $_) "Red"
        Write-Log "Unexpected error: $_" -Level "ERROR"
    }
    
    # Wait for user to press a key before closing
    Write-ColorOutput "$($LocalizedStrings.PressAnyKey)" "Gray"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}