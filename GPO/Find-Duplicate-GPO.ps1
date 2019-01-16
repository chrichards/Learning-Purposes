
# ======================================================================================
#                               Extension Name: Scripts
# ======================================================================================
Function Check_Scripts {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $scriptStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $scripts = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }            

        $command = $layer2.Command
        $type = $layer2.Type
        
        $scripts | Add-Member -MemberType NoteProperty -Name "Name" -Value $command
        $scripts | Add-Member -MemberType NoteProperty -Name "Option" -Value $type
        $scriptStorage += $scripts
    }
    $global:GPOtype | Add-Member -MemberType NoteProperty -Name "Scripts" -Value $scriptStorage
}
    
# ======================================================================================
#                             Extension Name: Public Key
# ======================================================================================
Function Check_PublicKey {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $publickeyStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $publickey = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }
        
        If($extensionLocalName -eq "EFSSettings"){
            $efs = New-Object -TypeName PSObject
            $allowEFS = $layer2.AllowEFS

            $efs | Add-Member -MemberType NoteProperty -Name "Name" -Value "Allow Encrypting File System"
            $efs | Add-Member -MemberType NoteProperty -Name "State" -Value $allowEFS
            $publickey | Add-Member -MemberType NoteProperty -Name "EFSSettings" -Value $efs
        }
        If($extensionLocalName -eq "RootCertificateSettings"){
            $rootcertificates = New-Object -TypeName PSObject
            $newCAs = $layer2.AllowNewCAs
            $Trust3rdParty = $layer2.TrustThirdPartyCAs
            $RequireUPN = $layer2.RequireUPNNamingConstraints

            $rootcertificates | Add-Member -MemberType NoteProperty -Name "Name" -Value "Allow new Certificate Authorities"
            $rootcertificates | Add-Member -MemberType NoteProperty -Name "State" -Value $newCAs
            $rootcertificates | Add-Member -MemberType NoteProperty -Name "Name" -Value 
            $rootcertificates | Add-Member -MemberType NoteProperty -Name "Name" -Value 
            
            $rootcertificates | Add-Member -MemberType NoteProperty -Name "Allow 3rd party Certificate Authorities" -Value $Trust3rdParty
            $rootcertificates | Add-Member -MemberType NoteProperty -Name "Require UPN naming constraints" -Value $RequireUPN
            $publickey | Add-Member -MemberType NoteProperty -Name "RootCertificateSettings" -Value $rootcertificates
        }
        If($extensionLocalName -eq "TrustedPublishersCertificate"){
            $trustedpublishers = New-Object -TypeName PSObject
            $issuedTo = $layer2.IssuedTo
            $issuedBy = $layer2.IssuedBy
            $expires = $layer2.ExpirationDate

            $trustedpublishers | Add-Member -MemberType NoteProperty -Name "Issued to" -Value $issuedTo
            $trustedpublishers | Add-Member -MemberType NoteProperty -Name "Issued by" -Value $issuedBy
            $trustedpublishers | Add-Member -MemberType NoteProperty -Name "Expires on" -Value $expires
            $trustedpublishers | Add-Member -MemberType NoteProperty -Name "TrustedPublishersCertificate" -Value $trustedpublishers
            $publickey | Add-Member -MemberType NoteProperty -Name "TrustedPublisherCertificates" -Value $trustedpublishers
        }
        $publickeyStorage += $publickey
    }
    $global:GPOtype | Add-Member -MemberType NoteProperty -Name "Public_Key" -Value $publickeyStorage
}

