function Get-Netstat ([switch]$all, [switch]$lookup, [switch]$statistics, [switch]$interfaceStatistics) {
    $doubleValueSets = @("ICMPv4 Statistics","ICMPv6 Statistics")

    if($statistics) {
        $netstatStatistics = netstat -s

        $netstatStatistics = $netstatStatistics | Where-Object { $_ }
        $netstatStatistics = $netstatStatistics | Where-Object {$_ -notmatch "^\s+[a-z]+\s+[a-z]+$"}
        
        $netstatStatistics = foreach ($line in $netstatStatistics) {
            if($line -match "^[a-z]+") {
                "@"
                "$line"
            } else {
                $line
            }
        }
        $netstatStatistics = $netstatStatistics | Select-Object -Skip 1
        
        foreach ($line in $netstatStatistics) {
            if($line -match "^[a-z]+") {
                $name = $line
            }
            if($line -match "[0-9]+\s+[0-9]+\s+$") {
                #The -s parameter prefix all values with empty space, trim dat bush...
                if($line -match "^\s+[a-z]+\s+[a-z]$") {
                    #Supress this line it... (Received/Sent header for multivalue output in netstat -s)... Mess with my algorithm
                } else {
                    $line = $line.Trim()
                    $line = $line -replace "\s\s+", ";"
                    $lineObject = $line | ConvertFrom-Csv -Delimiter ";" -Header @("Key","Received","Sent")
                    $hash = [ordered]@{
                        Category = $name
                        Key = $lineObject.Key
                        Value = $null
                        Received = $lineObject.Received
                        Sent = $lineObject.Sent
                    }
                    New-Object -TypeName PSObject -Property $hash
                }
            } elseif($line -match "\s+=\s+") {
                #The -s parameter prefix all values with empty space, trim dat bush...
                $line = $line.Trim()
                $line = $line -replace "\s\s+=\s", "="
                $lineObject = $line | ConvertFrom-Csv -Delimiter "=" -Header @("Key","Value")
                $hash = [ordered]@{
                    Category = $name
                    Key = $lineObject.Key
                    Value = $lineObject.Value
                    Received = $null
                    Sent = $null
                }
                New-Object -TypeName PSObject -Property $hash
            }
        }
    } elseif($interfaceStatistics) {
        $netstatStatistics = netstat -e

        $netstatStatistics = $netstatStatistics | Where-Object { $_ }
        $netstatStatistics = $netstatStatistics | Where-Object {$_ -notmatch "^\s+[a-z]+\s+[a-z]+$"}

        $array = @()
        foreach ($line in $netstatStatistics) {
            if($line -match "^[a-z]+\s[a-z]+$") {
                $name = $line
            }
            if($line -match "[0-9]+\s+[0-9]+$") {
                $line = $line -replace "\s\s+", ";"
                $lineObject = $line | ConvertFrom-Csv -Delimiter ";" -Header @("Key","Received","Sent")
                $hash = [ordered]@{
                    Category = $name
                    Key = $lineObject.Key
                    Received = $lineObject.Received
                    Sent = $lineObject.Sent
                }
                New-Object -TypeName PSObject -Property $hash
            }
        }

        foreach ($line in $array) {
            if($line -match "^[a-z]") {
                $name = $line
            } elseif($line -match ";") {
                $temp = $line -split ";"
                $hash = [ordered]@{
                    Category = $name
                    Key = $temp[0].Trim()
                    Value = $null
                    Received = $temp[1]
                    Sent = $temp[2]
                }
                New-Object -TypeName PSObject -Property $hash
            } elseif($line -match "=") {
                $temp = $line -split "="
                $hash = [ordered]@{
                    Category = $name
                    Key = $temp[0].Trim()
                    Value = $temp[1]
                    Received = $null
                    Sent = $null
                }
                New-Object -TypeName PSObject -Property $hash
            }
        }
    } else {
        $netstat = $(
            if($all -and $lookup) {
                netstat -a -f -o | Select-Object -Skip 3
            } elseif($lookup) {
                netstat -f -o | Select-Object -Skip 3
            } elseif($all) {
                netstat -a -n -o | Select-Object -Skip 3
            } else {
                netstat -n -o | Select-Object -Skip 3
            }
        )
        $netstatCsvFormat = foreach ($line in $netstat) {
            #Remove the empty space that prefix all line in the netstat output (to prevent phantom value, when doing split upon empty spaces.
            $line = $line -replace "^\s\s"

            #Remove the empty space in 'local address', so that the header isn't divided into two values.
            if($line -match "Local\sAddress") {
                $line = $line -replace "Local Address","LocalAddress"
            }

            #Remove the empty space in 'foreing address', so that the header isn't divided into two values.
            if($line -match "Foreign\sAddress") {
                #Change ForeignAddress to RemoteAddress, seems like a better name to me.
                $line = $line -replace "Foreign Address","RemoteAddress"
            }

            $values = @()
            $line -split "\s+" | foreach {
                $values += $_
            }

            $values -join ";"
        }
        $netstatObjects = $netstatCsvFormat | ConvertFrom-Csv -Delimiter ";"
        foreach ($netstatObject in $netstatObjects) {
            if($netstatObject.State -match "^[0-9]+$") {
                $netstatObject.PID = $netstatObject.State
                $netstatObject.State = $null
            }
            $netstatObject | Add-Member -MemberType NoteProperty -Name "PIDName" -Value (Get-Process -Id $netstatObject.PID).Name
            $netstatObject | Add-Member -MemberType NoteProperty -Name "PIDPath" -Value (Get-Process -Id $netstatObject.PID).Path
        }
        $netstatObjects
    }
}