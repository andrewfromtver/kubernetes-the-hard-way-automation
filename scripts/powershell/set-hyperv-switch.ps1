Get-VM $args[0] | Get-VMNetworkAdapter | Connect-VMNetworkAdapter -SwitchName $args[1]
