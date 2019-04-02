Param(
  [Parameter(Mandatory=$true)]
  [string]$source
)

# Load required assemblies
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Define paths
$here = (Get-Item -Path .\).FullName
$dest = "$source.zip"

# A blank directory needs to be made to create the zip archive
$test = "$here\Test"
if(test-path $test){
    remove-item -path $test -force
}
else{
    new-item -path .\ -name "Test" -itemtype Directory
}

# Set the compression level for the archive
$compressionlevel = [System.IO.Compression.CompressionLevel]::Optimal

# Create zip archive
[System.IO.Compression.ZipFile]::CreateFromDirectory($test,$dest,$compressionlevel,$false)

# Dispose of empyt shell folder
remove-item -path $test -force

# Get a listing of all the file paths necessary to create
$children = get-childitem -path $source -recurse -force
$count = $children.Count
$count
$i = 0

$update = [System.IO.Compression.ZipArchiveMode]::Update
[System.IO.Compression.ZipArchive]$archive = [System.IO.Compression.ZipFile]::Open($dest,$update)

foreach($child in $children){
    if($child.PSIsContainer){
        # make a name that honors file structure
        $path = ($($child.FullName).Replace(($source + "\"),''))
        if($path){
            $name = $path.Replace("\","/")
        }
        else{
            $name = $child.Name
        }

        # create the directory inside the archive
        $archive.CreateEntry("$name/")
    }
    else{
        # figure out where in the structure the file should reside
        $path = ($child.FullName).Replace(($source + "\"),'').Replace($child.Name,'')
        if($path -match '\\'){
            # at least one subdirectory exists
            $name = $path.Replace("\","/") + $child.Name
        }
        else{
            $name = $child.Name
        }

        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$child.FullName,$name,$compressionlevel)
        $i++
    }

}

$archive.Dispose()
