$switchname = $args[0]

If ("$switchname" -in (Get-VMSwitch | Select-Object -ExpandProperty Name) -eq $FALSE) {
    "Creating Internal-only switch named on Windows Hyper-V host..."
    New-VMSwitch -SwitchName "$switchname" -SwitchType Internal
    New-NetIPAddress -IPAddress $args[1] -PrefixLength 24 -InterfaceAlias "vEthernet ($switchname)"
}
else {
    "Static IP configuration already exists, skipping"
}

If ($args[1] -in (Get-NetIPAddress | Select-Object -ExpandProperty IPAddress) -eq $FALSE) {
    "Registering new IP address on Windows Hyper-V host..."
    New-NetIPAddress -IPAddress $args[1] -PrefixLength $args[3] -InterfaceAlias "vEthernet ($switchname)"
}
else {
    "Static IP configuration already registered, skipping"
}

If ($args[2] -in (Get-NetNAT | Select-Object -ExpandProperty InternalIPInterfaceAddressPrefix) -eq $FALSE) {
    "Registering new NAT adapter for  Windows Hyper-V host..."
    New-NetNAT -Name "$switchname" -InternalIPInterfaceAddressPrefix $args[2]
}
else {
    "New NAT adapter for Windows Hyper-V host already registered, skipping"
}