# ======================================================================================
#                              Extension Name: Registry
# ======================================================================================
Function Check_Registry {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $policyStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $tempStorage = @()
        $checkboxStorage = $null;$dropDownStorage = $null;$listboxStorage = $null;$editTextStorage = $null
        $settings = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }

        If($extensionLocalName -eq "Policy"){
            $name = $layer2.Name
            $state = $layer2.State
            $category = $layer2.Category

            # Check for the existence of a checkbox element in the policy
            If($layer2.CheckBox -ne $null){
                $checkboxStorage = @()
                $checkbox = New-Object -TypeName PSObject
                $checkboxCount = $layer2.CheckBox.Count

                If($first -eq $null){
                    $checkbox | Add-Member -MemberType NoteProperty -Name "Name" -Value $name
                    $checkbox | Add-Member -MemberType NoteProperty -Name "State" -Value $state
                    $checkbox | Add-Member -MemberType NoteProperty -Name "Category" -Value $category
                    $first = $true
                }

                If(!$checkboxCount){
                    $checkboxName = $layer2.CheckBox.Name
                    $checkboxState = $layer2.CheckBox.State

                    $checkbox | Add-Member -MemberType NoteProperty -Name "Option" -Value $checkboxName
                    $checkbox | Add-Member -MemberType NoteProperty -Name "Choice" -Value $checkboxState
                    $checkboxStorage += $checkbox
                }
                Else{
                    For($b=0;$b -lt $checkboxCount;$b++){
                        If($b -gt 0){$checkbox = New-Object -TypeName PSObject}
                        $checkboxName = $layer2.CheckBox.Name[$b]
                        $checkboxState = $layer2.CheckBox.State[$b]

                        $checkbox | Add-Member -MemberType NoteProperty -Name "Option" -Value $checkboxName
                        $checkbox | Add-Member -MemberType NoteProperty -Name "Choice" -Value $checkboxState
                        $checkboxStorage += $checkbox
                    }
                }
            }

            # Check for the existence of a dropdownlist element in the policy
            If($layer2.DropDownList -ne $null){
                $dropDownStorage = @()
                $dropDown = New-Object -TypeName PSObject
                $dropDownCount = $layer2.DropDownList.Count

                If($first -eq $null){
                    $dropDown | Add-Member -MemberType NoteProperty -Name "Name" -Value $name
                    $dropDown | Add-Member -MemberType NoteProperty -Name "State" -Value $state
                    $dropDown | Add-Member -MemberType NoteProperty -Name "Category" -Value $category
                    $first = $true
                }

                If(!$dropDownCount){
                    $dropDownName = $layer2.DropDownList.Name
                    $dropDownState = $layer2.DropDownList.State
                    $dropDownConfiguration = $layer2.DropDownList.Value.Name

                    If($dropDownState -eq "Enabled"){
                        $dropDown | Add-Member -MemberType NoteProperty -Name "Option" -Value $dropDownName
                        $dropDown | Add-Member -MemberType NoteProperty -Name "Choice" -Value $dropDownConfiguration
                        $dropDownStorage += $dropDown
                    }
                }
                Else{
                    For($b=0;$b -lt $dropDownCount;$b++){
                        If($b -gt 0){$dropDown = New-Object -TypeName PSObject}
                        $dropDownName = $layer2.DropDownList.Name[$b]
                        $dropDownState = $layer2.DropDownList.State[$b]
                        $dropDownConfiguration = $layer2.DropDownList.Value.Name[$b]

                        If($dropDownState -eq "Enabled"){
                            $dropDown | Add-Member -MemberType NoteProperty -Name "Option" -Value $dropDownName
                            $dropDown | Add-Member -MemberType NoteProperty -Name "Choice" -Value $dropDownConfiguration
                            $dropDownStorage += $dropDown
                        }
                    }
                }
            }

            # Check for the existence of a listbox element in the policy
            If($layer2.ListBox -ne $null){
                $listboxStorage = @()
                $listbox = New-Object -TypeName PSObject
                $listboxCount = $layer2.ListBox.Count

                If($first -eq $null){
                    $listbox | Add-Member -MemberType NoteProperty -Name "Name" -Value $name
                    $listbox | Add-Member -MemberType NoteProperty -Name "State" -Value $state
                    $listbox | Add-Member -MemberType NoteProperty -Name "Category" -Value $category
                    $first = $true
                }

                If(!$listboxCount){
                    $listboxName = $layer2.ListBox.Name
                    $listboxState = $layer2.ListBox.State
                    $listboxElementCount = $layer2.ListBox.Value.Element.Count

                    If($listboxState -eq "Enabled"){
                        If(!$listboxElementCount){
                            $layer3 = $layer2.ListBox.Value.Element
                            $listboxData = $layer3.Data

                            $listbox | Add-Member -MemberType NoteProperty -Name "Option" -Value $listboxName
                            $listbox | Add-Member -MemberType NoteProperty -Name "Choice" -Value $listboxData
                            $listboxStorage += $listbox
                        }
                        Else{
                            For($c=0;$c -lt $listboxElementCount;$c++){
                                $layer3 = $layer2.ListBox.Value.Element[$c]
                                $listboxData = $layer3.Data

                                If($c -eq 0){$listboxValueList = $listboxValueList+"$listboxData, "}
                                ElseIf(($c+1) -eq $listboxElementCount){$listboxValueList = $listboxValueList+"$listboxData"}
                                Else{$listboxValueList = $listboxValueList+"$listboxData"}
                              
                            }
                            $listbox | Add-Member -MemberType NoteProperty -Name "Option" -Value $listboxName
                            $listbox | Add-Member -MemberType NoteProperty -Name "Choice" -Value $listboxValueList
                            $listboxStorage += $listbox
                        }
                    }
                }
                Else{
                    For($b=0;$b -lt $listboxCount;$b++){
                        If($b -gt 0){$listbox = New-Object -TypeName PSObject}
                        $listboxName = $layer2.ListBox[$b].Name
                        $listboxState = $layer2.ListBox[$b].State
                        $listboxElementCount = $layer2.ListBox[$b].Value.Element.Count

                        If($listboxState -eq "Enabled"){
                            If(!$listboxElementCount){
                                $layer3 = $layer2.ListBox[$b].Value.Element
                                $listboxData = $layer3.Data
                                    
                                $listbox | Add-Member -MemberType NoteProperty -Name "Option" -Value $listboxName
                                $listbox | Add-Member -MemberType NoteProperty -Name "Choice" -Value $listboxData
                                $listboxStorage += $listbox 
                            }
                            Else{
                                For($c=0;$c -lt $listboxElementCount;$c++){
                                    $layer3 = $layer2.ListBox[$b].Value.Element[$c]
                                    $listboxData = $layer3.Data

                                    If($c -eq 0){$listboxValueList = $listboxValueList+"$listboxData, "}
                                    ElseIf(($c+1) -eq $listboxElementCount){$listboxValueList = $listboxValueList+"$listboxData"}
                                    Else{$listboxValueList = $listboxValueList+"$listboxData"}
                              
                                }
                                $listbox | Add-Member -MemberType NoteProperty -Name "Option" -Value $listboxName
                                $listbox | Add-Member -MemberType NoteProperty -Name "Choice" -Value $listboxValueList
                                $listboxStorage += $listbox
                            }
                        }
                    }
                }
            }

            # Check for the existence of an editbox element in the policy
            If($layer2.EditText -ne $null){
                $editTextStorage = @()
                $editText = New-Object -TypeName PSObject
                $editName = $layer2.EditText.Name
                $editState = $layer2.EditText.State
                $editValue = $layer2.EditText.Value

                If($first -eq $null){
                    $editText | Add-Member -MemberType NoteProperty -Name "Name" -Value $name
                    $editText | Add-Member -MemberType NoteProperty -Name "State" -Value $state
                    $editText | Add-Member -MemberType NoteProperty -Name "Category" -Value $category
                    $first = $true
                }
                
                If($editState -eq "Enabled"){
                    $editText | Add-Member -MemberType NoteProperty -Name "Option" -Value $editName
                    $editText | Add-Member -MemberType NoteProperty -Name "Choice" -Value $editValue
                    $editTextStorage += $editText
                }
            }
            If($checkboxStorage){$tempStorage = ($tempStorage + $checkboxStorage)}
            If($dropDownStorage){$tempStorage = ($tempStorage + $dropDownStorage)}
            If($listboxStorage){$tempStorage = ($tempStorage + $listboxStorage)}
            If($editTextStorage){$tempStorage = ($tempStorage + $editTextStorage)}
            If($tempStorage){
                $settings | Add-Member -MemberType NoteProperty -Name "AdvPolicies" -Value $tempStorage
            }
            Else{
                $common = New-Object -TypeName PSObject
                $common | Add-Member -MemberType NoteProperty -Name "Name" -Value $name
                $common | Add-Member -MemberType NoteProperty -Name "State" -Value $state
                $common | Add-Member -MemberType NoteProperty -Name "Category" -Value $category
                $settings | Add-Member -MemberType NoteProperty -Name "Policies" -Value $common
            }
        }

        If($extensionLocalName -eq "RegistrySetting"){
            $registrySetting = New-Object -TypeName PSObject
            $keypath = $layer2.KeyPath
            $admsetting = $layer2.AdmSetting

            $registrySetting | Add-Member -MemberType NoteProperty -Name "Key Adjust" -Value $keypath
            $registrySetting | Add-Member -MemberType NoteProperty -Name "Admin Setting" -Value $admsetting
            $settings | Add-Member -MemberType NoteProperty -Name "RegistrySetting" -Value $registrySetting
        }
        $policyStorage += $settings
        $first = $null
    }
    $global:GPOtype | Add-Member -MemberType NoteProperty -Name "Settings" -Value $policyStorage
}

