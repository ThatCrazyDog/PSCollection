Query netstat and parse the data into object format.

Examples:
Get-Netstat | ft
Get-Netstat -all | ft
Get-Netstat -lookup | ft

Get-Netstat -statistics | ft
Get-Netstat -interfaceStatistics | ft