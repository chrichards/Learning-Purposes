gwmi win32_logicaldisk | ?{$_.deviceID -eq 'C:'} | %{if($_.FreeSpace -lt '10737418240'){return $true}else{return $false}}