# ======================================================================================
#                        Extension Name: Software Restriction
# ======================================================================================
Function Check_SoftwareRestriction {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $softwareStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $softwareRestrictions = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }

        If($extensionLocalName -eq "General"){
            $general = New-Object -TypeName PSObject
            $applicableUsers = $layer2.ApplicableUsers
            $executableFilesCount = $layer2.ExecutableFiles.FileType.Count
            $defaultSecurityLevel = $layer2.DefaultSecurityLevel
            
            # Iterate through a nested list of executables
            For($b=0;$b -lt $executableFilesCount;$b++){
                $executableFile = $layer2.ExecutableFiles.FileType[$b]
                If($b -eq 0){$executableFileList = "Executable Files: "+"$executableFile, "}
                ElseIf(($b+1) -eq $executableFilesCount){$executableFileList = $executableFileList+"$executableFile"}
                Else{$executableFileList = $executableFileList+"$executableFile, "}
            }

            $general | Add-Member -MemberType NoteProperty -Name "Applicable Users" -Value $applicableUsers
            $general | Add-Member -MemberType NoteProperty -Name "File Types Allowed" -Value $executableFileList
            $general | Add-Member -MemberType NoteProperty -Name "Security Level" -Value $defaultSecurityLevel
            $softwareRestrictions | Add-Member -MemberType NoteProperty -Name "General" -Value $general
        }

        If($extensionLocalName -eq "CertificateRule"){
            $certificate = New-Object -TypeName PSObject
            $securityLevel = $layer2.SecurityLevel
            $certModificationTime = $layer2.ModificationTime
            $subjectName = $layer2.SubjectName

            $certificate | Add-Member -MemberType NoteProperty -Name "Subject Name" -Value $subjectName
            $certificate | Add-Member -MemberType NoteProperty -Name "Last Modified" -Value $certModificationTime
            $certificate | Add-Member -MemberType NoteProperty -Name "Security Level" -Value $securityLevel
            $softwareRestrictions | Add-Member -MemberType NoteProperty -Name "CertificateRule" -Value $certificate
        }
        $softwareStorage += $softwareRestrictions
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "SoftwareRestrictions" -Value $policyStorage
}

