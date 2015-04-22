# powercli_functions.ps1
PowerShell script with some useful PowerCLI functions

### How to use
    . "<path_to_folder_with_script>\powercli_functions.ps1"

### List of functions

#### Get-View2
This function returns the vSphere View object(s) with names corresponding to specified regular expression and type. Also there is an ability to get VM by IP. 

    Get-Help Remove-File -Full

#### PreStart
This function connects to VIServer, disables deprecation warnings and returns session object. It could connect to existing session or create a new one.

    Get-Help PreStart -Full

#### PostStart
This function disconnects session with VIServer and removes all variables.

    Get-Help PostStart -Full

#### Get-Interval
This function suggests most suitable history interval of vCenter statisctics for selected dates.

    Get-Help Get-Interval -Full

#### Get-Metrics
**This function uses function Get-Stat2 (which could be found in my same-named repo)**

This function collets statisctics for selected metrics of objects provided in list for selected period. Statisctics would be saved to %temp% folder with next file names:

For period 1:

      p1_<managed object reference ID>_Metrics.csv

For period 2:

      p2_<managed object reference ID>_Metrics.csv

    Get-Help Get-Metrics -Full

#### New-VM-SDK
This function creates a new virtual machine with the provided parameters. The network adapter and the SCSI adapter of the new virtual machine are created of the recommended type for the OS that is specified by the GuestId parameter. If  the custSpec parameter is used,  the virtual machine is customized according to the spec.

Function accepts only SDK object [`VMware.Vim.CustomizationSpecItem`] as a customization specification.

    Get-Help New-VM-SDK -Full

#### New-HardDisk-SDK
This function creates a new hard disk on the specified virtual machine (and datastore). Main feature of this function - is **support for SATA controllers**.

    Get-Help New-HardDisk-SDK -Full

#### Get-FolderPath
This function returns full path to specified Virtual Infrasctructure folder.

    Get-Help Get-FolderPath -Full

#### Set-VM-SDK
This function modifies the configuration of the virtual machine. Main feature of this function - is **ability to set amount of Cores Per Socket** which is not available in Set-VM cmdlet.

    Get-Help Set-VM-SDK -Full

#### Get-VMEvents
This function retrieves information about the events of VM on a vCenter Server system. An event is any action in the vCenter Server system or ESX/ESXi host.

    Get-Help Get-VMEvents -Full

#### Clone-OSCustomizationSpec-SDK
This functions clones existing OS customization specification to new non persistent one. Function returns SDK object of type [`VMware.Vim.CustomizationSpecItem`].

    Get-Help Clone-OSCustomizationSpec-SDK -Full

#### Set-OSCustomizationNicMapping-SDK
This function modifies the provided OS customization NIC mappings. Function accepts and returns only SDK object of type [`VMware.Vim.CustomizationSpecItem`].

    Get-Help Set-OSCustomizationNicMapping-SDK -Full

#### Set-OSCustomizationSpec-SDK
This function modifies the specified OS customization specification. Function accepts and returns only SDK object of type [`VMware.Vim.CustomizationSpecItem`].

    Get-Help Set-OSCustomizationSpec-SDK -Full
