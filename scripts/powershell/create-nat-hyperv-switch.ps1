$switch_name = $args[0]
$ip_address = $args[1]
$net_mask = $args[2]
$net_range = $args[3]

If ("$switch_name" -in (Get-VMSwitch | Select-Object -ExpandProperty Name) -eq $FALSE) {
    "Creating Internal-only switch on Windows Hyper-V host ..."
    New-VMSwitch -SwitchName "$switch_name" -SwitchType Internal
    New-NetIPAddress -IPAddress "$ip_address" -PrefixLength $net_range -InterfaceAlias "vEthernet ($switch_name)"
}
else {
    "Static IP configuration already exists, skipping"
}

If ("$ip_address" -in (Get-NetIPAddress | Select-Object -ExpandProperty IPAddress) -eq $FALSE) {
    "Registering new IP address on Windows Hyper-V host ..."
    New-NetIPAddress -IPAddress "$ip_address" -PrefixLength $net_range -InterfaceAlias "vEthernet ($switch_name)"
}
else {
    "Static IP configuration already registered, skipping"
}

If ("$net_mask" -in (Get-NetNAT | Select-Object -ExpandProperty InternalIPInterfaceAddressPrefix) -eq $FALSE) {
    "Registering new NAT adapter for  Windows Hyper-V host ..."
    New-NetNAT -Name "vEthernet ($switch_name)" -InternalIPInterfaceAddressPrefix "$net_mask"
}
else {
    "New NAT adapter for Windows Hyper-V host already registered, skipping ..."
}
