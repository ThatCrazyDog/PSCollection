function Get-Netstat ([switch]$all, [switch]$lookup) {
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
            $line = $line -replace "Foreign Address","ForeignAddress"
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