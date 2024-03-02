# Request user input for $Source and $Target paths
$Source = Read-Host "Type the Source path. Ex. C:\temp\folder\"
$Target = Read-Host "Type the Target path. Ex. D:\folder\"
$LogFilePath = Read-Host "Type the Log path. Ex. D:\temp\Log"

# Log Path
$GetDate = Get-Date -Format "ddMMyyyy"
$LogFile = "$LogFilePath\BKP_$GetDate.txt"

# Function to synchronize folders
function Sync-Folders {
    param(
        [string]$sourcePath,
        [string]$targetPath
    )

    # Log initial synchronization
    "Synchronization started at $(Get-Date)" | Out-File -Append -FilePath $LogFile

    # Copy existing files and directories to the target
    Copy-Item -Path $sourcePath\* -Destination $targetPath -Recurse -Force

    # Log initial synchronization completion
    "Synchronization completed at $(Get-Date)" | Out-File -Append -FilePath $LogFile
}

# Check if the directories exist; if not, create them with user approval
foreach ($path in ($Source, $Target, $LogFilePath)) {
    if (-not (Test-Path $path)) {
        $createPath = Read-Host "The path $path doesn't exist. Do you want to create it? (Y/N)"
        if ($createPath -eq 'Y') {
            New-Item -ItemType Directory -Path $path | Out-Null
        } else {
            Write-Host "Operation cancelled"
            exit
        }
    }
}

# Perform initial synchronization
Sync-Folders -sourcePath $Source -targetPath $Target

# Watch for changes in the source folder
$Watcher = New-Object System.IO.FileSystemWatcher $Source
$Watcher.Filter = "*.*"
$Watcher.IncludeSubdirectories = $true

# Event handler for file changes (Changed, Created, Deleted, or Renamed)
$action = {
    $eventArgs = $Event.SourceEventArgs

    $relativePath = $eventArgs.FullPath.Substring($Source.Length + 1)
    $targetFilePath = Join-Path $Target -ChildPath $relativePath

    # Wait for a short delay to ensure the file is fully written
    Start-Sleep -Seconds 2

    if ($eventArgs.ChangeType -eq 'Renamed') {
        # If file is renamed, update the target file name
        $newRelativePath = $eventArgs.OldFullPath.Substring($Source.Length + 1)
        $oldTargetFilePath = Join-Path $Target -ChildPath $newRelativePath
        Rename-Item -Path $oldTargetFilePath -NewName $relativePath -Force
    } elseif ($eventArgs.ChangeType -eq 'Deleted') {
        # If file is deleted, remove it from the target directory
        Remove-Item $targetFilePath -Force

        # Log the file deletion
        $logContent = "File '$relativePath' deleted from '$Target'"
        $logContent | Out-File -Append -FilePath $LogFile
        Write-Host $logContent
    } else {
        # Check if the file exists in the target directory
        if (Test-Path $targetFilePath) {
            # Remove the existing file in the target directory
            Remove-Item $targetFilePath -Force
        }

        # Copy the changed/created file to the target folder
        Copy-Item $eventArgs.FullPath -Destination $targetFilePath -Recurse -Force
    }

    # Log the file operation
    $logContent = "File '$relativePath' synchronized to '$Target'"
    $logContent | Out-File -Append -FilePath $LogFile
    Write-Host $logContent
}

# Register event handlers
Register-ObjectEvent -InputObject $Watcher -EventName "Changed" -Action $action
Register-ObjectEvent -InputObject $Watcher -EventName "Created" -Action $action
Register-ObjectEvent -InputObject $Watcher -EventName "Deleted" -Action $action
Register-ObjectEvent -InputObject $Watcher -EventName "Renamed" -Action $action

Write-Host "Synchronization is running. Press Ctrl+C to stop."

# Keep the script running
try {
    while ($true) {
        Start-Sleep -Seconds 0
    }
} finally {
    # Cleanup and stop the FileSystemWatcher
    $Watcher.EnableRaisingEvents = $false
    $Watcher.Dispose()
    
    # Open the directory where the log file is located
    Start-Process explorer.exe $LogFile
}