# ======================================================================================
#                             Extension Name: Security
# ======================================================================================
Function Check_Security {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $securityStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $security = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }

        If($extensionLocalName -eq "RestrictedGroups"){
            $restrictedGroup = New-Object -TypeName PSObject
            $groupName = $layer2.GroupName.Name.InnerText
            $memberOf = $layer2.Memberof.Name.InnerText
            $memberCount = $layer2.Member.Count

            If($memberOf){
                $restrictedGroup | Add-Member -MemberType NoteProperty -Name "Account" -Value $groupName
                $restrictedGroup | Add-Member -MemberType NoteProperty -Name "Member of" -Value $memberOf
            }
            For($b=0;$b -lt $memberCount;$b++){
                $member = $layer2.Member.Name[$b].InnerText

                If($b -eq 0){$memberList = $memberList+"Member(s): $member, "}
                Elseif(($b+1) -eq $memberCount){$memberList = $memberList+"$member"}
                Else{$memberList = $memberList+"$member, "}
            }
            If($memberList){
                $restrictedGroup | Add-Member -MemberType NoteProperty -Name "Group Name" -Value $groupName
                $restrictedGroup | Add-Member -MemberType NoteProperty -Name "Members" -Value $memberList
            }
            $security | Add-Member -MemberType NoteProperty -Name "RestrictedGroups" -Value $restrictedGroup
        }

        If($extensionLocalName -eq "EventLog"){
            $eventLog = New-Object -TypeName PSObject
            $logName = $layer2.Name
            $logType = $layer2.Log
            $logSettingNumber = $layer2.SettingNumber
            $logBoolean = $layer2.SettingBoolean

            If($logSettingNumber){$logSetting = $logSettingNumber}
            ElseIf($logBoolean){$logSetting = $logBoolean}

            $eventLog | Add-Member -MemberType NoteProperty -Name "Log Type" -Value $logType
            $eventLog | Add-Member -MemberType NoteProperty -Name "Property" -Value $logName
            $eventLog | Add-Member -MemberType NoteProperty -Name "Setting" -Value $logSetting
            $security | Add-Member -MemberType NoteProperty -Name "EventLog" -Value $eventLog
        }
        
        If($extensionLocalName -eq "Account"){
            $account = New-Object -TypeName PSObject
            $accountName = $layer2.Name
            $accountSetting = $layer2.SettingNumber

            $account | Add-Member -MemberType NoteProperty -Name "Name" -Value $accountName
            $account | Add-Member -MemberType NoteProperty -Name "Setting" -Value $accountSetting
            $security | Add-Member -MemberType NoteProperty -Name "Account" -Value $account
        }

        If($extensionLocalName -eq "Audit"){
            $audit = New-Object -TypeName PSObject
            $auditName = $layer2.Name
            $successAttempts = $layer2.SuccessAttempts
            $failureAttempts = $layer2.FailureAttempts
            
            $audit | Add-Member -MemberType NoteProperty -Name "Name" -Value $auditName
            If(($successAttempts -eq "true") -and ($failureAttempts -eq "false")){
                $audit | Add-Member -MemberType NoteProperty -Name "Setting" -Value "Success Only"
            }
            ElseIf(($successAttempts -eq "false") -and ($failureAttempts -eq "true")){
                $audit | Add-Member -MemberType NoteProperty -Name "Setting" -Value "Failure Only"
            }
            ElseIf(($successAttempts -eq "true") -and ($failureAttempts -eq "true")){
                $audit | Add-Member -MemberType NoteProperty -Name "Setting" -Value "Success AND Failure"
            }
            Else{$audit | Add-Member -MemberType NoteProperty -Name "Setting" -Value "Undefined"}
            $security | Add-Member -MemberType NoteProperty -Name "Audit" -Value $audit
        }
        
        If($extensionLocalName -eq "SecurityOptions"){
            $securityOptions = New-Object -TypeName PSObject
            $settingDisplayName = $layer2.Display.Name
            $settingPolicyName = $layer2.SystemAccessPolicyName
            $settingBoolean = $layer2.Display.DisplayBoolean
            $settingUnits = $layer2.Display.Units
            $settingNumber = $layer2.Display.DisplayNumber
            $settingString = $layer2.Display.DisplayString

            If($settingDisplayName){$settingName = $settingDisplayName}
            ElseIf($settingPolicyName){$settingName = $settingPolicyName}

            If($settingBoolean){$settingValue = $settingBoolean}
            ElseIf(($settingUnits) -and ($settingNumber)){$settingValue = "$settingNumber ($settingUnits)"}
            ElseIf($settingString){$settingValue = $settingString}
            
            $securityOptions | Add-Member -MemberType NoteProperty -Name "Name" -Value $settingName
            $securityOptions | Add-Member -MemberType NoteProperty -Name "Status" -Value $settingValue
            $security | Add-Member -MemberType NoteProperty -Name "SecurityOptions" -Value $securityOptions
        }  
        $securityStorage += $security
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "Security" -Value $securityStorage
}

# ======================================================================================
#                           Extension Name: Folder Redirection
# ======================================================================================
Function Check_FolderRedirection {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $folderRedirectionStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $folderRedirection = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }

        If($extensionLocalName -eq "Folder"){
            $folder = New-Object -TypeName PSObject
            $FRName = $layer2.Location.DestinationPath
            $FRFollow = $layer2.FollowParent

            If($y -eq 1){$FRNameArray = @()}
            If($FRFollow -eq "true"){$FRNameArray += $FRName}
            Else{
                $FRSecurityGroupCount = $layer2.Location.SecurityGroup.Count
                $FRExclusiveRights = $layer2.GrantExclusiveRights
                $FRMoveContents = $layer2.MoveContents
                $FRApplyToDownLevel = $layer2.ApplyToDownLevel
                $FRRedirectToLocal = $layer2.RedirectToLocal
                $FRPolicyRemove = $layer2.PolicyRemovalBehavior

                If(!$FRSecurityGroupCount){$FRSecurityGroup = $layer2.Location.SecurityGroup.Name.InnerText}
                Else{
                    For($b=0;$b -lt $FRSecurityGroupCount;$b++){
                        If($b -eq 0){$FRSecurityGroup = $FRSecurityGroup+"$($layer2.Location.SecurityGroup[$b].Name.InnerText), "}
                        ElseIf(($b+1) -eq $FRSecurityGroupCount){$FRSecurityGroup = $FRSecurityGroup+$($layer2.Location.SecurityGroup[$b].Name.InnerText)}
                        Else{$FRSecurityGroup = $FRSecurityGroup+"$($layer2.Location.SecurityGroup[$b].Name.InnerText), "}
                    }
                }
                   
                $Split = $FRName.Split("\")
                $ParentName = ($Split | Select -Last 1)
                $FRNameArray += $ParentName
                $FRDestination = ($FRName -Replace "$ParentName","")
            }

            If(!$layer1Count -or ($y -eq $null)){
                If($FRNameArray){
                    For($b=0;$b -lt $FRNameArray.Count;$b++){
                        If($b -eq 0){$FRNameOutput = $FRNameOutput+"$($FRNameArray[$b]), "}
                        ElseIf(($b+1) -eq $FRNameArray.Count){$FRNameOutput = $FRNameOutput+$FRNameArray[$b]}
                        Else{$FRNameOutput = $FRNameOutput+"$($FRNameArray[$b]), "}
                    }
                }
                Else{$FRNameOutput = $FRName}

                $folderRedirection | Add-Member -MemberType NoteProperty -Name "Folders" -Value $FRNameOutput
                $folderRedirection | Add-Member -MemberType NoteProperty -Name "Location" -Value $FRDestination
                $folderRedirection | Add-Member -MemberType NoteProperty -Name "Group(s)" -Value $FRSecurityGroup
                $folderRedirection | Add-Member -MemberType NoteProperty -Name "Move files to new location?" -Value $FRMoveContents
                $folderRedirection | Add-Member -MemberType NoteProperty -Name "User has exclusive rights?" -Value $FRExclusiveRights
                $folderRedirection | Add-Member -MemberType NoteProperty -Name "User rights propagate?" -Value $FRApplyToDownLevel
                $folderRedirection | Add-Member -MemberType NoteProperty -Name "Send back to local if policy removed?" -Value $FRRedirectToLocal
                $folderRedirection | Add-Member -MemberType NoteProperty -Name "Policy removal behavior" -Value $FRPolicyRemove
                $folderRedirectionStorage += $folderRedirection
            }
        }
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "FolderRedirection" -Value $folderRedirectionStorage
}

