# MCP Servers Updater
# Créé le : 05/04/2025
# Auteur : Claude & JayceeB1
# Ce script analyse les serveurs MCP et peut les mettre à jour si nécessaire

# Définir l'encodage en UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Configuration
$configPath = "$env:APPDATA\Claude\claude_desktop_config.json"
$logFile = "$env:USERPROFILE\Documents\MCP-Scripts\mcp-updater-log.txt"
$detailedLogFile = "$env:USERPROFILE\Documents\MCP-Scripts\mcp-detailed-analysis.json"

# Initialiser le fichier journal
if (Test-Path $logFile) {
    Remove-Item $logFile -Force
}

# Structure pour stocker l'analyse détaillée
$detailedAnalysis = @{}

# Fonction pour écrire dans le log
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    if ([string]::IsNullOrEmpty($Message)) {
        $Message = "[Message vide]"
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logMessage
}

# Fonction pour afficher des messages avec des couleurs
function Write-ColorOutput {
    param(
        [string]$Message = "[Message vide]",
        
        [Parameter(Mandatory=$false)]
        [string]$ForegroundColor = "White"
    )
    
    if ([string]::IsNullOrEmpty($Message)) {
        $Message = "[Message vide]"
    }
    
    Write-Host $Message -ForegroundColor $ForegroundColor
    Write-Log $Message
}

# Fonction pour vérifier si un chemin est un repository Git (cherche aussi dans les parents)
function Test-GitRepository {
    param (
        [string]$Path,
        [switch]$FindRoot = $false
    )
    
    $currentPath = $Path
    
    while ($currentPath -ne $null -and $currentPath -ne "") {
        if (Test-Path (Join-Path $currentPath ".git")) {
            if ($FindRoot) {
                return $currentPath  # Retourne le chemin racine du repo
            } else {
                return $true  # Retourne simplement vrai
            }
        }
        
        # Remonter d'un niveau
        $parentPath = [System.IO.Path]::GetDirectoryName($currentPath)
        
        # Si on est déjà à la racine, sortir de la boucle
        if ($parentPath -eq $currentPath) {
            break
        }
        
        $currentPath = $parentPath
    }
    
    if ($FindRoot) {
        return $null  # Pas de repo trouvé, retourner null
    } else {
        return $false  # Pas de repo trouvé, retourner false
    }
}

# Fonction pour extraire l'URL du dépôt distant principal d'un repository Git
function Get-GitRemoteUrl {
    param (
        [string]$Path
    )
    
    Push-Location $Path
    try {
        # Essayer d'abord d'obtenir l'URL d'origin avec git config
        $remote = git config --get remote.origin.url 2>$null
        if ($remote) {
            return $remote
        }
        
        # Si la commande précédente échoue, essayer avec git remote -v
        $remote = git remote -v | Select-String -Pattern "^origin.*\(fetch\)$" | ForEach-Object { $_ -replace "origin\s+([^\s]+).*", '$1' }
        if ($remote) {
            return $remote
        } else {
            # Si origin n'existe pas, essayons d'obtenir n'importe quel remote
            $remote = git remote -v | Select-String -Pattern "\(fetch\)$" | ForEach-Object { $_ -replace "([^\s]+)\s+([^\s]+).*", '$2' } | Select-Object -First 1
            return $remote
        }
    } catch {
        Write-Log "Erreur lors de l'extraction de l'URL distante : $_" -Level "ERROR"
        return $null
    } finally {
        Pop-Location
    }
}

# Fonction pour extraire le nom du propriétaire et du dépôt à partir d'une URL GitHub
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

