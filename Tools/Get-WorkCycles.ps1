# Function to be used with runspaces
function Get-WorkCycles {
    [CmdletBinding()]
    Param (
        [int]$Count
    )

    # From the base number, decide how big each group should be
    $size = ($count.ToString().Length) - 2
    $scale = [math]::pow(10,$size)
    if ($scale -gt 1000) {
        $scale = 1000
    }

    $groups = New-Object Collections.ArrayList

    # If there's a remainder when you divide by scale, kick it off to the side
    if ($count % $scale) {
        $a = [math]::truncate($count / $scale)
        $b = ($count % $scale)
    } else {
        $a = ($count / $scale)
    }

    # How many groups of scale will it take to complete the entire job?
    for ($i=1;$i -lt ($a + 1);$i++) {
        $total = $i * $scale
        $start = ($total - $scale)
        $end = ($total - 1)
        $temp = [PsCustomObject]@{
            Group = $i
            Start = $start
            End = $end
        }
        $groups.Add($temp) | Out-Null
    }

    # If there WAS a remainder, make a final group to tackle it
    if ($b) {
        $temp = [PsCustomObject]@{
            Group = $i
            Start = ($end + 1)
            End = ($end + $b)
        }
        $groups.Add($temp) | Out-Null
    }

    # Return the object to be consumed
    return $groups
}