# ======================================================================================
#                                Extension Name: Files
# ======================================================================================
Function Check_Files {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $filesStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $files = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }

        If($extensionLocalName -eq "FilesSettings"){
            $fileSettingsStorage = @()
            $fileCount = $layer2.File.Count

            If(!$fileCount){
                $fileSettings = New-Object -TypeName PSObject
                $layer3 = $layer2.File.Properties
                $fileAction = $layer3.action
                $fileName = $layer3.targetPath

                $fileSettings | Add-Member -MemberType NoteProperty -Name "Target" -Value $fileName
                $fileSettings | Add-Member -MemberType NoteProperty -Name "Action" -Value $fileAction
                $fileSettingsStorage += $fileSettings
            }
            Else{
                For($b=0;$b -lt $fileCount;$b++){
                    $fileSettings = New-Object -TypeName PSObject
                    $layer3 = $layer2.File[$b].Properties
                    $fileAction = $layer3.action
                    $fileName = $layer3.targetPath

                    $fileSettings | Add-Member -MemberType NoteProperty -Name "Target" -Value $fileName
                    $fileSettings | Add-Member -MemberType NoteProperty -Name "Action" -Value $fileAction
                    $fileSettingsStorage += $fileSettings
                }
            }
            $files | Add-Member -MemberType NoteProperty -Name "FileSettings" -Value $fileSettingsStorage
        }
        $filesStorage += $files
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "Files" -Value $filesStorage
}

# ======================================================================================
#                            Extension Name: Windows Registry
# ======================================================================================
Function Check_WindowsRegistry {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $registryStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $registry = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }

        If($extensionLocalName -eq "RegistrySettings"){
            $registrySettingsStorage = @()
            $registryCount = $layer2.Registry.Count
            
            If(!$registryCount){
                $registrySettings = New-Object -TypeName PSObject
                $layer3 = $layer2.Registry.Properties
                $registryAction = $layer3.action
                $registryHive = $layer3.hive
                $registryKey = $layer3.key
                $registryPath = "$registryHive\$registryKey"
                $registryName = $layer3.name
                $registryType = $layer3.type
                $registryValue = $layer3.value

                $registrySettings | Add-Member -MemberType NoteProperty -Name "Name" -Value $registryName
                $registrySettings | Add-Member -MemberType NoteProperty -Name "Type" -Value $registryType
                $registrySettings | Add-Member -MemberType NoteProperty -Name "Action" -Value $registryAction
                $registrySettings | Add-Member -MemberType NoteProperty -Name "Value" -Value $registryValue
                $registrySettings | Add-Member -MemberType NoteProperty -Name "Path" -Value $registryPath
                $registrySettingsStorage += $registrySettings
            }
            Else{
                For($b=0;$b -lt $registryCount;$b++){
                    $registrySettings = New-Object -TypeName PSObject
                    $layer3 = $layer2.Registry[$b].Properties
                    $registryAction = $layer3.action
                    $registryHive = $layer3.hive
                    $registryKey = $layer3.key
                    $registryPath = "$registryHive\$registryKey"
                    $registryName = $layer3.name
                    $registryType = $layer3.type
                    $registryValue = $layer3.value

                    $registrySettings | Add-Member -MemberType NoteProperty -Name "Name" -Value $registryName
                    $registrySettings | Add-Member -MemberType NoteProperty -Name "Type" -Value $registryType
                    $registrySettings | Add-Member -MemberType NoteProperty -Name "Action" -Value $registryAction
                    $registrySettings | Add-Member -MemberType NoteProperty -Name "Value" -Value $registryValue
                    $registrySettings | Add-Member -MemberType NoteProperty -Name "Path" -Value $registryPath
                    $registrySettingsStorage += $registrySettings
                }
            }
            $registry | Add-Member -MemberType NoteProperty -Name "RegistrySettings" -Value $registrySettingsStorage
        }
        $registryStorage += $registry
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "WindowsRegistry" -Value $registryStorage
}

# ======================================================================================
#                               Extension Name: Printers
# ======================================================================================
Function Check_Printers {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $printerStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $printers = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }

        If($extensionLocalName -eq "Printers"){
            $sharedPrinterStorage = @()
            $printerCount = $layer2.SharedPrinter.Count

            If(!$printerCount){
                $printer = New-Object -TypeName PSObject
                $layer3 = $layer2.SharedPrinter.Properties
                $printerName = $layer2.SharedPrinter.Name
                $printerPath = $layer3.path
                $printerAction = $layer3.action
                $printerDefault = $layer3.default

                If($printerDefault -eq "1"){$printerDefault = "True"}
                Else{$printerDefault = "False"}

                $printer | Add-Member -MemberType NoteProperty -Name "Name" -Value $printerName
                $printer | Add-Member -MemberType NoteProperty -Name "Path" -Value $printerPath
                $printer | Add-Member -MemberType NoteProperty -Name "Action" -Value $printerAction
                $printer | Add-Member -MemberType NoteProperty -Name "Default" -Value $printerDefault
                $sharedPrinterStorage += $printer
            }
            Else{
                For($b=0;$b -lt $printerCount;$b++){
                    $printer = New-Object -TypeName PSObject
                    $layer3 = $layer2.SharedPrinter[$b].Properties
                    $printerName = $layer2.SharedPrinter[$b].Name
                    $printerPath = $layer3.path
                    $printerAction = $layer3.action
                    $printerDefault = $layer3.default

                    If($printerDefault -eq "1"){$printerDefault = "True"}
                    Else{$printerDefault = "False"}

                    $printer | Add-Member -MemberType NoteProperty -Name "Name" -Value $printerName
                    $printer | Add-Member -MemberType NoteProperty -Name "Path" -Value $printerPath
                    $printer | Add-Member -MemberType NoteProperty -Name "Action" -Value $printerAction
                    $printer | Add-Member -MemberType NoteProperty -Name "Default" -Value $printerDefault
                    $sharedPrinterStorage += $printer
                }
            }
            $printers | Add-Member -MemberType NoteProperty -Name "PrinterSettings" -Value $sharedPrinterStorage
        }
        $printerStorage += $printers
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "Printers" -Value $printerStorage
}            

