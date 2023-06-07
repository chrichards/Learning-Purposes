Param (
    [Parameter(Mandatory=$true)]
    $source,

    [Parameter(Mandatory=$true)]
    [string]$destination,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Optimal','Fastest','NoCompression')]
    [string]$compressiontype = 'Optimal'
)

begin {
    # Load required assemblies
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # Set the compression level for the archive
    $compressionlevel = [System.IO.Compression.CompressionLevel]::$compressiontype

    # Set the zip write method type
    $update = [System.IO.Compression.ZipArchiveMode]::Update

    $i = 0
}

process {
    # Create the base zip archive
    [System.IO.Compression.ZipArchive]$archive = [System.IO.Compression.ZipFile]::Open($destination,$update)

    while (-not(test-path $destination)) {
        start-sleep -milliseconds 50
    }

    foreach ($item in $source) {
        $children = Get-ChildItem -Path $item -Force
        foreach ($child in $children){
            if ($child.PSIsContainer){
                # make a name that honors file structure
                $path = $child.FullName -Replace [Regex]::Escape("$item")
                if ($path) {
                    $name = $path
                } else {
                    $name = $child.Name
                }

                # create the directory inside the archive
                $archive.CreateEntry("$name/")
            } else {
                # figure out where in the structure the file should reside
                $path = $child.FullName -Replace [Regex]::Escape("$item") -Replace "$($child.Name)"
                if ($path -match '\\') {
                    # at least one subdirectory exists
                    $name = $path + $child.Name
                } else {
                    $name = $child.Name
                }

                try {
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$child.FullName,$name,$compressionlevel)
                } catch {
                    # make temporary file if original is open with another process
                    $temp = get-content -path $child.FullName -raw
                    $tempFile = [System.IO.Path]::GetTempFileName()
                    $temp | out-file $tempFile
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$tempFile,$name,$compressionlevel)
                    remove-item -path $tempFile -force
                    $temp = $null; $tempFile = $null
                }
            }

            $i++

        }
    }
}

end {
    $archive.Dispose()
}
