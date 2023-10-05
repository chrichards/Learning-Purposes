function Create-Zip {
    Param (
        [Parameter(Mandatory=$true)]
        $Source,

        [Parameter(Mandatory=$true)]
        [string]$Destination,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Optimal','Fastest','NoCompression')]
        [string]$CompressionType = 'Optimal'
    )

    begin {
        # Load required assemblies
        Add-Type -AssemblyName System.IO.Compression
        Add-Type -AssemblyName System.IO.Compression.FileSystem

        # Set the compression level for the archive
        $CompressionLevel = [System.IO.Compression.CompressionLevel]::$CompressionType

        # Set the zip write method type
        $Update = [System.IO.Compression.ZipArchiveMode]::Update

        $n = 0
    }

    process {
        # Create the base zip archive
        [System.IO.Compression.ZipArchive]$Archive = [System.IO.Compression.ZipFile]::Open($Destination,$Update)

        while (-not(Test-Path $Destination)) {
            Start-Sleep -Milliseconds 50
        }

        $OverallCount = $Source.Count

        foreach ($Item in $Source) {
            # Overall progress update
            $ParentProgress = @{
                Activity         = 'Creating zip archive'
                Status           = "Processing $($n + 1) of $OverallCount"
                PercentComplete  = ([int]($n/$OverallCount * 100))
                CurrentOperation = "$item"
            }
            Write-Progress @ParentProgress

            # If there's more than one folder being zipped, create the parent folders
            # to keep files separated and organized
            if ($OverallCount -gt 1) {
                $Split = $Item.Split("\")
                $Name  = $Split[-1]
                $Item  = $Split[0..$($Split.Count - 2)] -Join "\"
                [void]$Archive.CreateEntry("$Name\")

                # Get all files within the folder
                $Children = Get-ChildItem -Path "$Item\$Name" -Recurse -Force
            } else {
                $Children = Get-ChildItem -Path $Item -Recurse -Force
            }

            # For inner loop progress purposes            
            $ChildCount = $Children.Count
            $i = 0
            foreach ($Child in $Children){
                # Child progress update
                $ChildProgress = @{
                    Activity         = 'Adding item to archive'
                    Status           = "Processing $($i + 1) of $ChildCount"
                    PercentComplete  = ([int]($i/$ChildCount * 100))
                    CurrentOperation = "$($Child.Name)"
                }
                Write-Progress @ChildProgress

                if ($Child.PSIsContainer){
                    # make a name that honors file structure
                    $ChildPath = $Child.FullName -Replace [Regex]::Escape("$Item\")
                    if ($ChildPath) {
                        $Name = $ChildPath
                    } else {
                        $Name = $Child.Name
                    }

                    # create the directory inside the archive
                    [void]$Archive.CreateEntry("$Name\")
                } else {
                    # figure out where in the structure the file should reside
                    $ChildPath = $Child.FullName -Replace [Regex]::Escape("$Item\") -Replace "$($Child.Name)"
                    if ($ChildPath -match '\\') {
                        # at least one subdirectory exists
                        $Name = $ChildPath + $Child.Name
                    } else {
                        $Name = $Child.Name
                    }

                    try {
                        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive,$Child.FullName,$Name,$CompressionLevel)
                    } catch {
                        # make temporary file if original is open with another process
                        $Temp = Get-Content -Path $Child.FullName -Raw
                        $TempFile = [System.IO.Path]::GetTempFileName()
                        $Temp | Out-File $TempFile
                        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($Archive,$TempFile,$Name,$CompressionLevel)
                        Remove-Item -Path $TempFile -Force
                        $Temp = $TempFile = $Null
                    }
                }

                $i++
            }
            $n++
        }
    }

    end {
        $Archive.Dispose()
    }
}
