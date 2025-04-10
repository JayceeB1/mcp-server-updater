# English strings for Update-MCP-Servers.ps1
@{
    CreatingLogDir = 'Creating log directory: {0}'
    CreatingLogFile = 'Creating log file: {0}'
    CreatingDetailedLogFile = 'Creating detailed log file: {0}'
    ErrorExtractingRemoteUrl = 'Error extracting remote URL: {0}'
    ErrorReadingPackageJson = 'Error reading package.json: {0}'
    PathNotGitRepo = "The path '{0}' is not a valid Git repository."
    StatusRemoteBranchNotFound = 'Remote branch not found or not accessible'
    StatusErrorCheckingUpdates = 'Error checking for updates'
    StatusUpToDate = 'Up to date'
    StatusUpdatesAvailable = 'Updates available ({0} commits behind)'
    ErrorAnalyzingRepo = 'Error analyzing repository: {0}'
    UpdatingServer = "  Updating MCP server '{0}'..."
    LocalChangesBackedUp = '  Local changes backed up in branch {0}'
    RunningGitPull = "  Running 'git pull origin {0}'..."
    ErrorUpdating = '  Error updating: {0}'
    ServerUpdated = "  MCP server '{0}' updated from {1} to {2}"
    InstallingNodeDeps = '  Installing Node.js dependencies...'
    BuildingProject = '  Building project...'
    InstallingPipenvDeps = '  Installing Python dependencies (pipenv)...'
    InstallingPipDeps = '  Installing Python dependencies (pip)...'
    InstallingPythonPackage = '  Installing Python package...'
    InstallingGoDeps = '  Installing Go dependencies...'
    BuildingGoProject = '  Building Go project...'
    BuildingMavenProject = '  Building Maven project...'
    BuildingGradleProject = '  Building Gradle project...'
    BuildingRustProject = '  Building Rust project...'
    RestoringNetDeps = '  Restoring .NET dependencies...'
    BuildingNetProject = '  Building .NET project...'
    GeneratingCMakeProject = '  Generating CMake project...'
    BuildingCMakeProject = '  Building CMake project...'
    BuildingMakeProject = '  Building Make project...'
    ErrorConvertingPath = "Error converting path '{0}' to absolute path: {1}"
    ScriptPathNotExist = "Script path '{0}' does not exist."
    ConfigNotFound = 'Claude Desktop configuration file not found at: {0}'
    ErrorReadingConfig = 'Error reading configuration file: {0}'
    NoServersConfigured = 'No MCP servers are configured in the configuration file.'
    AnalyzingServersTitle = '=== Analyzing MCP Servers for Claude Desktop ==='
    ServersDetected = 'MCP servers detected: {0}'
    AnalyzingServer = "Analyzing MCP server '{0}'..."
    UnableToDeterminePath = "  Unable to determine path for MCP server '{0}'."
    DetectedPathNotExist = "  Detected path '{0}' does not exist."
    DetectedPath = '  Detected path: {0}'
    NotAGitRepo = '  Not a Git repository (or any parent directory).'
    AnalyzingGitRepo = '  Analyzing Git repository...'
    UnknownError = 'Unknown error'
    ErrorAnalyzingRepoDetailed = '  Error analyzing repository: {0}'
    UpdateStatus = '  Update status: {0}'
    DetectedProjectType = '  Detected project type: {0} ({1})'
    BuildScriptDetected = '  Build script detected: {0}'
    WarningLocalChanges = '  Warning: Uncommitted local changes detected.'
    NodeUpdateCommands = '  Node.js update commands:'
    PythonUpdateCommands = '  Python update commands:'
    GoUpdateCommands = '  Go update commands:'
    JvmUpdateCommands = '  JVM update commands:'
    RustUpdateCommands = '  Rust update commands:'
    NetUpdateCommands = '  .NET update commands:'
    CUpdateCommands = '  C/C++ update commands:'
    UnrecognizedProjectType = '  Unrecognized project type. Standard Git update:'
    GitPullCommand = '    - git pull'
    NpmInstallCommand = '    - npm install'
    NpmBuildCommand = '    - {0}' # Placeholder for actual build command
    PipenvInstallCommand = '    - pipenv install'
    PipInstallRequirementsCommand = '    - pip install -r requirements.txt'
    PipInstallEditableCommand = '    - pip install -e .'
    GoModDownloadCommand = '    - go mod download'
    GoBuildCommand = '    - go build'
    MvnCleanInstallCommand = '    - mvn clean install'
    GradlewBuildCommand = '    - ./gradlew build'
    CargoBuildCommand = '    - cargo build'
    DotnetRestoreCommand = '    - dotnet restore'
    DotnetBuildCommand = '    - dotnet build'
    CMakeGenerateCommand = '    - cmake -B build'
    CMakeBuildCommand = '    - cmake --build build'
    MakeCommand = '    - make'
    AnalysisSummaryTitle = '=== Analysis Summary ==='
    ServersAnalyzed = 'MCP servers successfully analyzed: {0}'
    ServersSkipped = 'MCP servers skipped: {0}'
    ServersFailed = 'MCP servers with errors: {0}'
    DetailedLogSaved = 'Detailed analysis saved to: {0}'
    LogSaved = 'Operations log saved to: {0}'
    ServersToUpdateTitle = 'MCP servers that can be updated ({0}):'
    ServerUpdateInfo = '  - {0} ({1} commits behind)'
    UpdatePrompt = 'Do you want to update these MCP servers? (Y/N)'
    UpdateSummaryTitle = '=== Update Summary ==='
    ServersUpdated = 'MCP servers successfully updated: {0}'
    ServersUpdateFailed = 'MCP servers with update errors: {0}'
    RestartRequired = 'To apply the changes, please restart Claude Desktop.'
    UpdateCanceled = 'Update canceled.'
    AllServersUpToDate = 'All MCP servers are up to date. No updates needed.'
    StartingUpdater = '=== Starting MCP Server Updater ==='
    UpdaterCompleted = '=== MCP Server Updater Completed ==='
    PressAnyKey = 'Press any key to exit...'
    EmptyStringErrorIgnored = 'Empty string error detected and ignored.'
    UnexpectedError = 'An unexpected error occurred: {0}'
}