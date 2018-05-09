# Define objects and variables
$site = "https://support.hp.com/us-en/checkwarranty/multipleproducts"
$site_results = "https://support.hp.com/us-en/checkwarranty/multipleproducts/results"
$raw = Import-CSV "[path to some csv]"
$browser = New-Object -ComObject InternetExplorer.Application
$excel = New-Object -ComObject Excel.Application
$a = 1
$b = 2
$temp = @{}

# Create an Excel worksheet
$excel.visible = $true
$workbook = $excel.Workbooks.Add()
$worksheet = $workbook.Worksheets.Item(1)
$header1 = $worksheet.Cells.Item(1,1) = "Computer:"
$header2 = $worksheet.Cells.Item(1,2) = "Serial Number:"
$header3 = $worksheet.Cells.Item(1,3) = "Model:"
$header4 = $worksheet.Cells.Item(1,4) = "Date Purchased:"
$header5 = $worksheet.Cells.Item(1,5) = "Expiration Date:"
$intRow = 2

Do{
    $browser.Navigate2($site)
    $browser.Visible = $true

    Do{Sleep -Seconds 2}While($browser.ReadyState -ne 4)
    Do{
        Try{
            $page = $browser.Document
            $status = $page.GetElementbyID("g-recaptcha-response")
        }
        Catch{ Sleep -Milliseconds 500 }
    }Until($status.value -ne $null)

    If($browser.ReadyState -eq 4){
        $page = $browser.Document
        $inputs = $page.GetElementsbyTagName("input")
        $i = 1
        ForEach($item in $inputs){
            If($item.id -eq "btnWFormSubmit"){ $button = $item }
            If($item.id -eq "wFormSerialNumber$i"){
                $temp.Add($i,$raw.Serial[$a])
                $worksheet.Cells.Item($intRow,1) = $raw.Name[$a]
                $worksheet.Cells.Item($intRow,2) = $raw.Serial[$a]
                $worksheet.Cells.Item($intRow,3) = $raw.Model[$a]
                $item.Value = $raw.Serial[$a]
                $a++,$i++,$intRow++ | Out-Null
            }
        }
        If($button.disabled -eq $true){
            $button.disabled = $false
            $button.click()
        }
        Else{ $button.click() }
    }
    Do{
        $page = $browser.Document
        $page_div = $page.GetElementsbyTagName("div")
        If($clicked -ne $true){
            ForEach($div in $page_div){
                If($div.id -like "wFormProductNumDiv*"){
                    ForEach($style in $div.style){
                        If($style.cssText -eq $null){ 
                            [int]$error_row = ($div.id) -replace '\D+'
                            $computer_info = $raw | Where {$_.Serial -eq $temp[$error_row]}
                            [string]$SKU = $computer_info.Product
                            ForEach($child in $div.childNodes){
                                If($child.tagname -eq "input"){
                                    $child.value = $SKU
                                    $error_corrected = $true
                                }
                            }
                        }
                    }
                }
            }
        }
        If($error_corrected -eq $true){
            Do{
                Try{
                    $page = $browser.Document
                    $status = $page.GetElementbyID("g-recaptcha-response")
                }
                Catch{ Sleep -Milliseconds 500 }
            }Until($status.value -ne $null)
            $page = $browser.Document
            $inputs = $page.GetElementsbyTagName("input")
            ForEach($item in $inputs){
                If($item.id -eq "btnWFormSubmit"){ $button = $item }
            }
            $error_corrected = $false
            If($button.disabled -eq $true){
                $button.disabled = $false
                $clicked = $true
                $button.click()
            }
            Else{ $clicked = $true, $button.click()}
        }
        Sleep -Seconds 2
    }Until($browser.LocationURL -eq $site_results)
    Do{Sleep -Seconds 2}While($browser.ReadyState -ne 4)
    $page = $browser.Document
    $content = $page.GetElementsByTagName("div")
        ForEach($div in $content){
            If($div.classname -eq "warrantyResultsTable hidden-sm"){
                $worksheet.Cells.Item($b,4) = $div.GetElementsbyTagName("td")[8].innerText
                $worksheet.Cells.Item($b,5) = $div.GetElementsbyTagName("td")[11].innerText
                $b++
            }
        }
    $temp = @{}
    $clicked = $null
    Sleep -Seconds 1
}Until($a -gt $raw.count)
