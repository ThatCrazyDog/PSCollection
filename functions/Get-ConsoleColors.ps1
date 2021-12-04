function Get-ConsoleColors {
    $i = 0
    [enum]::GetValues([System.ConsoleColor]) | Foreach-Object {Write-Host "$i`t$_" -ForegroundColor $_; $i++}
}