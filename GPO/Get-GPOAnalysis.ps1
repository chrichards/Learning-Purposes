import-module grouppolicy

function Get-GPOBreakdown {
    param (
        [string]$Identity,

        [ValidateSet("Computer","User")]
        [string]$Target,

        $Extensions
    )

    $result = [System.Collections.Generic.List[object]]::new()

    foreach ($extension in $extensions) {
        if (-not($extension)) { continue }
        $class      = ($extension.Type).Split(":")[1]
        $categories = (($extension | Get-Member).Where{
                ($_.MemberType -eq "Property") -and (($_.Name -notlike "q*") -and ($_.Name -notlike "type") -and ($_.Name -notlike "blocked"))
            }).Name
        
        switch ($class) {

            #############################################################
            ####                      Policies                       ####
            #############################################################

            'SoftwareInstallationSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    $type        = "Policy"
                    $config      = $extension.$category
                    $config_path = "Software Settings/Software installation"

                    foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                        $setting = $item.Name 
                        $action  = $item.DeploymentType
                        $element = [PsCustomObject]@{
                            'GPO'     = $identity
                            'Target'  = $target
                            'Type'    = $type
                            'Class'   = $class
                            'Setting' = $setting
                            'Action'  = $action
                            'Path'    = $config_path
                        }

                        $result.Add($element)
                    }
                }
            }

            'Scripts' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'Script' {
                            $type        = 'Policy'
                            $config_path = 'Windows Settings/Scripts'
                            $config = $extension.$category
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting = $item.Type
                                $action  = $item.Command
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'SecuritySettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'Account' {
                            $type        = "Policy"
                            $config      = $extension.$category | Sort-Object -Property 'Type'

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $config_path = "Windows Settings/Security Settings/Account Policies/$($item.Type)"
                                $setting = $item.Name 
                                $action  = $item.SettingNumber
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'Audit' {
                            $type        = "Policy"
                            $config      = $extension.$category
                            $config_path = "Windows Settings/Security Settings/Local Policies/Audit Policy"

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.SuccessAttempts) { $a = 1 } else { $a = 0 }
                                if ($item.FailureAttempts) { $b = 2 } else { $b = 0 }

                                $setting = $item.Name
                                $action  = ($a + $b)
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'UserRightsAssignment' {
                            $type        = "Policy"
                            $config      = $extension.$category
                            $config_path = "Windows Settings/Security Settings/Local Policies/User Rights Assignment"

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting = $item.Name
                                $action  = $item.Member.Name."#text"
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'SecurityOptions' {
                            $type        = "Policy"
                            $config      = $extension.$category
                            $config_path = "Windows Settings/Security Settings/Local Policies/Security Options"

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $property = ($item | Get-Member -MemberType Property).Name

                                if ('Display' -in $property) {
                                    $setting = $item.Display.Name
                                } else {
                                    $setting = $item.SystemAccessPolicyName
                                }
                                
                                $action  = $item.$($property.Where{$_ -match "Setting"})
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'EventLog' {
                            $type        = "Policy"
                            $config      = $extension.$category
                            $config_path = "Windows Settings/Security Settings/Event Log"

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $property = ($item | Get-Member -MemberType Property).Name
                                $setting  = "$($item.Name)`:$($item.Log)"
                                $action   = $item.$($property.Where{$_ -match "Setting"})
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'RestrictedGroups' {
                            $type        = "Policy"
                            $config      = $extension.$category
                            $config_path = "Windows Settings/Security Settings/Restricted Groups"

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting     = 'GroupName'
                                $action      = $item.GroupName.Name."#text"
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'SystemServices' {
                            $type        = "Policy"
                            $config      = $extension.$category
                            $config_path = "Windows Settings/Security Settings/System Services"
                            
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting     = $item.Name
                                $action      = $item.StatupMode
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'File' {
                            $type        = "Policy"
                            $config      = $extension.$category
                            $config_path = "Windows Settings/Security Settings/File System"
                            
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting     = $item.Path
                                $action      = $item.Mode
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'Registry' {
                            $type        = "Policy"
                            $config      = $extension.$category
                            $config_path = "Windows Settings/Security Settings/Registry"
                            
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting     = $item.Path
                                $action      = $item.Mode
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'WindowsFirewallSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        {$_ -match 'Profile'} {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = 'Windows Settings/Security Settings/Windows Defender Firewall with Advanced Security/Windows Defender Firewall with Advanced Security'
                            $setting     = "$category EnableFirewall"
                            $action      = $config.EnableFirewall.Value
                            $element = [PsCustomObject]@{
                                'GPO'     = $identity
                                'Target'  = $target
                                'Type'    = $type
                                'Class'   = $class
                                'Setting' = $setting
                                'Action'  = $action
                                'Path'    = $config_path
                            }

                            $result.Add($element)
                        }

                        {$_ -match 'Rules'} {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = "Windows Settings/Security Settings/Windows Defender Firewall with Advanced Security/$category"

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting     = $item.Name
                                $action      = $item.Action
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'PublicKeySettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'EFSSettings' {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = 'Windows Settings/Security Settings/Public Key Policies/Encrypting File System'
                            
                            $setting = 'Allow EFS'
                            $action  = $config.AllowEFS
                            $element = [PsCustomObject]@{
                                'GPO'     = $identity
                                'Target'  = $target
                                'Type'    = $type
                                'Class'   = $class
                                'Setting' = $setting
                                'Action'  = $action
                                'Path'    = $config_path
                            }

                            $result.Add($element)
                        }

                        'RootCertificateSettings' {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = 'Windows Settings/Security Settings/Public Key Policies'
                            $members     = ($config | Get-Member -MemberType Property).Name
                            
                            foreach ($member in $members) {
                                $setting = $member
                                $action  = $config.$member
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'RootCertificate' {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = 'Windows Settings/Security Settings/Public Key Policies/Trusted Root Certification Authorities'
                            
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting = $item.IssuedTo
                                $action  = $item.IssuedBy
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'IntermediateCACertificate' {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = 'Windows Settings/Security Settings/Public Key Policies/Intermediate Certification Authorities'
                            
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting = $item.IssuedTo
                                $action  = $item.IssuedBy
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }

                        'TrustedPublishersCertificate' {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = 'Windows Settings/Security Settings/Public Key Policies/Trusted Publishers'
                            
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting = $item.IssuedTo
                                $action  = $item.IssuedBy
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'SoftwareRestrictionSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'General' {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = 'Windows Settings/Security Settings/Software Restriction Policies/Security Levels'
                            
                            $setting = 'Restriction Level'
                            $action  = $config.DefaultSecurityLevel
                            $element = [PsCustomObject]@{
                                'GPO'     = $identity
                                'Target'  = $target
                                'Type'    = $type
                                'Class'   = $class
                                'Setting' = $setting
                                'Action'  = $action
                                'Path'    = $config_path
                            }

                            $result.Add($element)
                        }

                        'PathRule' {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = 'Windows Settings/Security Settings/Software Restriction Policies/Additional Rules'
                            
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting = $item.Path
                                $action  = $item.SecurityLevel
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'Policy' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    $type        = 'Policy'
                    $config      = $extension.$category
                    
                    foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                        if ($item.FilePublisherRule) {
                            $config_path = "Windows Settings/Security Settings/Application Control Policies/AppLocker/$($item.Type)"
                            foreach ($rule in $item.FilePublisherRule) {
                                $setting = $rule.Name
                                $action  = $rule.Action
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }    
                        }
                    }
                }
            }

            'AuditSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'AuditSetting' {
                            $type        = 'Policy'
                            $config      = $extension.$category
                            $config_path = 'Windows Settings/Security Settings/Advanced Audit Policy Configuration/Audit Policies'
                            
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                $setting = $item.SubcategoryName
                                $action  = $item.SettingValue
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'FolderRedirectionSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'Folder' {
                            $type        = 'Policy'
                            $config      = $extension.$category

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.DoNotCare) { continue }
                                $folder = switch ($item.Id) {
                                    '{3EB685DB-65F9-4CF6-A03A-E3EF65729F3D}' { 'AppData(Roaming)' }
                                    '{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}' { 'Desktop' }
                                    '{625B53C3-AB48-4EC1-BA1F-A1EF4146FC19}' { 'Start Menu' }
                                    '{FDD39AD0-238F-46AF-ADB4-6C85480369C7}' { 'Documents' }
                                    '{33E28130-4E1E-4676-835A-98395C3BC3BB}' { 'Pictures' }
                                    '{4BD8D571-6D19-48D3-BE97-422220080E43}' { 'Music' }
                                    '{18989B1D-99B5-455B-841C-AB7C74E4DDFC}' { 'Videos' }
                                    '{1777F761-68AD-4D8A-87BD-30B759FA33DD}' { 'Favorites' }
                                    '{56784854-C6CB-462B-8169-88E350ACB882}' { 'Contacts' }
                                    '{374DE290-123F-4565-9164-39C4925E467B}' { 'Downloads' }
                                    '{BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968}' { 'Links' }
                                    '{7D1D3A04-DEBB-4115-95CF-2F29DA2920DA}' { 'Searches' }
                                    '{4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4}' { 'Saved Games' }
                                }

                                $config_path = "Windows Settings/Folder Redirection/$folder"
                                $setting = $folder
                                $action  = $item.Location.DestinationPath
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'RegistrySettings' {
                $choice = $extension.$(($extension | Get-Member -MemberType Property | Where-Object {$_.Name -like "q*"}).Name)

                if ($choice -notmatch "Windows") {
                    foreach ($category in $categories) {
                        if (-Not($extension.$category)) { continue }
                        switch ($category) {
                            'Policy' {
                                $type        = 'Policy'
                                $config      = $extension.$category

                                foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                    $config_path = "Administrative Templates/$($item.Category)"
                                    $setting     = $item.Name
                                    $action      = $item.State
                                    $element = [PsCustomObject]@{
                                        'GPO'     = $identity
                                        'Target'  = $target
                                        'Type'    = $type
                                        'Class'   = $class
                                        'Setting' = $setting
                                        'Action'  = $action
                                        'Path'    = $config_path
                                    }

                                    $result.Add($element)
                                }   
                            }
                        }
                    }
                } else {
                    foreach ($category in $categories) {
                        if (-Not($extension.$category)) { continue }
                        switch ($category) {
                            'RegistrySettings' {
                                $type        = 'Preference'
                                $config_path = 'Windows Settings/Registry'
                                $config = $extension.$category.ChildNodes.Properties

                                if ($extension.$category.Collection) {
                                    $config += $extension.$category.ChildNodes.Registry.Properties
                                }

                                foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                    $setting = "$($item.hive)\$($item.key)"
                                    if ($item.name) {
                                        $setting = "$setting`:$($item.name)"
                                    }
                                    $action  = switch ($item.action) {
                                        'C' { 'Create' }
                                        'R' { 'Replace' }
                                        'U' { 'Update' }
                                        'D' { 'Delete' }
                                        Default { $item.action }
                                    }
                                    $element = [PsCustomObject]@{
                                        'GPO'     = $identity
                                        'Target'  = $target
                                        'Type'    = $type
                                        'Class'   = $class
                                        'Setting' = $setting
                                        'Action'  = $action
                                        'Path'    = $config_path
                                    }

                                    $result.Add($element)
                                }   
                            }
                        }
                    }
                }
            }

            #############################################################
            ####                     Preferences                     ####
            #############################################################

            'DriveMapSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'Drive' {
                            $type        = 'Preference'
                            $config_path = 'Windows Settings/Drive Maps'
                            $config      = $extension.$category.ChildNodes.Properties

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = "$($item.letter) = $($item.path)"
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'EnvironmentVariablesSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'EnvironmentVariables' {
                            $type        = 'Preference'
                            $config_path = 'Windows Settings/Environment'
                            $config      = $extension.$category.ChildNodes.Properties
        
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.name 
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'FilesSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'FileSettings' {
                            $type        = 'Preference'
                            $config_path = 'Windows Settings/Files'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.targetPath
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'FoldersSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'Folders' {
                            $type        = 'Preference'
                            $config_path = 'Windows Settings/Folders'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.path
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'IniFilesSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'IniFiles' {
                            $type        = 'Preference'
                            $config_path = 'Windows Settings/Ini Files'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.path
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'NetworkSharesSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'NetworkShares' {
                            $type        = 'Preference'
                            $config_path = 'Windows Settings/Network Shares'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.path
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'ShortcutSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'ShortcutSettings' {
                            $type        = 'Preference'
                            $config_path = 'Windows Settings/Shortcuts'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.shortcutPath
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'DataSourcesSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'DataSourceSettings' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Data Sources'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.driver
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'DevicesSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'DevicesSettings' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Devices'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.deviceType
                                $action  = $item.deviceAction
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'FolderOptionsSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'FolderOptions' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Folder Options'
                            $config      = $extension.$category.ChildNodes
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.Name
                                $action  = switch ($item.Properties.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.Properties.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'InternetSettings' {
                # This could get needlessly messy so instead, it'll just let you know if
                # you have this configured... Just don't use IE settings, kay?
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'InternetOptions' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Internet Settings'
                            $config      = $extension.$category.ChildNodes

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.Name
                                $action  = "Order = $($item.GPOSettingOrder)"
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'LugsSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'LocalUsersAndGroups' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Local Users and Groups'
                            $config      = $extension.$category.ChildNodes

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                else { $item = $item.Properties }
                                if ($item.userName) {
                                    $setting = "User: $($item.userName)"
                                } elseif ($item.groupName) {
                                    $setting = "Group: $($item.groupName)"
                                }

                                if ($item.newName) {
                                    $setting = "$setting -> $($item.newName)"
                                }

                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'NetworkOptionsSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'NetworkOptions' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Network Options'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.name
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'PowerOptionsSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'PowerOptions' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Power Options'
                            $config = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = switch ($item.nameGuid) {
                                    '{a1841308-3541-4fab-bc81-f71556f20b4a}' { 'Power Save' }
                                    '{381b4222-f694-41f0-9685-ff5bb260df2e}' { 'Balanced' }
                                    '{8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c}' { 'High Performance' }
                                }
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'PrintersSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'Printers' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Printers'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.path
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'RegionalOptionsSettings' {
                # these SHOULD be deprecated but who knows - it'll do the same as IE settings
                # and just let you know if this setting is set
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'RegionalOptions' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Regional Options'
                            $config      = $extension.$category.ChildNodes

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.Name
                                $action  = "Order = $($item.GPOSettingOrder)"
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'ScheduledTasksSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'ScheduledTasks' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Scheduled Tasks'
                            $config = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.name
                                $action  = switch ($item.action) {
                                    'C' { 'Create' }
                                    'R' { 'Replace' }
                                    'U' { 'Update' }
                                    'D' { 'Delete' }
                                    Default { $item.action }
                                }
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'ServiceSettings' {
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'NTServices' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Services'
                            $config      = $extension.$category.ChildNodes.Properties
                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.serviceName
                                $action  = $item.serviceAction
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }

            'StartMenuSettings' {
                # these SHOULD be deprecated but who knows - it'll do the same as IE settings
                # and just let you know if this setting is set
                foreach ($category in $categories) {
                    if (-Not($extension.$category)) { continue }
                    switch ($category) {
                        'StartMenuSettings' {
                            $type        = 'Preference'
                            $config_path = 'Control Panel Settings/Start Menu'
                            $config      = $extension.$category.ChildNodes

                            foreach ($item in ($config | Where-Object {-not [string]::IsNullOrWhiteSpace($_)})) {
                                if ($item.disabled -eq 1) { continue }
                                $setting = $item.Name
                                $action  = "Order = $($item.GPOSettingOrder)"
                                $element = [PsCustomObject]@{
                                    'GPO'     = $identity
                                    'Target'  = $target
                                    'Type'    = $type
                                    'Class'   = $class
                                    'Setting' = $setting
                                    'Action'  = $action
                                    'Path'    = $config_path
                                }

                                $result.Add($element)
                            }
                        }
                    }
                }
            }
        } #endswitch
    } #endfor

    return ,$result
}



#################################################
####                  Main                   ####
#################################################
[xml]$report = Get-GPOReport -All -ReportType xml
$gpos        = $report.GPOS.GPO
$gpo_results = [System.Collections.Generic.List[object]]::new()

foreach ($gpo in $gpos) {
    # check for computer configurations
    if ($gpo.Computer.ExtensionData) {
        $info = Get-GPOBreakdown -Identity $gpo.Name -Target 'Computer' -Extensions $gpo.Computer.ExtensionData.Extension
        $gpo_results.Add($info)
    }
            
    # check for user configurations
    if ($gpo.User.ExtensionData) {
        $info = Get-GPOBreakdown -Identity $gpo.Name -Target 'User' -Extensions $gpo.User.ExtensionData.Extension
        $gpo_results.Add($info)
    }

}

# Which GPOs are linked and should be reviewed?
$link_results = New-Object Collections.ArrayList
$domain_dn    = ([ADSI]'').distinguishedName.ToString()
$top_level    = Get-GPInheritance -Target $domain_dn
$OUs          = Get-ADOrganizationalUnit -Filter *

if ($top_level.GpoLinks) {
    foreach ($policy in $top_level.GpoLinks) {
        $add = [PsCustomObject]@{
            'Path'               = "$env:USERDNSDOMAIN"
            'GPO'                = $policy.DisplayName
            'LinkEnabled'        = $policy.Enabled
            'Enforced'           = $policy.Enforced
            'InheritanceEnabled' = "N/A"
        }
        $link_results.Add($add) | Out-Null
        $add = $null
    }
}

foreach ($OU in $OUs) {
    $dn       = $OU.DistinguishedName
    $policies = Get-GPInheritance -Target $dn
    $array    = @($dn.Replace(",$domain_dn","") -Split ",")
    [array]::Reverse($array)
    $path_name = "$($env:USERDNSDOMAIN)/$($array -Replace "\w+=" -Join "/")"

    if ($policies.GpoLinks) {
        if ($policies.GpoInheritanceBlocked) {
            $inheritance = $false
        } else {
            $inheritance = $true
        }

        foreach ($policy in $policies.GpoLinks) {
            $add = [PsCustomObject]@{
                'Path'               = $path_name
                'GPO'                = $policy.DisplayName
                'LinkedEnabled'      = $policy.Enabled
                'Enforced'           = $policy.Enforced
                'InheritanceEnabled' = $inheritance
            }
            $link_results.Add($add) | Out-Null
            $add = $null
        }
    } else {
        continue
    }
}

$linked_gpos = $link_results.GPO | Select-Object -Unique
$filter      = $gpo_results | %{$_} | ?{$_.GPO -in $linked_gpos}
$grouped     = $filter | %{$_} | Group-Object -Property Setting,Path
$duplicates  = $grouped.Where{$_.Count -gt 1} | Sort-Object -Property Count -Descending
$differences = [System.Collections.Arraylist]::new()
$counter     = 1

foreach ($duplicate in $duplicates) {
    $check = $duplicate.Group.Action | Select-Object -Unique
    if ($check.Count -gt 1) {
        $opposition = $duplicate.Group | Group-Object -Property Action
        $record     = [PsCustomObject]@{
            'Record #'        = $counter
            'Setting'         = $duplicate.Name
            'Conflict Record' = ($opposition | Select-Object -Property 'Count',@{n='Value';e={$_.Name}},@{n='Policies';e={($_.Group.GPO)}})
        }
        $differences.Add($record) | Out-Null
        $counter++
    }
}