# Fonction pour identifier le type de projet
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
    
    # Déterminer le type de projet principal
    if ($projectInfo.HasPackageJson) {
        # Lire package.json pour plus d'informations
        try {
            $packageJson = Get-Content (Join-Path $Path "package.json") -Raw | ConvertFrom-Json
            $projectInfo.PackageName = $packageJson.name
            $projectInfo.PackageVersion = $packageJson.version
            $projectInfo.HasTypescript = Test-Path (Join-Path $Path "tsconfig.json")
            $projectInfo.HasBuildScript = $null -ne $packageJson.scripts.build
            $projectInfo.BuildCommand = if ($projectInfo.HasBuildScript) { "npm run build" } else { $null }
            $projectInfo.DependenciesCount = if ($packageJson.dependencies) { ($packageJson.dependencies | Get-Member -MemberType NoteProperty).Count } else { 0 }
        } catch {
            Write-Log "Erreur lors de la lecture de package.json : $_" -Level "ERROR"
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
        # Essayer de détecter par les extensions de fichiers
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

# Fonction pour analyser un repository Git sans effectuer de modifications
function Test-GitRepositoryUpdate {
    param (
        [string]$Path,
        [string]$McpName
    )
    
    # Obtenir le chemin racine du repository Git
    $gitRoot = Test-GitRepository -Path $Path -FindRoot
    
    if (-not $gitRoot) {
        Write-ColorOutput "Le chemin '$Path' n'est pas un repository Git valide." "Red"
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
        # Obtenir l'URL distante
        $remoteUrl = Get-GitRemoteUrl -Path $gitRoot
        $analysis.RemoteUrl = $remoteUrl
        
        if ($remoteUrl -and $remoteUrl -match "github\.com") {
            $repoInfo = Get-GitHubRepoInfo -Url $remoteUrl
            $analysis.GitHubOwner = $repoInfo.Owner
            $analysis.GitHubRepo = $repoInfo.Repo
        }
        
        # Obtenir la branche actuelle
        $analysis.CurrentBranch = git rev-parse --abbrev-ref HEAD
        
        # Obtenir la version actuelle
        $analysis.CurrentVersion = git describe --tags --always 2>$null
        if (-not $analysis.CurrentVersion) {
            $analysis.CurrentVersion = git rev-parse --short HEAD
        }
        
        # Vérifier s'il y a des modifications non validées
        $status = git status --porcelain
        $analysis.HasLocalChanges = $null -ne $status -and $status.Length -gt 0
        
        # Récupérer les dernières modifications (sans les appliquer)
        git fetch origin 2>$null
        
        # Vérifier s'il y a des mises à jour
        try {
            # Vérifier si la branche distante existe
            $remoteBranchExists = git ls-remote --heads origin $analysis.CurrentBranch | Out-String
            
            if (-not $remoteBranchExists) {
                $analysis.UpdateStatus = "Branche distante introuvable ou inaccessible"
                $analysis.IsUpToDate = $false
            } else {
                $behind = git rev-list --count HEAD..origin/$($analysis.CurrentBranch) 2>$null
                $ahead = git rev-list --count origin/$($analysis.CurrentBranch)..HEAD 2>$null
                
                if ($null -eq $behind -or $null -eq $ahead) {
                    $analysis.UpdateStatus = "Erreur lors de la vérification des mises à jour"
                    $analysis.IsUpToDate = $false
                } else {
                    $analysis.Behind = [int]$behind
                    $analysis.Ahead = [int]$ahead
                    $analysis.IsUpToDate = $behind -eq 0
                    $analysis.HasLocalCommits = $ahead -gt 0
                    
                    if ($behind -eq 0) {
                        $analysis.UpdateStatus = "À jour"
                    } else {
                        $analysis.UpdateStatus = "Mises à jour disponibles ($behind commits en retard)"
                    }
                }
            }
        } catch {
            Write-Log "Erreur lors de la vérification des mises à jour : $_" -Level "ERROR"
            $analysis.UpdateStatus = "Erreur lors de la vérification des mises à jour"
            $analysis.IsUpToDate = $false
        }
        
        # Identifier le type de projet
        $projectType = Get-ProjectType -Path $gitRoot
        $analysis.ProjectType = $projectType.Type
        $analysis.Language = $projectType.Language
        $analysis.ProjectDetails = $projectType.Details
        
        return $analysis
    } catch {
        Write-ColorOutput "Erreur lors de l'analyse du repository : $_" "Red"
        Write-Log "Erreur lors de l'analyse de $Path : $_" -Level "ERROR"
        
        return @{
            IsGitRepo = $true
            Error = $_.Exception.Message
        }
    } finally {
        Pop-Location
    }
}

# Fonction pour mettre à jour un repository Git
function Update-GitRepository {
    param (
        [string]$Path,
        [string]$McpName,
        [hashtable]$Analysis
    )
    
    $gitRoot = $Analysis.GitRoot
    
    if (-not $gitRoot) {
        Write-ColorOutput "  Le chemin '$Path' n'est pas un repository Git valide." "Red"
        return $false
    }
    
    Push-Location $gitRoot
    try {
        Write-ColorOutput "  Mise à jour du serveur MCP '$McpName'..." "Cyan"
        
        # Sauvegarder les modifications non validées si nécessaires
        if ($Analysis.HasLocalChanges) {
            $backupBranch = "backup-" + (Get-Date -Format "yyyyMMdd-HHmmss")
            git stash
            git branch $backupBranch
            Write-ColorOutput "  Modifications locales sauvegardées dans la branche $backupBranch" "Yellow"
        }
        
        # Obtenir la version actuelle
        $currentVersion = $Analysis.CurrentVersion
        
        # Récupérer les modifications
        Write-ColorOutput "  Exécution de 'git pull origin $($Analysis.CurrentBranch)'..." "Gray"
        $pullResult = git pull origin $Analysis.CurrentBranch 2>&1
        $pullSuccess = $LASTEXITCODE -eq 0
        
        if (-not $pullSuccess) {
            Write-ColorOutput "  Erreur lors de la mise à jour : $pullResult" "Red"
            return $false
        }
        
        # Obtenir la nouvelle version
        $newVersion = git describe --tags --always 2>$null
        if (-not $newVersion) {
            $newVersion = git rev-parse --short HEAD
        }
        
        Write-ColorOutput "  Serveur MCP '$McpName' mis à jour de $currentVersion à $newVersion" "Green"
        
        # Effectuer les actions spécifiques au type de projet
        switch ($Analysis.ProjectType) {
            "Node.js" {
                Write-ColorOutput "  Installation des dépendances Node.js..." "Gray"
                npm install
                
                if ($Analysis.ProjectDetails.HasBuildScript) {
                    Write-ColorOutput "  Compilation du projet..." "Gray"
                    npm run build
                }
            }
            "Python" {
                if ($Analysis.ProjectDetails.HasPipfile) {
                    Write-ColorOutput "  Installation des dépendances Python (pipenv)..." "Gray"
                    pipenv install
                } elseif ($Analysis.ProjectDetails.HasRequirements) {
                    Write-ColorOutput "  Installation des dépendances Python (pip)..." "Gray"
                    pip install -r requirements.txt
                } elseif ($Analysis.ProjectDetails.HasSetupPy) {
                    Write-ColorOutput "  Installation du package Python..." "Gray"
                    pip install -e .
                }
            }
            "Go" {
                Write-ColorOutput "  Installation des dépendances Go..." "Gray"
                go mod download
                Write-ColorOutput "  Compilation du projet Go..." "Gray"
                go build
            }
            "JVM" {
                if ($Analysis.ProjectDetails.HasMaven) {
                    Write-ColorOutput "  Compilation du projet Maven..." "Gray"
                    mvn clean install
                } elseif ($Analysis.ProjectDetails.HasGradlew) {
                    Write-ColorOutput "  Compilation du projet Gradle..." "Gray"
                    ./gradlew build
                }
            }
            "Rust" {
                Write-ColorOutput "  Compilation du projet Rust..." "Gray"
                cargo build
            }
            ".NET" {
                Write-ColorOutput "  Restauration des dépendances .NET..." "Gray"
                dotnet restore
                Write-ColorOutput "  Compilation du projet .NET..." "Gray"
                dotnet build
            }
            "C/C++" {
                if ($Analysis.ProjectDetails.HasCMakeLists) {
                    Write-ColorOutput "  Génération du projet CMake..." "Gray"
                    cmake -B build
                    Write-ColorOutput "  Compilation du projet CMake..." "Gray"
                    cmake --build build
                } elseif ($Analysis.ProjectDetails.HasMakefile) {
                    Write-ColorOutput "  Compilation du projet Make..." "Gray"
                    make
                }
            }
        }
        
        return $true
    } catch {
        Write-ColorOutput "  Erreur lors de la mise à jour : $_" "Red"
        return $false
    } finally {
        Pop-Location
    }
}

# Fonction pour détecter le chemin d'un serveur MCP à partir de sa configuration
function Get-McpPath {
    param (
        [string]$Command,
        [array]$Arguments
    )
    
    # Si le premier argument est un chemin vers un fichier JavaScript, Python, TypeScript ou exécutable
    if ($Arguments -and $Arguments[0] -match "\.(js|py|exe|ts|mjs)$") {
        $scriptPath = $Arguments[0]
        
        # Convertir le chemin en chemin absolu si nécessaire
        if (-not [System.IO.Path]::IsPathRooted($scriptPath)) {
            try {
                $scriptPath = [System.IO.Path]::GetFullPath($scriptPath)
            } catch {
                Write-Log "Erreur lors de la conversion du chemin '$scriptPath' en chemin absolu : $_" -Level "ERROR"
                return $null
            }
        }
        
        # Vérifier si le chemin existe
        if (-not (Test-Path $scriptPath)) {
            Write-Log "Le chemin du script '$scriptPath' n'existe pas." -Level "WARN"
            # Continuer quand même, car le chemin pourrait être relatif à un autre répertoire
        }
        
        # Obtenir le répertoire parent
        $directory = [System.IO.Path]::GetDirectoryName($scriptPath)
        
        # Remonter d'un niveau si nous sommes dans un sous-dossier comme "dist"
        $buildFolders = @("dist", "build", "lib", "out", "bin", "target", "release", "debug")
        if ([System.IO.Path]::GetFileName($directory) -in $buildFolders) {
            $directory = [System.IO.Path]::GetDirectoryName($directory)
        }
        
        return $directory
    }
    
    # Si la commande est "npx", essayer de trouver le chemin du package
    if ($Command -eq "npx" -and $Arguments -and $Arguments.Count -gt 0) {
        # Le package est probablement le premier argument après "-y" si présent
        $packageArg = if ($Arguments[0] -eq "-y") { $Arguments[1] } else { $Arguments[0] }
        
        # Si c'est un chemin local, le retourner
        if ($packageArg -and ($packageArg.StartsWith("./") -or $packageArg.StartsWith("../") -or [System.IO.Path]::IsPathRooted($packageArg))) {
            return $packageArg
        }
        
        # Sinon, c'est probablement un package npm
        return $null
    }
    
    return $null
}

# Fonction principale pour analyser tous les serveurs MCP
function Test-AllMcpServers {
    param (
        [switch]$Update = $false
    )
    
    # Vérifier que le fichier de configuration existe
    if (-not (Test-Path $configPath)) {
        Write-ColorOutput "Le fichier de configuration Claude Desktop n'a pas été trouvé à l'emplacement : $configPath" "Red"
        return
    }
    
    # Lire la configuration
    try {
        $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    } catch {
        Write-ColorOutput "Erreur lors de la lecture du fichier de configuration : $_" "Red"
        return
    }
    
    # Vérifier que des serveurs MCP sont configurés
    if (-not $config.mcpServers -or ($config.mcpServers | Get-Member -MemberType NoteProperty).Count -eq 0) {
        Write-ColorOutput "Aucun serveur MCP n'est configuré dans le fichier de configuration." "Yellow"
        return
    }
    
    # Parcourir chaque serveur MCP
    $serverCount = ($config.mcpServers | Get-Member -MemberType NoteProperty).Count
    $analyzedCount = 0
    $skippedCount = 0
    $failedCount = 0
    
    Write-ColorOutput "=== Analyse des serveurs MCP pour Claude Desktop ===" "Cyan"
    Write-ColorOutput "Nombre de serveurs MCP détectés : $serverCount" "Cyan"
    Write-ColorOutput ""
    
    foreach ($mcpName in ($config.mcpServers | Get-Member -MemberType NoteProperty).Name) {
        $mcpConfig = $config.mcpServers.$mcpName
        
        Write-ColorOutput "Analyse du serveur MCP '$mcpName'..." "White"
        Write-Log "===== Début de l'analyse du serveur MCP '$mcpName' =====" -Level "INFO"
        
        # Collecter les informations de base sur le serveur
        $serverInfo = @{
            Name = $mcpName
            Command = $mcpConfig.command
            Args = $mcpConfig.args
            Environment = if ($mcpConfig.env) { $mcpConfig.env } else { @{} }
        }
        
        # Obtenir le chemin du serveur MCP
        $mcpPath = Get-McpPath -Command $mcpConfig.command -Arguments $mcpConfig.args
        
        if (-not $mcpPath) {
            Write-ColorOutput "  Impossible de déterminer le chemin du serveur MCP '$mcpName'." "Yellow"
            Write-Log "Impossible de déterminer le chemin pour '$mcpName'." -Level "WARN"
            
            $serverInfo.Status = "SKIPPED"
            $serverInfo.Error = "Unable to determine path"
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $skippedCount++
            continue
        }
        
        if (-not (Test-Path $mcpPath)) {
            Write-ColorOutput "  Le chemin détecté '$mcpPath' n'existe pas." "Yellow"
            Write-Log "Le chemin détecté '$mcpPath' n'existe pas pour '$mcpName'." -Level "WARN"
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "SKIPPED"
            $serverInfo.Error = "Path does not exist"
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $skippedCount++
            continue
        }
        
        Write-ColorOutput "  Chemin détecté : $mcpPath" "Gray"
        Write-Log "Chemin détecté pour '$mcpName': $mcpPath" -Level "INFO"
        
        # Vérifier si c'est un repository Git en cherchant aussi dans les dossiers parents
        if (-not (Test-GitRepository $mcpPath)) {
            Write-ColorOutput "  Ce n'est pas un repository Git (ni aucun dossier parent)." "Yellow"
            Write-Log "Le chemin '$mcpPath' n'est pas un repository Git (ni aucun dossier parent)." -Level "WARN"
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "SKIPPED"
            $serverInfo.IsGitRepo = $false
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $skippedCount++
            continue
        }
        
        # Analyser le repository
        Write-ColorOutput "  Analyse du repository Git..." "Gray"
        $analysisResult = Test-GitRepositoryUpdate -Path $mcpPath -McpName $mcpName
        
        if ($analysisResult.Error) {
            $errorMsg = if ([string]::IsNullOrEmpty($analysisResult.Error)) { "Erreur inconnue" } else { $analysisResult.Error }
            Write-ColorOutput "  Erreur lors de l'analyse du repository : $errorMsg" "Red"
            Write-Log "Erreur lors de l'analyse du repository '$mcpPath': $errorMsg" -Level "ERROR"
            
            $serverInfo.Path = $mcpPath
            $serverInfo.Status = "FAILED"
            $serverInfo.Error = $errorMsg
            $detailedAnalysis[$mcpName] = $serverInfo
            
            $failedCount++
        } else {
            # Statut de mise à jour
            $updateStatus = $analysisResult.UpdateStatus
            Write-ColorOutput "  Statut de mise à jour : $updateStatus" -ForegroundColor $(if ($analysisResult.IsUpToDate) { "Green" } else { "Yellow" })
            
            # Type de projet
            $projectType = $analysisResult.ProjectType
            $language = $analysisResult.Language
            Write-ColorOutput "  Type de projet détecté : $projectType ($language)" "Gray"
            
            # Instructions de build
            if ($analysisResult.ProjectDetails.HasBuildScript) {
                Write-ColorOutput "  Script de build détecté : $($analysisResult.ProjectDetails.BuildCommand)" "Gray"
            }
            
            # Changements locaux
            if ($analysisResult.HasLocalChanges) {
                Write-ColorOutput "  Attention : Des modifications locales non validées ont été détectées." "Yellow"
            }
            
            # Commandes spécifiques au langage pour mise à jour
            switch ($projectType) {
                "Node.js" {
                    Write-ColorOutput "  Commandes pour mise à jour Node.js :" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    Write-ColorOutput "    - npm install" "Gray"
                    if ($analysisResult.ProjectDetails.HasBuildScript) {
                        Write-ColorOutput "    - $($analysisResult.ProjectDetails.BuildCommand)" "Gray"
                    }
                }
                "Python" {
                    Write-ColorOutput "  Commandes pour mise à jour Python :" "Gray"
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
                    Write-ColorOutput "  Commandes pour mise à jour Go :" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    Write-ColorOutput "    - go mod download" "Gray"
                    Write-ColorOutput "    - go build" "Gray"
                }
                "JVM" {
                    Write-ColorOutput "  Commandes pour mise à jour JVM :" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    if ($analysisResult.ProjectDetails.HasMaven) {
                        Write-ColorOutput "    - mvn clean install" "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasGradlew) {
                        Write-ColorOutput "    - ./gradlew build" "Gray"
                    }
                }
                "Rust" {
                    Write-ColorOutput "  Commandes pour mise à jour Rust :" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    Write-ColorOutput "    - cargo build" "Gray"
                }
                ".NET" {
                    Write-ColorOutput "  Commandes pour mise à jour .NET :" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    Write-ColorOutput "    - dotnet restore" "Gray"
                    Write-ColorOutput "    - dotnet build" "Gray"
                }
                "C/C++" {
                    Write-ColorOutput "  Commandes pour mise à jour C/C++ :" "Gray"
                    Write-ColorOutput "    - git pull" "Gray"
                    if ($analysisResult.ProjectDetails.HasCMakeLists) {
                        Write-ColorOutput "    - cmake -B build" "Gray"
                        Write-ColorOutput "    - cmake --build build" "Gray"
                    } elseif ($analysisResult.ProjectDetails.HasMakefile) {
                        Write-ColorOutput "    - make" "Gray"
                    }
                }
                default {
                    Write-ColorOutput "  Type de projet non reconnu. Mise à jour standard Git :" "Gray"
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
        Write-Log "===== Fin de l'analyse du serveur MCP '$mcpName' =====" -Level "INFO"
    }
    
    # Afficher le résumé
    Write-ColorOutput "=== Résumé de l'analyse ===" "Cyan"
    Write-ColorOutput "Serveurs MCP détectés : $serverCount" "White"
    Write-ColorOutput "Serveurs analysés avec succès : $analyzedCount" "Green"
    Write-ColorOutput "Serveurs ignorés : $skippedCount" "Yellow"
    Write-ColorOutput "Serveurs avec erreurs : $failedCount" "Red"
    Write-ColorOutput ""
    
    # Enregistrer l'analyse détaillée au format JSON
    $detailedAnalysisJson = ConvertTo-Json -InputObject $detailedAnalysis -Depth 6
    Set-Content -Path $detailedLogFile -Value $detailedAnalysisJson
    
    Write-ColorOutput "Analyse détaillée enregistrée dans : $detailedLogFile" "Gray"
    Write-ColorOutput "Journal des opérations enregistré dans : $logFile" "Gray"
    
    # Proposer la mise à jour si demandé et si des serveurs à mettre à jour sont détectés
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
            Write-ColorOutput "Serveurs MCP qui peuvent être mis à jour ($($serversToUpdate.Count)):" "Cyan"
            
            foreach ($mcpName in $serversToUpdate) {
                $behind = $detailedAnalysis[$mcpName].Analysis.Behind
                Write-ColorOutput "  - $mcpName ($behind commits en retard)" "Yellow"
            }
            
            Write-ColorOutput ""
            $confirmation = Read-Host "Voulez-vous mettre à jour ces serveurs MCP ? (O/N)"
            
            if ($confirmation -eq "O" -or $confirmation -eq "o") {
                $updatedCount = 0
                $updateFailedCount = 0
                
                foreach ($mcpName in $serversToUpdate) {
                    $serverInfo = $detailedAnalysis[$mcpName]
                    
                    Write-ColorOutput "Mise à jour du serveur MCP '$mcpName'..." "Cyan"
                    Write-Log "===== Début de la mise à jour du serveur MCP '$mcpName' =====" -Level "INFO"
                    
                    $updateResult = Update-GitRepository -Path $serverInfo.Path -McpName $mcpName -Analysis $serverInfo.Analysis
                    
                    if ($updateResult) {
                        $updatedCount++
                        Write-Log "Mise à jour réussie du serveur MCP '$mcpName'" -Level "INFO"
                    } else {
                        $updateFailedCount++
                        Write-Log "Échec de la mise à jour du serveur MCP '$mcpName'" -Level "ERROR"
                    }
                    
                    Write-ColorOutput ""
                    Write-Log "===== Fin de la mise à jour du serveur MCP '$mcpName' =====" -Level "INFO"
                }
                
                Write-ColorOutput "=== Résumé de la mise à jour ===" "Cyan"
                Write-ColorOutput "Serveurs MCP mis à jour avec succès : $updatedCount" "Green"
                Write-ColorOutput "Serveurs MCP avec erreurs de mise à jour : $updateFailedCount" "Red"
                Write-ColorOutput ""
                Write-ColorOutput "Pour que les changements prennent effet, veuillez redémarrer Claude Desktop." "Cyan"
            } else {
                Write-ColorOutput "Mise à jour annulée." "Yellow"
            }
        } else {
            Write-ColorOutput ""
            Write-ColorOutput "Tous les serveurs MCP sont à jour. Aucune mise à jour nécessaire." "Green"
        }
    }
}

# Point d'entrée principal
param (
    [switch]$Update,
    [switch]$ForceUpdate,
    [string]$Language = "fr"
)

try {
    # Définir un gestionnaire d'erreurs pour intercepter les erreurs liées aux chaînes vides
    $ErrorActionPreference = "Continue"
    
    Write-ColorOutput "=== Démarrage de l'outil de mise à jour des serveurs MCP ===" "Cyan"
    Write-Log "=== Démarrage de l'outil de mise à jour des serveurs MCP ===" -Level "INFO"
    
    # Créer le répertoire MCP-Scripts s'il n'existe pas
    $scriptsDir = [System.IO.Path]::GetDirectoryName($logFile)
    if (-not (Test-Path $scriptsDir)) {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    }
    
    # Exécuter l'analyse avec option de mise à jour
    if ($ForceUpdate) {
        # Forcer la mise à jour sans confirmation
        Test-AllMcpServers -Update
        # Répondre automatiquement "O" à l'invite de mise à jour
        # Cela nécessiterait de modifier la fonction Test-AllMcpServers
    } else {
        Test-AllMcpServers -Update:$Update
    }
    
    Write-ColorOutput "=== Fin de l'outil de mise à jour des serveurs MCP ===" "Cyan"
    Write-Log "=== Fin de l'outil de mise à jour des serveurs MCP ===" -Level "INFO"
    
    # Attendre que l'utilisateur appuie sur une touche pour fermer
    Write-ColorOutput "Appuyez sur une touche pour fermer..." "Gray"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} catch {
    # Gérer l'erreur spécifique liée aux chaînes vides
    if ($_.Exception.Message -match "chaîne vide") {
        Write-Host "Erreur liée à une chaîne vide détectée et ignorée." -ForegroundColor Yellow
        Write-Log "Erreur liée à une chaîne vide détectée et ignorée: $_" -Level "WARN"
    } else {
        Write-ColorOutput "Une erreur inattendue s'est produite : $_" "Red"
        Write-Log "Erreur inattendue : $_" -Level "ERROR"
    }
    
    # Attendre que l'utilisateur appuie sur une touche pour fermer
    Write-ColorOutput "Appuyez sur une touche pour fermer..." "Gray"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
