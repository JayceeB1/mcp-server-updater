# MCP Servers Updater
# Created: 05/04/2025
# Author: Claude & JayceeB1
# This script analyzes MCP servers and can update them if needed

# Set UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Configuration
$configPath = "$env:APPDATA\Claude\claude_desktop_config.json"
$logFile = "$env:USERPROFILE\Documents\MCP-Scripts\mcp-updater-log.txt"
$detailedLogFile = "$env:USERPROFILE\Documents\MCP-Scripts\mcp-detailed-analysis.json"

# Ensure log directory and files exist
$logDirectory = Split-Path -Path $logFile -Parent
if (-not (Test-Path -Path $logDirectory -PathType Container)) {
    Write-Host "Creating log directory: $logDirectory" -ForegroundColor Yellow
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path -Path $logFile)) {
    Write-Host "Creating log file: $logFile" -ForegroundColor Yellow
    New-Item -Path $logFile -ItemType File -Force | Out-Null
}
if (-not (Test-Path -Path $detailedLogFile)) {
    Write-Host "Creating detailed log file: $detailedLogFile" -ForegroundColor Yellow
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
    
    while ($currentPath -ne $null -and $currentPath -ne "") {
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
            $projectInfo.HasBuildScript = $null -ne $packageJson.scripts.build
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
        Write-ColorOutput "The path '$Path' is not a valid Git repository." "Red"
        return @{
            IsGitRepo = $false
            Error = "Not a valid Git repository"
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
        $analysis.HasLocalChanges = $null -ne $status -and $status.Length -gt 0
        
        # Fetch the latest changes (without applying them)
        git fetch origin 2>$null
        
        # Check for updates
        try {
            # Check if the remote branch exists
            $remoteBranchExists = git ls-remote --heads origin $analysis.CurrentBranch | Out-String
            
            if (-not $remoteBranchExists) {
                $analysis.UpdateStatus = "Remote branch not found or not accessible"
                $analysis.IsUpToDate = $false
            } else {
                $behind = git rev-list --count HEAD..origin/$($analysis.CurrentBranch) 2>$null
                $ahead = git rev-list --count origin/$($analysis.CurrentBranch)..HEAD 2>$null
                
                if ($null -eq $behind -or $null -eq $ahead) {
                    $analysis.UpdateStatus = "Error checking for updates"
                    $analysis.IsUpToDate = $false
                } else {
                    $analysis.Behind = [int]$behind
                    $analysis.Ahead = [int]$ahead
                    $analysis.IsUpToDate = $behind -eq 0
                    $analysis.HasLocalCommits = $ahead -gt 0
                    
                    if ($behind -eq 0) {
                        $analysis.UpdateStatus = "Up to date"
                    } else {
                        $analysis.UpdateStatus = "Updates available ($behind commits behind)"
                    }
                }
            }
        } catch {
            Write-Log "Error checking for updates: $_" -Level "ERROR"
            $analysis.UpdateStatus = "Error checking for updates"
            $analysis.IsUpToDate = $false
        }
        
        # Identify the project type
        $projectType = Get-ProjectType -Path $gitRoot
        $analysis.ProjectType = $projectType.Type
        $analysis.Language = $projectType.Language
        $analysis.ProjectDetails = $projectType.Details
        
        return $analysis
    } catch {
        Write-ColorOutput "Error analyzing repository: $_" "Red"
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
    
    if (-not $gitRoot) {
        Write-ColorOutput "  The path '$Path' is not a valid Git repository." "Red"
        return $false
    }
    
    Push-Location $gitRoot
    try {
        Write-ColorOutput "  Updating MCP server '$McpName'..." "Cyan"
        
        # Backup uncommitted changes if necessary
        if ($Analysis.HasLocalChanges) {
            $backupBranch = "backup-" + (Get-Date -Format "yyyyMMdd-HHmmss")
            git stash
            git branch $backupBranch
            Write-ColorOutput "  Local changes backed up in branch $backupBranch" "Yellow"
        }
        
        # Get the current version
        $currentVersion = $Analysis.CurrentVersion
        
        # Pull changes
        Write-ColorOutput "  Running 'git pull origin $($Analysis.CurrentBranch)'..." "Gray"
        $pullResult = git pull origin $Analysis.CurrentBranch 2>&1
        $pullSuccess = $LASTEXITCODE -eq 0
        
        if (-not $pullSuccess) {
            Write-ColorOutput "  Error updating: $pullResult" "Red"
            return $false
        }
        
        # Get the new version
        $newVersion = git describe --tags --always 2>$null
        if (-not $newVersion) {
            $newVersion = git rev-parse --short HEAD
        }
        
        Write-ColorOutput "  MCP server '$McpName' updated from $currentVersion to $newVersion" "Green"
        
        # Perform actions specific to the project type
        switch ($Analysis.ProjectType) {
            "Node.js" {
                Write-ColorOutput "  Installing Node.js dependencies..." "Gray"
                npm install
                
                if ($Analysis.ProjectDetails.HasBuildScript) {
                    Write-ColorOutput "  Building project..." "Gray"
                    npm run build
                }
            }
            "Python" {
                if ($Analysis.ProjectDetails.HasPipfile) {
                    Write-ColorOutput "  Installing Python dependencies (pipenv)..." "Gray"
                    pipenv install
                } elseif ($Analysis.ProjectDetails.HasRequirements) {
                    Write-ColorOutput "  Installing Python dependencies (pip)..." "Gray"
                    pip install -r requirements.txt
                } elseif ($Analysis.ProjectDetails.HasSetupPy) {
                    Write-ColorOutput "  Installing Python package..." "Gray"
                    pip install -e .
                }
            }
            "Go" {
                Write-ColorOutput "  Installing Go dependencies..." "Gray"
                go mod download
                Write-ColorOutput "  Building Go project..." "Gray"
                go build
            }
            "JVM" {
                if ($Analysis.ProjectDetails.HasMaven) {
                    Write-ColorOutput "  Building Maven project..." "Gray"
                    mvn clean install
                } elseif ($Analysis.ProjectDetails.HasGradlew) {
                    Write-ColorOutput "  Building Gradle project..." "Gray"
                    ./gradlew build
                }
            }
            "Rust" {
                Write-ColorOutput "  Building Rust project..." "Gray"
                cargo build
            }
            ".NET" {
                Write-ColorOutput "  Restoring .NET dependencies..." "Gray"
                dotnet restore
                Write-ColorOutput "  Building .NET project..." "Gray"
                dotnet build
            }
            "C/C++" {
                if ($Analysis.ProjectDetails.HasCMakeLists) {
                    Write-ColorOutput "  Generating CMake project..." "Gray"
                    cmake -B build
                    Write-ColorOutput "  Building CMake project..." "Gray"
                    cmake --build build
                } elseif ($Analysis.ProjectDetails.HasMakefile) {
                    Write-ColorOutput "  Building Make project..." "Gray"
                    make
                }
            }
        }
        
        return $true
    } catch {
        Write-ColorOutput "  Error updating: $_" "Red"
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
        Write-ColorOutput "Claude Desktop configuration file not found at: $configPath" "Red"
        return
    }
    
    # Read the configuration
    try {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    } catch {
        Write-ColorOutput "Error reading configuration file: $_" "Red"
        return
    }
    
    # Check that MCP servers are configured
    if (-not $config.mcpServers -or ($config.mcpServers | Get-Member -MemberType NoteProperty).Count -eq 0) {
        Write-ColorOutput "No MCP servers are configured in the configuration file." "Yellow"
        return
    }
    
    # Process each MCP server
    $serverCount = ($config.mcpServers | Get-Member -MemberType NoteProperty).Count
    $analyzedCount = 0
    $skippedCount = 0
    $failedCount = 0
    
    Write-ColorOutput "=== Analyzing MCP Servers for Claude Desktop ===" "Cyan"
    Write-ColorOutput "MCP servers detected: $serverCount" "Cyan"
    Write-ColorOutput ""
    
    foreach ($mcpName in ($config.mcpServers | Get-Member -MemberType NoteProperty).Name) {
        $mcpConfig = $config.mcpServers.$mcpName
        
        Write-ColorOutput "Analyzing MCP server '$mcpName'..." "White"
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
        
        if (-not $mcpPath) {
            Write-ColorOutput "  Unable to determine path for MCP server '$mcpName'." "Yellow"
            Write-Log "Unable to determine path for '$mcpName'." -Level "WARN"
            
            $serverInfo.Status = "SKIPPED"
            $serverInfo.Error = "Unable to determine path"
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $skippedCount++
            continue
        }
        
        if (-not (Test-Path $mcpPath)) {
            Write-ColorOutput "  Detected path '$mcpPath' does not exist." "Yellow"
            Write-Log "Detected path '$mcpPath' does not exist for '$mcpName'." -Level "WARN"
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "SKIPPED"
            $serverInfo.Error = "Path does not exist"
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $skippedCount++
            continue
        }
        
        Write-ColorOutput "  Detected path: $mcpPath" "Gray"
        Write-Log "Detected path for '$mcpName': $mcpPath" -Level "INFO"
        
        # Check if it's a Git repository by also checking parent directories
        if (-not (Test-GitRepository $mcpPath)) {
            Write-ColorOutput "  Not a Git repository (or any parent directory)." "Yellow"
            Write-Log "Path '$mcpPath' is not a Git repository (or any parent directory)." -Level "WARN"
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "SKIPPED"
            $serverInfo.IsGitRepo = $false
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $skippedCount++
            continue
        }
        
        # Analyze the repository
        Write-ColorOutput "  Analyzing Git repository..." "Gray"
        $analysisResult = Test-GitRepositoryUpdate -Path $mcpPath -McpName $mcpName
        
        if ($analysisResult.Error) {
            $errorMsg = if ([string]::IsNullOrEmpty($analysisResult.Error)) { "Unknown error" } else { $analysisResult.Error }
            Write-ColorOutput "  Error analyzing repository: $errorMsg" "Red"
            Write-Log "Error analyzing repository '$mcpPath': $errorMsg" -Level "ERROR"
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "FAILED"
            $serverInfo.Error = $errorMsg
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $failedCount++
        } else {
            # Update status
            $updateStatus = $analysisResult.UpdateStatus
            Write-ColorOutput "  Update status: $updateStatus" -ForegroundColor $(if ($analysisResult.IsUpToDate) { "Green" } else { "Yellow" })
            
            # Project type
            $projectType = $analysisResult.ProjectType
            $language = $analysisResult.Language
            Write-ColorOutput "  Detected project type: $projectType ($language)" "Gray"
            
            # Build instructions
            if ($analysisResult.ProjectDetails.HasBuildScript) {
                Write-ColorOutput "  Build script detected: $($analysisResult.ProjectDetails.BuildCommand)" "Gray"
            }
            
            # Local changes
            if ($analysisResult.HasLocalChanges) {
                Write-ColorOutput "  Warning: Uncommitted local changes detected." "Yellow"
            }
            
            # Language-specific update commands
            switch ($projectType) {
                "Node.js" {
                    Write-ColorOutput "  Node.js update commands:" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    Write-ColorOutput "    - npm install" "Gray"
                    if ($analysisResult.ProjectDetails.HasBuildScript) {
                        Write-ColorOutput "    - $($analysisResult.ProjectDetails.BuildCommand)" "Gray"
                    }
                }
                "Python" {
                    Write-ColorOutput "  Python update commands:" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    if ($analysisResult.ProjectDetails.HasPipfile) {
                        Write-ColorOutput "    - pipenv install" "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasRequirements) {
                        Write-ColorOutput "    - pip install -r requirements.txt" "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasSetupPy) {
                        Write-ColorOutput "    - pip install -e ." "Gray"
                    }
                }
                "Go" {
                    Write-ColorOutput "  Go update commands:" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    Write-ColorOutput "    - go mod download" "Gray"
                    Write-ColorOutput "    - go build" "Gray"
                }
                "JVM" {
                    Write-ColorOutput "  JVM update commands:" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    if ($analysisResult.ProjectDetails.HasMaven) {
                        Write-ColorOutput "    - mvn clean install" "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasGradlew) {
                        Write-ColorOutput "    - ./gradlew build" "Gray"
                    }
                }
                "Rust" {
                    Write-ColorOutput "  Rust update commands:" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    Write-ColorOutput "    - cargo build" "Gray"
                }
                ".NET" {
                    Write-ColorOutput "  .NET update commands:" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    Write-ColorOutput "    - dotnet restore" "Gray"
                    Write-ColorOutput "    - dotnet build" "Gray"
                }
                "C/C++" {
                    Write-ColorOutput "  C/C++ update commands:" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    if ($analysisResult.ProjectDetails.HasCMakeLists) {
                        Write-ColorOutput "    - cmake -B build" "Gray"
                        Write-ColorOutput "    - cmake --build build" "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasMakefile) {
                        Write-ColorOutput "    - make" "Gray"
                    }
                }
                default {
                    Write-ColorOutput "  Unrecognized project type. Standard Git update:" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                }
            }
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "ANALYZED"
            $serverInfo.Analysis = $analysisResult
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $analyzedCount++
        }
        
        Write-ColorOutput ""
        Write-Log "===== End of analysis of MCP server '$mcpName' =====" -Level "INFO"
    }
    
    # Display summary
    Write-ColorOutput "=== Analysis Summary ===" "Cyan"
    Write-ColorOutput "MCP servers detected: $serverCount" "White"
    Write-ColorOutput "MCP servers successfully analyzed: $analyzedCount" "Green"
    Write-ColorOutput "MCP servers skipped: $skippedCount" "Yellow"
    Write-ColorOutput "MCP servers with errors: $failedCount" "Red"
    Write-ColorOutput ""
    
    # Save detailed analysis as JSON
    $detailedAnalysisJson = ConvertTo-Json -InputObject $detailedAnalysis -Depth 6
    Set-Content -Path $detailedLogFile -Value $detailedAnalysisJson
    
    Write-ColorOutput "Detailed analysis saved to: $detailedLogFile" "Gray"
    Write-ColorOutput "Operations log saved to: $logFile" "Gray"
    
    # Offer to update if requested and if servers to update are detected
    if ($Update) {
        $serversToUpdate = @()
        
        foreach ($mcpName in $detailedAnalysis.Keys) {
            $serverInfo = $detailedAnalysis[$mcpName]
            
            if ($serverInfo.Status -eq "ANALYZED" -and -not $serverInfo.Analysis.IsUpToDate) {
                $serversToUpdate += $mcpName
            }
        }
        
        if ($serversToUpdate.Count -gt 0) {
            Write-ColorOutput ""
            Write-ColorOutput "MCP servers that can be updated ($($serversToUpdate.Count)):" "Cyan"
            
            foreach ($mcpName in $serversToUpdate) {
                $behind = $detailedAnalysis[$mcpName].Analysis.Behind
                Write-ColorOutput "  - $mcpName ($behind commits behind)" "Yellow"
            }
            
            Write-ColorOutput ""
            $confirmation = Read-Host "Do you want to update these MCP servers? (Y/N)"
            
            if ($confirmation -eq "Y" -or $confirmation -eq "y") {
                $updatedCount = 0
                $updateFailedCount = 0
                
                foreach ($mcpName in $serversToUpdate) {
                    $serverInfo = $detailedAnalysis[$mcpName]
                    
                    Write-ColorOutput "Updating MCP server '$mcpName'..." "Cyan"
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
                
                Write-ColorOutput "=== Update Summary ===" "Cyan"
                Write-ColorOutput "MCP servers successfully updated: $updatedCount" "Green"
                Write-ColorOutput "MCP servers with update errors: $updateFailedCount" "Red"
                Write-ColorOutput ""
                Write-ColorOutput "To apply the changes, please restart Claude Desktop." "Cyan"
            } else {
                Write-ColorOutput "Update canceled." "Yellow"
            }
        } else {
            Write-ColorOutput ""
            Write-ColorOutput "All MCP servers are up to date. No updates needed." "Green"
        }
    }
}

# Main entry point
param (
    [switch]$Update,
    [switch]$ForceUpdate,
    [string]$Language = "en"
)

try {
    # Set error handler to intercept empty string errors
    $ErrorActionPreference = "Continue"
    
    Write-ColorOutput "=== Starting MCP Server Updater ===" "Cyan"
    Write-Log "=== Starting MCP Server Updater ===" -Level "INFO"
    
    # Create MCP-Scripts directory if it doesn't exist
    $scriptsDir = [System.IO.Path]::GetDirectoryName($logFile)
    if (-not (Test-Path $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    }
    
    # Run analysis with update option
    if ($ForceUpdate) {
        # Force update without confirmation
        Test-AllMcpServers -Update
        # Automatically answer "Y" to the update prompt
        # This would require modifying the Test-AllMcpServers function
    } else {
        Test-AllMcpServers -Update:$Update
    }
    
    Write-ColorOutput "=== MCP Server Updater Completed ===" "Cyan"
    Write-Log "=== MCP Server Updater Completed ===" -Level "INFO"
    
    # Wait for user to press a key before closing
    Write-ColorOutput "Press any key to exit..." "Gray"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} catch {
    # Handle specific error related to empty strings
    if ($_.Exception.Message -match "empty string") {
        Write-Host "Empty string error detected and ignored." -ForegroundColor Yellow
        Write-Log "Empty string error detected and ignored: $_" -Level "WARN"
    } else {
        Write-ColorOutput "An unexpected error occurred: $_" "Red"
        Write-Log "Unexpected error: $_" -Level "ERROR"
    }
    
    # Wait for user to press a key before closing
    Write-ColorOutput "Press any key to exit..." "Gray"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}