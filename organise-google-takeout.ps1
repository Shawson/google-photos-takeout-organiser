$InformationPreference = 'Continue'
$moveFolders = $true

# Get all subdirectories in the current directory
$folders = Get-ChildItem -Directory |  Where-Object { -not ($_.Name -match '^\d{4}$') }

foreach ($folder in $folders) {
    $folderPath = $folder.FullName

    # Get all files that are not JSON files
    $nonJsonFiles = Get-ChildItem -Path $folder.FullName -File | Where-Object Extension -ne ".json"
    $fileProcessingError = $false
    foreach ($file in $nonJsonFiles) {

        # Check if the JSON metadata file exists for the current file

        $extension = $file.Extension.TrimStart('.') 
        $fileNameWithEditedRemoved = $file.Name -replace '-edited', ''
        $fileNameForMetaLookup = $fileNameWithEditedRemoved

        if ($fileNameForMetaLookup.Length -gt 46) {
            $fileNameForMetaLookup = $fileNameForMetaLookup.Substring(0, 46)
        }

        $metaFilePath = "$($folder.FullName)\$($fileNameForMetaLookup).json"

        if (-not (Test-Path -Path $metaFilePath)) {
            # Handle () on duplicates having the wrong json path
            Write-Information "Failed to find meta data at $metaFilePath"

            $fileNameForMetaLookup = $fileNameWithEditedRemoved

            $patternExtension = "(?<! )\((\d+)\)\.$extension" 
            $replacement = ".$extension(`$1)"
            $fileNameForMetaLookup = $fileNameForMetaLookup -replace $patternExtension, $replacement

            if ($fileNameForMetaLookup.Length -gt 46) {
                $fileNameForMetaLookup = $fileNameForMetaLookup.Substring(0, 46)
            }

            $metaFilePath = "$($folder.FullName)\$($fileNameForMetaLookup).json"
        }

        if (-not (Test-Path -Path $metaFilePath)) {
            # Handle () on duplicates having the wrong json path - no truncating

            Write-Information "Failed to find meta data at $metaFilePath"

            $fileNameForMetaLookup = $fileNameWithEditedRemoved

            $patternExtension = "(?<! )\((\d+)\)\.$extension" 
            $replacement = ".$extension(`$1)"
            $fileNameForMetaLookup = $fileNameForMetaLookup -replace $patternExtension, $replacement

            $metaFilePath = "$($folder.FullName)\$($fileNameForMetaLookup).json"

        }

        
        if (-not (Test-Path -Path $metaFilePath)) {
            # Handle weird HEIC file

            Write-Information "Failed to find meta data at $metaFilePath"

            $fileNameForMetaLookup = $fileNameWithEditedRemoved
            $fileNameForMetaLookup = $file.Name -replace ".$($extension)", '.HEIC'
            $patternExtension = "(?<! )\((\d+)\)\.HEIC" 
            $replacement = ".HEIC(`$1)"
            $fileNameForMetaLookup = $fileNameForMetaLookup -replace $patternExtension, $replacement

            if ($fileNameForMetaLookup.Length -gt 46) {
                $fileNameForMetaLookup = $fileNameForMetaLookup.Substring(0, 46)
            }

            $metaFilePath = "$($folder.FullName)\$($fileNameForMetaLookup).json"

        }

        if (-not (Test-Path -Path $metaFilePath) -and ($extension -eq "MP4")) {
            # Handle weird HEIC file

            Write-Information "Failed to find meta data at $metaFilePath"

            $fileNameForMetaLookup = $fileNameWithEditedRemoved
            $fileNameForMetaLookup = $file.Name -replace ".$($extension)", '.jpg'
            $patternExtension = "(?<! )\((\d+)\)\.JPG" 
            $replacement = ".JPG(`$1)"
            $fileNameForMetaLookup = $fileNameForMetaLookup -replace $patternExtension, $replacement

            if ($fileNameForMetaLookup.Length -gt 46) {
                $fileNameForMetaLookup = $fileNameForMetaLookup.Substring(0, 46)
            }

            $metaFilePath = "$($folder.FullName)\$($fileNameForMetaLookup).json"

        }
        
        if (-not (Test-Path -Path $metaFilePath)) {
            Write-Information "Failed to find meta data at $metaFilePath"

            Write-Warning "Unable to locate metadata file for '$($file.Name)'"
            $fileProcessingError = $true
            continue
        } 

        # Read the metadata.json file for the current non-JSON file
        $jsonContent = Get-Content -Path $metaFilePath | Out-String
        $jsonData = $jsonContent | ConvertFrom-Json
        
        # Extract the Unix timestamp and convert it to DateTime
        $unixTimestamp = $jsonData.photoTakenTime.timestamp

        if ($unixTimestamp -eq 0) {
            Write-Warning "Invalid 0 datetime stamp in file metadata for folder '$($file.Name)'.  File processing skipping..."
            $fileProcessingError = $true
            continue
        }

        $dateTime = [datetimeoffset]::FromUnixTimeSeconds($unixTimestamp).DateTime

        # Update the creation and last write time of the file
        $null = Set-ItemProperty -Path $file.FullName -Name creationtime -Value $dateTime
        $null = Set-ItemProperty -Path $file.FullName -Name lastwritetime -Value $dateTime
    }
   
    if ($fileProcessingError -eq $true) {
        Write-Warning "Abandoning processing of folder '$($folder.Name)' due to file processing error"
        continue
    }

    # figure out folders date time stamp based on the media
    $oldestMedia = Get-ChildItem -Path $folder.FullName -File | Where-Object Extension -ne ".json" | Sort-Object CreationTime | Select-Object -First 1

    if ($oldestMedia -ne $null) {
        # Use the oldest picture's creation time as the fallback date
        $dateTime = $oldestMedia.CreationTime.DateTime

        Write-Information "Using the oldest picture's date $($dateTime) as fallback for folder '$($folder.Name)'"

        $null = Set-ItemProperty -Path $folderPath -Name creationtime -Value $dateTime
        $null = Set-ItemProperty -Path $folderPath -Name lastwritetime -Value $dateTime

        $folder.CreationTime = $dateTime
    } else {
        Write-Warning "No pictures found in folder '$($folder.Name)' for fallback. Folder processing skipping..."
        continue
    }

    # Determine the year from the folder's creation time
    $year = $folder.CreationTime.Year

    # Construct the path for the year sub-folder
    $yearFolderPath = Join-Path -Path $PSScriptRoot -ChildPath $year

    # Check if the year sub-folder exists, if not, create it
    if (-not (Test-Path -Path $yearFolderPath)) {
        if ($moveFolders -eq $true) {
            New-Item -Path $yearFolderPath -ItemType Directory
            Write-Information "Creating new year subfolder '$($yearFolderPath)'"
        }         
    }

    # Construct the new path for the folder within the year sub-folder
    $newFolderPath = Join-Path -Path $yearFolderPath -ChildPath $folder.Name

    # Move the folder to the year sub-folder
    # Check if a folder with the same name already exists in the destination to avoid errors
    if (-not (Test-Path -Path $newFolderPath)) {
        if ($moveFolders -eq $true) {
            Move-Item -Path $folder.FullName -Destination $newFolderPath
        } else {
            Write-Information "Simulated Folder move from '$($folder.FullName)' to '$($newFolderPath)'"
        }
    } else {
        Write-Warning "A folder with the name '$($folder.Name)' already exists in '$yearFolderPath'. Folder year move skipping..."
    }
}