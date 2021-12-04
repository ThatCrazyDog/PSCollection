function Set-SchannelProtocols {
[CmdletBinding(DefaultParameterSetName='default')]
Param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("TLS 1.0", "TLS 1.1", "TLS 1.2")]
    [String[]]
    $securityLevel = "TLS 1.0",

    [Parameter(Mandatory=$false)]
    [switch]
    $whatif
)
    <#
        Pre-Script
    #>
    #CHECK IF ADMIN
    if([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains 'S-1-5-32-544') {
        
    } else {
        throw "This script can only be run as admin, otherwise we couldn't make change in the registry."
    }

    $protocols = @("Multi-Protocol Unified Hello", "PCT 1.0", "SSL 1.0", "SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1", "TLS 1.2")
    $keys = @("Enabled", "Disabled", "DisabledByDefault")
    $roles = @("Client", "Server")
    $resultArray = @()
    if($whatif) {
        "Get-SchannelProtocols report..."
    } else {
        if(${function:Get-SchannelProtocols}) {
            Get-SchannelProtocols -securityLevel $securityLevel | Select-Object -Property Path,Exist,Enabled,Disabled,DisabledByDefault,DeFacto,SecurityLevel,SecurityCheck,@{Name = 'From'; Expression = {"Before"}}
        }
    }
    
    <#
        Process
    #>
    foreach ($protocol in $protocols) {
        foreach ($role in $roles) {
            $path = "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\$role"
            if($whatif) {
                #New-Item -Path $path -WhatIf
            } else {
                try {
                    New-Item -Path $path -Force -ErrorAction Stop | Out-Null
                } catch {
                    if($_.Exception.Message -like "Access to the registry key*") {
                        "Access to the registry was denied: $path"
                    } else {
                        $_.Exception
                    }
                    throw "Cant create missing paths"
                }
            }
            foreach ($key in $keys) {
                if($key -eq "Enabled") {
                    if((($protocols).IndexOf("$protocol") -ge ($protocols).IndexOf("$securityLevel"))) {
                        $keyValue = 1
                    } else {
                        $keyValue = 0
                    }
                } elseif($key -eq "Disabled" -or $key -eq "DisabledByDefault") {
                    if((($protocols).IndexOf("$protocol") -ge ($protocols).IndexOf("$securityLevel"))) {
                        $keyValue = 0
                    } else {
                        $keyValue = 1
                    }
                }
                
                if($whatif) {
                    "New-ItemProperty -Path $path -Name $key -Value $keyValue -PropertyType DWORD -Force"
                } else {
                    New-ItemProperty -Path $path -Name $key -Value $keyValue -PropertyType DWORD -Force -ErrorAction Continue | Out-Null
                }
            }
        }
    }
    if($whatif) {
        "Get-SchannelProtocols report..."
    } else {
        if(${function:Get-SchannelProtocols}) {
            Get-SchannelProtocols -securityLevel $securityLevel | Select-Object -Property Path,Exist,Enabled,Disabled,DisabledByDefault,DeFacto,SecurityLevel,SecurityCheck,@{Name = 'From'; Expression = {"After"}}
        }
    }
    
}