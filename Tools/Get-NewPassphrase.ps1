function Get-NewPassphrase {
    [CmdletBinding()]
    param (
        [Parameter(
            HelpMessage="Choose how many words are in your passphrase. Must be between 2-8. Default is 3."
        )]
        [ValidateRange(2,8)]
        [int]$WordCount = 3,

        [Parameter()]
        [switch]$AddPunctuation
    )

    begin {
        # Add the necessary assembly
        Add-Type -AssemblyName System.Windows.Forms

        # Which region is the OS?
        $Region = (Get-WinSystemLocale).Name

        # Define the root path of the "dictionaries"
        $Paths = @(
            "C:\Windows\Help",
            "C:\Windows\System32\$Region\Licenses"
        )

        # Blank array that will store raw "dictionary" data
        $Content = @()
    }

    process {
        # Find the necessary files to root words from
        foreach ($Path in $Paths) {
            $File = Get-ChildItem -Path $Path -Recurse -File -Filter *.rtf | Sort-Object -Property Length -Descending | Select-Object -First 1

            if (-Not($File)) { continue }

            # Create the object that will read the .rtf file then read the file
            $RichTextObject = New-Object -TypeName System.Windows.Forms.RichTextBox
            $RichTextObject.Rtf = [System.IO.File]::ReadAllText("$($File.FullName)")
            $Content += $RichTextObject.Text
        }
        
        # Define the "dictionary"
        $Words = ($Content -Split "\s+").ToLower().Trim()

        # It's not necessary to make it alphabetical but since dictionaries ARE, might as well
        $Dictionary = $Words.Where{$_ -notmatch "\W|[0-9_]"} | Select-Object -Unique | Sort-Object

        # Generate the passphrase
        $Passphrase = (Get-Random -Count $WordCount -InputObject $Dictionary | ForEach-Object {$_.substring(0,1).ToUpper()+$_.substring(1).ToLower()})

        if ($AddPunctuation) {
            $Count = Get-Random -Minimum 1 -Maximum $WordCount
            $Punctuation = {Get-Random -InputObject @("!", "?", ".")}

            if ($Count -eq 1) {
                $Passphrase[-1] = "$($Passphrase[-1])$(&$Punctuation)"
            } else {
                $Positions = Get-Random -Count $Count -InputObject (0..($WordCount-1))
                foreach ($Position in $Positions) {
                    $Passphrase[$Position] = "$($Passphrase[$Position])$(&$Punctuation)"
                }
            }
        }
        
        # Assemble the passphrase so it's a "sentence" and not an array
        $Passphrase = $Passphrase -Join " "
    }

    end {
        # Remove objects for garbage collection
        $RichTextObject.Dispose()
        return $Passphrase
    }

}