# ======================================================================================
#                           Extension Name: Internet Options
# ======================================================================================
Function Check_InternetOptions {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $IEOptionsStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $internetOptions = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }

        If($extensionLocalName -eq "InternetOptions"){
            $iestorage = @()
            If($layer2.IE8){$layer3 = $layer2.IE8;$iecount}
            ElseIf($layer2.IE9){$layer3 = $layer2.IE9;$iecount}
            ElseIf($layer2.IE10){$layer3 = $layer2.IE10;$iecount}

            $iecount = $layer3.Properties.Reg.Count

            If(!$iecount){
                $ieo = New-Object -TypeName PSObject
                $ieID = $layer3.Properties.Reg.id
                $ieValue = $layer3.Properties.Reg.value

                $ieo | Add-Member -MemberType NoteProperty -Name "Name" -Value $ieID
                $ieo | Add-Member -MemberType NoteProperty -Name "Value" -Value $ieValue
                $iestorage += $ieo
            }
            Else{
                For($b=0;$b -lt $iecount;$b++){
                    $ieo = New-Object -TypeName PSObject
                    $layer4 = $layer3.Properties.Reg[$b]
                    $ieID = $layer4.id
                    $ieValue = $layer4.value

                    $ieo | Add-Member -MemberType NoteProperty -Name "Name" -Value $ieID
                    $ieo | Add-Member -MemberType NoteProperty -Name "Value" -Value $ieValue
                    $iestorage += $ieo
                }
            }
            $internetOptions | Add-Member -MemberType NoteProperty -Name "Properties" -Value $iestorage
        }
        $IEOptionsStorage += $internetOptions
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "InternetOptions" -Value $IEOptionsStorage
}            

# ======================================================================================
#                           Extension Name: Start Menu
# ======================================================================================
Function Check_StartMenu {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $startMenuStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $startMenuOptions = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        # Check if there are multiple settings with the same name
        $layer1Count = $layer1.Extension.$extensionLocalName.Count
        If(!$layer1Count){$layer2 = $layer1.Extension.$extensionLocalName}
        Else{
            If($y -eq $null){$y = 0}
            $layer2 = $layer1.Extension.$extensionLocalName[$y]
            If(($y+1) -eq $layer1Count){$y = $null}
            Else{$y++}
        }

        If($extensionLocalName -eq "StartMenuSettings"){
            $startMenuSettingsStorage = @()
            $layer3 = $layer2.StartMenuVista.Properties

            $startNames = @("showMyComputer","connectTo","showControlPanel","defaultPrograms",
            "showMyDocs","enableContextMenu","showFavorites","showGames","showHelp","highlightNew",
            "showMyMusic","showNetPlaces","openSubMenus","personalFolders","showMyPics","showPrinters",
            "runCommand","showSearch","searchCommunications","searchFavorites","searchFiles",
            "searchPrograms","sortAllPrograms","systemAdmin","useLargeIcons","minMFU","showRecentDocs",
            "clearStartDocsList","trackProgs")

            $startSettings = @($layer3.showMyComputer,$layer3.connectTo,$layer3.showControlPanel,
            $layer3.defaultPrograms,$layer3.showMyDocs,$layer3.enableContextMenu,$layer3.showFavorites,
            $layer3.showGames,$layer3.showHelp,$layer3.highlightNew,$layer3.showMyMusic,$layer3.showNetPlaces,
            $layer3.openSubMenus,$layer3.personalFolders,$layer3.showMyPics,$layer3.showPrinters,
            $layer3.runCommand,$layer3.showSearch,$layer3.searchCommunications,$layer3.searchFavorites,
            $layer3.searchFiles,$layer3.searchPrograms,$layer3.sortAllPrograms,$layer3.systemAdmin,
            $layer3.useLargeIcons,$layer3.minMFU,$layer3.showRecentDocs,$layer3.clearStartDocsList,$layer3.trackProgs)

            
            For($b=0;$b -lt $startNames.Count;$b++){
                $temp = New-Object -TypeName PSObject
                $temp | Add-Member -MemberType NoteProperty -Name "Name" -Value $startNames[$b]
                $temp | Add-Member -MemberType NoteProperty -Name "Setting" -Value $startSettings[$b]
                $startMenuSettingsStorage += $temp
            }
            $startMenuOptions | Add-Member -MemberType NoteProperty -Name "StartMenuOptions" -Value $startMenuSettingsStorage
        }
        $startMenuStorage += $startMenuOptions
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "StartMenu" -Value $startMenuStorage
}

# ======================================================================================
#                      Extension Name: Internet Explorer Maintenance
# ======================================================================================
# This policy is deprecated but may still appear in some older environments
Function Check_IEMaintenance {
    # How many settings are configured in the policy? 
    $extensionSettingsCount = $layer1.Extension.ChildNodes.Count

    # If extensionSettingsCount is null, there's only a single setting being configured
    $IEMaintenanceStorage = @()
    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $IEMaintenance = New-Object -TypeName PSObject
        $extensionLocalName = $layer1.Extension.ChildNodes[$a].LocalName
        $extensionLocalSetting = $layer1.Extension.$extensionLocalName
        If($extensionLocalSetting.Value){$extensionLocalSetting = $extensionLocalSetting.Value}

        $IEMaintenance | Add-Member -MemberType NoteProperty -Name "Name" -Value $extensionLocalName
        $IEMaintenance | Add-Member -MemberType NoteProperty -Name "Setting" -Value $extensionLocalSetting
        $IEMaintenanceStorage += $IEMaintenance
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "InternetExplorerMaintenance" -Value $IEMaintenanaceStorage
}

