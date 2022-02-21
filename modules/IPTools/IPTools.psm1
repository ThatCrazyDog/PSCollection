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
    <#
        Note;
            Beware, there is no padding of binary numbers!
    #>
    BEGIN {
        if($from -eq $to) {
            if($to -eq "Decimal") {
                #If from and to is both 'Decimal', change default behavior from Binary>Decimal to Decimal>Binary
                $to = "Binary"
            } else {
                #Both from and to, have been set to the same value... Hope it was a brain fart...
                #Should I just output the provided input?
                "From $from, To $to... Uhh, thats a hard one :/"
                break
            }
        }
    }

    PROCESS {
        #Do the math
        if($from -eq 'Binary') {
            $valueInDecimal = [Convert]::ToInt32($value, 2)
            if($to -eq 'Hex') {
                #Binary 2 Hex
                $valueInDecimal.ToString('X')
            } elseif($to -eq 'Decimal') {
                #Binary 2 Decimal
                $valueInDecimal
            }

        } elseif($from -eq 'Hex') {
            $valueInDecimal = [Convert]::ToInt32($value, 16)
            if($to -eq 'Binary') {
                #Hex 2 Binary
                [System.Convert]::ToString($valueInDecimal,2)
            } elseif($to -eq 'Decimal') {
                #Hex 2 Decimal
                [Convert]::ToInt32($value,16)
            }

        } elseif($from -eq 'Decimal') {
            $valueInDecimal = [Convert]::ToInt32($value, 10)
            if($to -eq 'Hex') {
                #Decimal 2 Hex
                $valueInDecimal.ToString('X')
            } elseif($to -eq 'Binary') {
                #Decimal 2 Binary
                [System.Convert]::ToString($valueInDecimal,2)
            }
        }
    }
}



###
# Exposed scripts (i.e. the module as seen by the user)
#
function Convert-PrefixLengthToMask {
[CmdletBinding(DefaultParameterSetName='default')]
Param(
    [Parameter(Mandatory=$true)]
    [String]$prefixLength
)
    #Get 32-bit unsigned integer, shift it left (Bitwise comparison), with 32 bits minus our prefixLengt (we are doing it reversed, didn't find other ways). 
    $reversedMask = [ipaddress](([UInt32]::MaxValue) -shl (32 - $prefixLength))

    #Substract the 32-bits from earlier, as a string.
    #Then by splitting the mask by its notations, we can then sort the array/pipeline (descending) as we will always have the higher numbers first in a network mask.
    ($reversedMask.IPAddressToString -split "\." | Sort-Object -Descending) -join "."
}


function Convert-SubnetMaskToPrefixLength {
[CmdletBinding(DefaultParameterSetName='default')]
Param(
    [Parameter(Mandatory=$true)]
    [String]$subnetMask
)
    #Split the provided subnet mask, convert decimal to binary and join it all together.
    $subnetMaskInBinary = ($subnetMask -split "\." | foreach {ConvertNumberBase -value $_ -from Decimal -to Binary}) -join ""
    
    #Trim the end of string for any zeros, then count the bits/length and output it.
    $subnetMaskInBinary.TrimEnd('0').Length
}


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
        #Determine format, at extract values.
        if($format -eq 'IP/Prefix') {
            #Prefix is used, extract and convert value into a mask.
            $mask = Convert-PrefixLengthToMask -prefixLength $($value -split "/" | Select-Object -Last 1)
        } elseif($format -eq 'IP/Mask') {
            $mask = $value -split "/" | Select-Object -Last 1
        }
        $ip = $value -split "/" | Select-Object -First 1
    }

    PROCESS {
        #Create an array to store the individual octects.
        $result = @()
        for($octet = 0; $octet -le 3; $octet++) {
            #Go through each (4) octects and gather network ID by using bitwise AND operater.
            $result += (($mask -split "\.")[$octet]) -band (($ip -split "\.")[$octet])
        }
        $result -join "."
    }
}


Function Get-IPv4Information {
[CmdletBinding(DefaultParameterSetName='default')]
Param(
    [Parameter(Mandatory=$true,ParameterSetName='ByAlias')]
    [ArgumentCompleter({
        param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
        (Get-NetAdapter | Where-Object {$_.InterfaceIndex -in (Get-NetIPAddress -AddressFamily IPv4).InterfaceIndex}).Name | foreach {"`'$_`'"}
    })]
    [String]$adapterName,

    [Parameter(Mandatory=$true,ParameterSetName='ByDescription')]
    [ArgumentCompleter({
        param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
        (Get-NetAdapter | Where-Object {$_.InterfaceIndex -in (Get-NetIPAddress -AddressFamily IPv4).InterfaceIndex}).InterfaceDescription | foreach {"`'$_`'"}
    })]
    [String]$adapterDescription,

    [Parameter(Mandatory=$true,ParameterSetName='ByIndex')]
    [ArgumentCompleter({
        param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
        (Get-NetAdapter | Where-Object {$_.InterfaceIndex -in (Get-NetIPAddress -AddressFamily IPv4).InterfaceIndex}).InterfaceIndex
    })]
    [int]$adapterIndex
)
    if($adapterName) {
        Try {
            $networkAdapter = Get-NetAdapter -Name $adapterName -ErrorAction Stop
        } Catch {
            # Failed to gather netadapter information
            throw "Couldn't fetch information about any adapter named $adapterName"
        }
    } elseif($adapterDescription) {
        Try {
            $networkAdapter = Get-NetAdapter -InterfaceDescription $adapterDescription -ErrorAction Stop
        } Catch {
            # Failed to gather netadapter information
            throw "Couldn't fetch information about any adapter with a description like: $adapterName"
        }
    } elseif($adapterIndex) {
        Try {
            $networkAdapter = Get-NetAdapter -InterfaceIndex $adapterIndex -ErrorAction Stop
        } Catch {
            # Failed to gather netadapter information
            throw "Couldn't fetch information about any adapter with index: $adapterIndex"
        }
    } else {
        # Get em' all...
        $networkAdapter = Get-NetAdapter | Where-Object {$_.InterfaceIndex -in ((Get-NetIPAddress -AddressFamily IPv4).InterfaceIndex -le 32)}
    }

    foreach ($adapter in $networkAdapter) {
        $networkAdapterInformation = $adapter | Get-NetIPAddress -AddressFamily IPv4
        
        #Multiply ip addresses can be returned, loop through them.
        foreach ($ipInformation in $networkAdapterInformation) {
            $networkIPAddress = $ipInformation.IPAddress
            
            $hash = [ordered]@{
                Status = $adapter.Status
                Name = $adapter.Name
                Description = $adapter.InterfaceDescription
                IPv4 = $networkIPAddress
                SubnetMask = Convert-PrefixLengthToMask -prefixLength ($ipInformation.PrefixLength | Where-Object {$_.Prefixlength -le 32})
                NetworkID = Get-IPv4NetworkID -value "$networkIPAddress/$($ipInformation.PrefixLength)" -format IP/Prefix
            }
            New-Object -TypeName PSObject -Property $hash
        }
        
    }
}


###
# The end
#
Export-ModuleMember *-*