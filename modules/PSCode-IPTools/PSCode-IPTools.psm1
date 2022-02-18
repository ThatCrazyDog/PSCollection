###
# Helper functions
#
function ConvertNumberBase {
[CmdletBinding(DefaultParameterSetName='default')]
Param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
    [String]$value,

    [Parameter(Mandatory=$true,Position=1)]
    [ValidateSet('Binary', 'Hex', 'Decimal')]
    [String]$from,

    [Parameter(Mandatory=$false,Position=2)]
    [ValidateSet('Binary', 'Hex', 'Decimal')]
    [String]$to = 'Decimal'
)
    BEGIN {
        if($from -eq $to) {
            if($to -eq "Decimal") {
                $to = "Binary"
            } else {
                "From $from, To $to... Uhh, thats a hard one :/"
                break
            }
        }
    }

    PROCESS {
        if($from -eq 'Binary') {
            $valueInDecimal = [Convert]::ToInt32($value, 2)
            if($to -eq 'Hex') {
                $valueInDecimal.ToString('X')
            } elseif($to -eq 'Decimal') {
                $valueInDecimal
            }

        } elseif($from -eq 'Hex') {
            $valueInDecimal = [Convert]::ToInt32($value, 16)
            if($to -eq 'Binary') {
                [System.Convert]::ToString($valueInDecimal,2)
            } elseif($to -eq 'Decimal') {
                [Convert]::ToInt32($value,16)
            }

        } elseif($from -eq 'Decimal') {
            $valueInDecimal = [Convert]::ToInt32($value, 10)
            if($to -eq 'Hex') {
                $valueInDecimal.ToString('X')
            } elseif($to -eq 'Binary') {
                [System.Convert]::ToString($valueInDecimal,2)
            }
        }
    }
}

function ConvertPrefixLengthToMask {
[CmdletBinding(DefaultParameterSetName='default')]
Param(
    [Parameter(Mandatory=$true)]
    [String]$prefixLength
)
    #Break up and comment..!
    (([ipaddress](([UInt32]::MaxValue) -shl (32 - $prefixLength))).IPAddressToString -split "\." | Sort-Object -Descending) -join "."
}

function ConvertSubnetMaskToPrefixLength {
[CmdletBinding(DefaultParameterSetName='default')]
Param(
    [Parameter(Mandatory=$true)]
    [String]$subnetMask
)
    $subnetMaskInBinary = ($subnetMask -split "\." | foreach {ConvertNumberBase -value $_ -from Decimal -to Binary}) -join ""
    $subnetMaskInBinary.TrimEnd('0').Length
}



###
# Exposed scripts (i.e. the module as seen by the user)
#
function Get-IPv4NetworkID {
[CmdletBinding(DefaultParameterSetName='default')]
Param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
    [String]$value,

    [Parameter(Mandatory=$false,Position=2)]
    [ValidateSet('IP/Prefix', 'IP/Mask')]
    [String]$format = 'IP/Prefix'
)
    BEGIN {
        if($format -eq 'IP/Prefix') {
            $mask = ConvertPrefixLengthToMask -prefixLength $($value -split "/" | Select-Object -Last 1)
        } elseif($format -eq 'IP/Mask') {
            $mask = $value -split "/" | Select-Object -Last 1
        }
        $ip = $value -split "/" | Select-Object -First 1
    }

    PROCESS {
        $result = @()
        for($octet = 0; $octet -le 3; $octet++) {
            $result += (($mask -split "\.")[$octet]) -band (($ip -split "\.")[$octet])
        }
        $result -join "."
    }
}






###
# The end
#
Export-ModuleMember *-*