# ======================================================================================
#                         Extension Name: Folder Settings
# ======================================================================================
Function Check_FolderSettings {
# There's only one extension for Folders but multiple sub-extensions
    $extensionLocalName = $layer1.Extension.ChildNodes.LocalName
    $layer2 = $layer1.Extension.$extensionLocalName
    $extensionSettingsCount = $layer2.Count
    $FolderSettingsStorage = @()

    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $FolderSettings = New-Object -TypeName PSObject
        $FolderName = $layer2[$a].Name
        $FolderAction = $layer2[$a].Properties.Action
        $FolderPath = $layer2[$a].Properties.Path

        $FolderSettings | Add-Member -MemberType NoteProperty -Name "Name" -Value $FolderName
        $FolderSettings | Add-Member -MemberType NoteProperty -Name "Setting" -Value "$FolderAction : $FolderPath"
        $FolderSettingsStorage += $FolderSettings
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "Folders" -Value $FolderSettingsStorage
}

# ======================================================================================
#                         Extension Name: Scheduled Tasks
# ======================================================================================
# This policy is deprecated but may still appear in some older environments
Function Check_ScheduledTasks {
# There's only one extension for Scheduled Tasks but multiple sub-extensions
    $extensionLocalName = $layer1.Extension.ChildNodes.LocalName
    $layer2 = $layer1.Extension.$extensionLocalName.TaskV2
    $extensionSettingsCount = $layer2.Count
    $ScheduledTasksStorage = @()

    For($a=0;$a -lt $extensionSettingsCount;$a++){
        $ScheduledTaskSettings = New-Object -TypeName PSObject
        $ScheduledTaskName = $layer2[$a].Name
        $ScheduledTaskTrigger = $layer2[$a].Properties.Action
        $FolderPath = $layer2[$a].Properties.Path

        $FolderSettings | Add-Member -MemberType NoteProperty -Name "Name" -Value $FolderName
        $FolderSettings | Add-Member -MemberType NoteProperty -Name "Setting" -Value "$FolderAction : $FolderPath"
        $FolderSettingsStorage += $FolderSettings
    }
    $global:GPOType | Add-Member -MemberType NoteProperty -Name "Folders" -Value $FolderSettingsStorage
}

# ======================================================================================
#                                   GPO Processing
# ======================================================================================
Function Process_GPO {
    $a=$null;$b=$null;$c=$null
    If($xml.GPO.Computer.ExtensionData){
        $global:GPOtype = New-Object -TypeName PSObject
        # How many COMPUTER policies are configured?
        $configuredItemCount = $xml.GPO.Computer.ExtensionData.Count
    
        # If configuredItemCount is null, there's only a single area of configuration in the GPO
        If(!$configuredItemCount){
            # Declare the single configured item
            $layer1 = $xml.GPO.Computer.ExtensionData

            # Declare the local name for function comparison
            $settingLocalName = $layer1.Name

            If($settingLocalName -eq "Scripts"){Check_Scripts}
            ElseIf($settingLocalName -eq "Public Key"){Check_PublicKey}
            ElseIf($settingLocalName -eq "Registry"){Check_Registry}
            ElseIf($settingLocalName -eq "Software Restriction"){Check_SoftwareRestriction}
            ElseIf($settingLocalName -eq "Security"){Check_Security}
            ElseIf($settingLocalName -eq "Folder Redirection"){Check_FolderRedirection}
            ElseIf($settingLocalName -eq "Files"){Check_Files}
            ElseIf($settingLocalName -eq "Windows Registry"){Check_WindowsRegistry}
            ElseIf($settingLocalName -eq "Printers"){Check_Printers}
            ElseIf($settingLocalName -eq "Internet Options"){Check_InternetOptions}
            ElseIf($settingLocalName -eq "Start Menu"){Check_StartMenu}
            ElseIf($settingLocalName -eq "Internet Explorer Maintenance"){Check_IEMaintenance}
            ElseIf($settingLocalName -eq "Folders"){Check_FolderSettings}
            ElseIf($settingLocalName -eq "ScheduledTasks"){Check_ScheduledTasks}
            #Else{Write-Host "Function not yet defined for $settingLocalName"}
        }
        Else{
            For($i=0;$i -lt $configuredItemCount;$i++){
                # Declare the single configured item
                $layer1 = $xml.GPO.Computer.ExtensionData[$i]

                # Declare the local name for function comparison
                $settingLocalName = $layer1.Name

                If($settingLocalName -eq "Scripts"){Check_Scripts}
                ElseIf($settingLocalName -eq "Public Key"){Check_PublicKey}
                ElseIf($settingLocalName -eq "Registry"){Check_Registry}
                ElseIf($settingLocalName -eq "Software Restriction"){Check_SoftwareRestriction}
                ElseIf($settingLocalName -eq "Security"){Check_Security}
                ElseIf($settingLocalName -eq "Folder Redirection"){Check_FolderRedirection}
                ElseIf($settingLocalName -eq "Files"){Check_Files}
                ElseIf($settingLocalName -eq "Windows Registry"){Check_WindowsRegistry}
                ElseIf($settingLocalName -eq "Printers"){Check_Printers}
                ElseIf($settingLocalName -eq "Internet Options"){Check_InternetOptions}
                ElseIf($settingLocalName -eq "Start Menu"){Check_StartMenu}
                ElseIf($settingLocalName -eq "Internet Explorer Maintenance"){Check_IEMaintenance}
                ElseIf($settingLocalName -eq "Folders"){Check_FolderSettings}
                ElseIf($settingLocalName -eq "ScheduledTasks"){Check_ScheduledTasks}
                #Else{Write-Host "Function not yet defined for $settingLocalName"}
                }
        }
        $global:outputFile | Add-Member -MemberType NoteProperty -Name "Computer" -Value $global:GPOtype
    }
    If($xml.GPO.User.ExtensionData){
        $global:GPOtype = New-Object -TypeName PSObject
        # How many USER policies are configured?
        $configuredItemCount = $xml.GPO.User.ExtensionData.Count
    
        # If configuredItemCount is null, there's only a single area of configuration in the GPO
        If(!$configuredItemCount){
            # Declare the single configured item
            $layer1 = $xml.GPO.User.ExtensionData

            # Declare the local name for function comparison
            $settingLocalName = $layer1.Name

            If($settingLocalName -eq "Scripts"){Check_Scripts}
            ElseIf($settingLocalName -eq "Public Key"){Check_PublicKey}
            ElseIf($settingLocalName -eq "Registry"){Check_Registry}
            ElseIf($settingLocalName -eq "Software Restriction"){Check_SoftwareRestriction}
            ElseIf($settingLocalName -eq "Security"){Check_Security}
            ElseIf($settingLocalName -eq "Folder Redirection"){Check_FolderRedirection}
            ElseIf($settingLocalName -eq "Files"){Check_Files}
            ElseIf($settingLocalName -eq "Windows Registry"){Check_WindowsRegistry}
            ElseIf($settingLocalName -eq "Printers"){Check_Printers}
            ElseIf($settingLocalName -eq "Internet Options"){Check_InternetOptions}
            ElseIf($settingLocalName -eq "Start Menu"){Check_StartMenu}
            ElseIf($settingLocalName -eq "Internet Explorer Maintenance"){Check_IEMaintenance}
            ElseIf($settingLocalName -eq "Folders"){Check_FolderSettings}
            ElseIf($settingLocalName -eq "ScheduledTasks"){Check_ScheduledTasks}
            #Else{Write-Host "Function not yet defined for $settingLocalName"}
        }
        Else{
            For($i=0;$i -lt $configuredItemCount;$i++){
                # Declare the single configured item
                $layer1 = $xml.GPO.User.ExtensionData[$i]

                # Declare the local name for function comparison
                $settingLocalName = $layer1.Name

                If($settingLocalName -eq "Scripts"){Check_Scripts}
                ElseIf($settingLocalName -eq "Public Key"){Check_PublicKey}
                ElseIf($settingLocalName -eq "Registry"){Check_Registry}
                ElseIf($settingLocalName -eq "Software Restriction"){Check_SoftwareRestriction}
                ElseIf($settingLocalName -eq "Security"){Check_Security}
                ElseIf($settingLocalName -eq "Folder Redirection"){Check_FolderRedirection}
                ElseIf($settingLocalName -eq "Files"){Check_Files}
                ElseIf($settingLocalName -eq "Windows Registry"){Check_WindowsRegistry}
                ElseIf($settingLocalName -eq "Printers"){Check_Printers}
                ElseIf($settingLocalName -eq "Internet Options"){Check_InternetOptions}
                ElseIf($settingLocalName -eq "Start Menu"){Check_StartMenu}
                ElseIf($settingLocalName -eq "Internet Explorer Maintenance"){Check_IEMaintenance}
                ElseIf($settingLocalName -eq "Folders"){Check_FolderSettings}
                ElseIf($settingLocalName -eq "ScheduledTasks"){Check_ScheduledTasks}
                #Else{Write-Host "Function not yet defined for $settingLocalName"}
            }
        }
        $global:outputFile | Add-Member -MemberType NoteProperty -Name "User" -Value $global:GPOtype
    }
}

