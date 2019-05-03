# equivalent to running cleanmgr /sageset:60
# and selecting all boxes

$root = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'

$paths = @(
    'Active Setup Temp Folders',
    'BranchCache',
    'D3D Shader Cache',
    'Delivery Optimization Files',
    'Diagnostic Data Viewer database files',
    'Downloaded Program Files',
    'DownloadsFolder',
    'Internet Cache Files',
    'Language Pack',
    'Old ChkDsk Files',
    'Recycle Bin',
    'RetailDemo Offline Content',
    'Service Pack Cleanup',
    'Setup Log Files',
    'System error memory dump files',
    'System error minidump files',
    'Temporary Files',
    'Thumbnail Cache',
    'Update Cleanup',
    'User file versions',
    'Windows Defender',
    'Windows Error Reporting Files'
)

foreach ($path in $paths) {
    if(-not(test-path "$root\$path")){ new-item $root -name $path }
    new-itemproperty "$root\$path" -name "StateFlags0060" -propertytype dword -value 2 -force
}

# run the disk cleanup utility
start cleanmgr -argumentlist '/sagerun:60'
