function Get-SchannelProtocols {
[CmdletBinding(DefaultParameterSetName='default')]
Param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("TLS 1.0", "TLS 1.1", "TLS 1.2")]
    [String[]]
    $securityLevel = "TLS 1.0"
)
    <#
        Pre-Script
    #>
    $protocols = @("Multi-Protocol Unified Hello", "PCT 1.0", "SSL 1.0", "SSL 2.0", "SSL 3.0", "TLS 1.0", "TLS 1.1", "TLS 1.2")
    $keys = @("Enabled", "Disabled", "DisabledByDefault")
    $roles = @("Client", "Server")
    
    
    <#
        Process
    #>
    foreach ($protocol in $protocols) {
        foreach ($role in $roles) {
            foreach ($key in $keys) {
                try {
                    $protocolValue = Get-ItemPropertyValue -Path "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\$role" -Name $key -ErrorAction Stop
                    $exist = $true
                    if($protocolValue -eq 1 -or $protocolValue -eq 4294967295) {
                        if($key -eq "Enabled") {
                            $enabled = $true
                        } elseif ($key -eq "DisabledByDefault") {
                            $disabledByDefault = $true
                        } elseif ($key -eq "Disabled") {
                            $disabled = $true
                        }
                    } elseif($protocolValue -eq 0) {
                        if($key -eq "Enabled") {
                            $enabled = $false
                        } elseif ($key -eq "DisabledByDefault") {
                            $disabledByDefault = $false
                        } elseif ($key -eq "Disabled") {
                            $disabled = $false
                        }
                    }
                } catch {
                    $exist = $false
                    $securityLevelCheck = $false
                }
            }
            $hash = [ordered]@{
                Path = "$protocol\$role"
                Exist = $exist
                Enabled = $(
                    if($exist) {
                        if($enabled -eq $null) {
                            $false
                        } else {
                            $enabled
                        }
                    } else {
                        $false
                    }
                )
                Disabled = $(
                    if($exist) {
                        if($disabled -eq $null) {
                            $false
                        } else {
                            $disabled
                        }
                    } else {
                        $false
                    }
                )
                DisabledByDefault = $(
                    if($exist) {
                        if($disabledByDefault -eq $null) {
                            $false
                        } else {
                            $disabledByDefault
                        }
                    } else {
                        $false
                    }
                )
                DeFacto = ""
                SecurityLevel = "$securityLevel"
                SecurityCheck = ""
                        
            }
            
            if($ExecutionContext.SessionState.LanguageMode -eq "ConstrainedLanguage") {
                #FUCK
                $object = New-Object -TypeName PSObject -Property $hash
            } else {
                $defaultProperties = @("Path","Exist","DeFacto","SecurityLevel","SecurityCheck")
                $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet(‘DefaultDisplayPropertySet’,[string[]]$defaultProperties)
                $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
                $object = New-Object -TypeName PSObject -Property $hash | Add-Member MemberSet PSStandardMembers $PSStandardMembers -PassThru
            }
                
            #Check defacto status
            if($object.Disabled -eq $true) {
                $object.DeFacto = "Disabled"
            } elseif($object.Enabled -eq $false -and $object.DisabledByDefault -eq $false -and $object.Disabled -eq $false) {
                $object.DeFacto = "Enabled"
            } elseif($object.Enabled -eq $false -and $object.DisabledByDefault -eq $true) {
                $object.DeFacto = "Enabled"
            } elseif($object.Enabled -eq $true -and $object.DisabledByDefault -eq $false) {
                $object.DeFacto = "Enabled"
            } elseif($object.Enabled -eq $true -and $object.DisabledByDefault -eq $true) {
                $object.DeFacto = "Enabled"
            } else {
                $object.DeFacto = "Check failed"
            }
            
            #Check security match set level
            if((($protocols).IndexOf("$protocol") -ge ($protocols).IndexOf("$securityLevel"))) {
                if($object.DeFacto -eq "Enabled") {
                    $object.SecurityCheck = $true
                } elseif($object.DeFacto -eq "Disabled") {
                    $object.SecurityCheck = $false
                } else {
                    $object.SecurityCheck = "Check failed"
                }
            } elseif((($protocols).IndexOf("$protocol") -lt ($protocols).IndexOf("$securityLevel"))) {
                if($object.DeFacto -eq "Enabled") {
                    $object.SecurityCheck = $false
                } else {
                    $object.SecurityCheck = $true
                }
            }

            $object
        }
    }
}