# ======================================================================================
#                                   Script Start
# ======================================================================================
<#
Clear-Host
Write-Host "Checking for a working directory..."
$workDirectory = "$env:USERPROFILE\Desktop\GPO"
If(-Not(Test-Path $workDirectory)){
    Write-Host "Making a work directory on your desktop..."
    New-Item -Path "$env:USERPROFILE\Desktop" -Name "GPO" -ItemType Directory -Force
}
If(-Not(Test-Path "$workDirectory/In-Use")){New-Item -Path $workDirectory -Name "In-Use" -ItemType Directory -Force}
If(-Not(Test-Path "$workDirectory/Idle")){New-Item -Path $workDirectory -Name "Idle" -ItemType Directory -Force}

Write-Host "Please wait while the GPO report is generated..."

# Get the name of all GPOs in your environment
$GPO_Names = Get-GPO -All | Select DisplayName | Sort DisplayName
$Total = $GPO_Names.Count
$z = 1

ForEach($Name in $GPO_Names){
    $global:outputFile = New-Object -TypeName PSObject
    Write-Progress -Activity "Gathering GPO Info" -Status "$z of $Total Complete" -PercentComplete (100*($z/$Total))

    # Get individual XML reports based on the names collected earlier
    [xml]$xml = Get-GPOReport -Name $Name.DisplayName -ReportType XML
    Process_GPO
    If($xml.GPO.LinksTo -ne $null){
        $filename = $Name.DisplayName -Replace "\\",'-' -Replace "/",'-'
        #$outputFile | Export-Clixml -Depth 10 "$workDirectory\In-Use\$filename.xml"
    }
    Else{
        $filename = $Name.DisplayName -Replace "\\",'-' -Replace "/",'-'
        #$outputFile | Export-Clixml -Depth 10 "$workDirectory\In-Use\$filename.xml"
    }
    $z++
}
#>

# Test block
Clear-Host
$z = 1
$files = Get-ChildItem -Path "C:\users\chrisr\desktop\function" -File
$Total = $files.Count

ForEach($Name in $files){
    $global:outputFile = New-Object -TypeName PSObject
    $filename = $Name.Name
    Write-Progress -Activity "Gathering GPO Info" -Status "$z of $Total Complete" -PercentComplete (100*($z/$Total))

    # Get individual XML reports based on the names collected earlier
    [xml]$xml = Get-Content $Name.Fullname
    Process_GPO
    If($xml.GPO.LinksTo -ne $null){
        $outputFile | Export-Clixml -Depth 10 "$env:USERPROFILE\Desktop\Landing\$filename"
    }
    Else{
        $outputFile | Export-Clixml -Depth 10 "$env:USERPROFILE\Desktop\Landing\$filename"
    }
    $z++
}
