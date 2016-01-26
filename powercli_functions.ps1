Function Global:Get-View2 {
  <#
    .Synopsis
       This function returns the vSphere View object(s) with names corresponding to specified regular expression and type.
    .DESCRIPTION
       This function returns the vSphere View object(s) with names corresponding to specified regular expression and type.
    .EXAMPLE
       $vm = Get-View2 "^VM001$"
    .EXAMPLE
       $vm = Get-View2 "^VM001$" -Property Name,Parent,Guest
    .EXAMPLE
       $vmlist = Get-View2 "^VM.*"
    .EXAMPLE
       $vmhost = Get-View2 -ViewType HostSystem "VMHost001"
    .EXAMPLE
       $vmhost = Get-View2 -IP "^192\.168.*"
    .EXAMPLE
       $vmhost = Get-View2 -IP "^10\.10\.10\.10$"
    .EXAMPLE
       $templates = Get-View2 -ViewType Template
    .PARAMETER Name
      Regular expression of name(s) of object(s) to find.
    .PARAMETER ViewType
      Specifies the type of the View object(s) you want to retrieve.
    .PARAMETER IP
      Regular expression of IP of VM(s) to find.
      You could find only VM(s) by IP!
    .PARAMETER Property
      Specifies the properties of the view object you want to retrieve. If no value is given, all properties are shown.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function returns the vSphere View objects with names corresponding to specified regular expression and type.
    .OUTPUTS
       vSphere View object(s)
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(ParameterSetName = "Name", Position = 0)][string]$Name=".*",
    [parameter(ParameterSetName = "Name")]
    [ValidateSet("ClusterComputeResource",`
                 "ComputeResource",`
                 "Datacenter",`
                 "Datastore",`
                 "DistributedVirtualPortgroup",`
                 "DistributedVirtualSwitch",`
                 "Folder",`
                 "HostSystem",`
                 "Network",`
                 "OpaqueNetwork",`
                 "ResourcePool",`
                 "StoragePod",`
                 "VirtualApp",`
                 "VirtualMachine",`
                 "Template",`
                 "VmwareDistributedVirtualSwitch")][string]$ViewType="VirtualMachine",
    [parameter(Mandatory = $true, ParameterSetName = "IP")][string]$IP,
    [string[]]$Property=$null
  )
  if ($IP) {
    $result = Get-View -ViewType VirtualMachine -Filter @{"Guest.IpAddress"="$IP";"Config.Template"="False"} -Property $Property
  } else {
    if ($ViewType -eq "Template") {
      $result = Get-View -ViewType VirtualMachine -Filter @{Name="$Name";"Config.Template"="True"} -Property $Property
    } elseif ($ViewType -eq "VirtualMachine") {
      $result = Get-View -ViewType $ViewType -Filter @{Name="$Name";"Config.Template"="False"} -Property $Property
      #если не нашли по именим ВМ, то пробуем найти по dns имени гостевой ОС
      if(!($result)) {
        $result = Get-View -ViewType $ViewType -Filter @{"Guest.HostName"="$Name";"Config.Template"="False"} -Property $Property
      }
    } else {
      $result = Get-View -ViewType $ViewType -Filter @{Name="$Name"} -Property $Property
    }
  }
  return $result
}

Function Global:Import-PCLImodules {
  <#
    .Synopsis
       This function imports PowerCLI modules necessary for proper script work.
    .DESCRIPTION
       This function imports PowerCLI modules necessary for proper script work.
    .EXAMPLE
       Import-PCLImodules
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function imports PowerCLI modules necessary for proper script work.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  Write-Host "Импорт модулей..." -f gray -NoNewline
  $exectime = Measure-Command {
    if ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null)
    {
      Add-PSSnapin VMware.VimAutomation.Core -ErrorAction Stop
    }

    $pcliver = Get-PowerCLIVersion
    if ($pcliver.Major -le 5) {
      if ((Get-PSSnapin -Name VMware.VimAutomation.Vds -ErrorAction SilentlyContinue) -eq $null) {
        Add-PSSnapin VMware.VimAutomation.Vds -ErrorAction Stop
      }
      if ((Get-PSSnapin -Name VMware.VimAutomation.Storage -ErrorAction SilentlyContinue) -eq $null) {
        Add-PSSnapin VMware.VimAutomation.Storage -ErrorAction Stop
      }
    }
    else {
      Import-Module VMware.VimAutomation.Vds -ErrorAction Stop
      Import-Module VMware.VimAutomation.Storage -ErrorAction Stop
    }
  }
  Write-Host "Готово!" -f Green -NoNewline
  Write-Host " ($($exectime.Minutes) м., $($exectime.Seconds) с.)" -f Yellow
}

Function Global:PreStart {
  <#
    .Synopsis
       This function connects to VIServer, disables deprecation warnings and returns session object.
    .DESCRIPTION
       This function connects to VIServer, disables deprecation warnings and returns session object.
       It could connect to existing session or create a new one.
    .EXAMPLE
       $visession = PreStart -VIServer "vcenter.alpha.beta.ru"
    .EXAMPLE
       PreStart -visession $visession | Out-Null
    .PARAMETER visession
      VIServer session object of type [VIServerImpl] that should be used.
    .PARAMETER VIServer
      VIServer address to connect to.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function connects to VIServer, disables deprecation warnings and returns session object.
    .OUTPUTS
       [VIServerImpl]
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(Mandatory = $true, ParameterSetName = "visession")][PSObject]$visession=$null,
    [parameter(Mandatory = $true, ParameterSetName = "viserver")][string]$VIServer=$null
  )
  Import-PCLImodules

  Write-Host "Подключение к vCenter $(&{if ($VIServer) {$VIServer} else {$visession.Name}})..." -f gray -NoNewline
  $exectime = Measure-Command {
    if ($visession) {
      $visession = Connect-VIServer $visession.Name -Session $visession.SessionId -ErrorAction Stop -WarningAction SilentlyContinue
    } elseif ($VIServer) {
      $visession = Connect-VIServer $VIServer -ErrorAction Stop -WarningAction SilentlyContinue
    }
  }
  Write-Host "Готово!" -f Green -NoNewline
  Write-Host " ($($exectime.Minutes) м., $($exectime.Seconds) с.)" -f Yellow

  # Отключаем сообщения об устаревших полях
  Set-PowerCLIConfiguration -DisplayDeprecationWarnings:$false -Scope Session -Confirm:$false | Out-Null

  return $visession
}

Function Global:PostStart {
  <#
    .Synopsis
       This function disconnects session with VIServer and removes all variables.
    .DESCRIPTION
       This function disconnects session with VIServer and removes all variables.
    .EXAMPLE
       PostStart -visession $visession
    .PARAMETER visession
      VIServer session object of type [VIServerImpl] that should be used.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This functions disconnects session with VIServer and removes all variables.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(Mandatory = $true)][VMware.VimAutomation.ViCore.Impl.V1.VIServerImpl]$visession
  )
  disconnect-viserver $visession.Name -confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
  Remove-Variable -Force * -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
  Remove-Variable -Force * -Scope Script -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
  Remove-Variable -Force * -Scope Global -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
  [System.GC]::Collect()
}

Function Global:Get-Interval {
  <#
    .Synopsis
       This function suggests most suitable history interval of vCenter statisctics for selected dates.
    .DESCRIPTION
       This function suggests most suitable history interval of vCenter statisctics for selected dates.
    .EXAMPLE
       $somedate = Get-Date

       Get-Interval -startdate $somedate.AddDays(-1) -enddate $somedate
    .EXAMPLE
       $somedate = Get-Date

       Get-Interval -startdate $somedate.AddDays(-30) -enddate $somedate
    .PARAMETER startdate
      Date of interval's beginning.
    .PARAMETER enddate
      Date of interval's end.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function suggests most suitable history interval of vCenter statisctics for selected dates.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(Mandatory = $true)][DateTime]$startdate,
    [parameter(Mandatory = $true)][DateTime]$enddate
  )
  $curdate = Get-Date
  $curdiff = $curdate - $enddate
  $pdiff = $curdate - $startdate

  $pinterval = $null
  if ($curdiff.Days -le 1) {
    if ($pdiff.Days -eq 0) {
      $pinterval = "RT" # история за настоящее время
    } elseif ($pdiff.Days -le 1) {
      $pinterval = "HI1" # история за последний день
    } elseif ($pdiff.Days -le 7) {
      $pinterval = "HI2" # история за последнюю неделю
    } elseif ($pdiff.Days -le 30) {
      $pinterval = "HI3" # история за последний месяц
    } else {
      $pinterval = "HI4" # история за последний год
    }
  } elseif ($curdiff.Days -le 7) {
    if ($pdiff.Days -le 7) {
      $pinterval = "HI2" # история за последнюю неделю
    } elseif ($pdiff.Days -le 30) {
      $pinterval = "HI3" # история за последний месяц
    } else {
      $pinterval = "HI4" # история за последний год
    }
  } elseif ($curdiff.Days -le 30) {
    if ($pdiff.Days -le 30) {
      $pinterval = "HI3" # история за последний месяц
    } else {
      $pinterval = "HI4" # история за последний год
    }
  } else {
    $pinterval = "HI4" # история за последний год
  }

  switch ($pinterval) {
    "RT" {
      $SamplingPeriod=20
    }
    "HI1" {
      $SamplingPeriod=300
    }
    "HI2" {
      $SamplingPeriod=1800
    }
    "HI3" {
      $SamplingPeriod=7200
    }
    "HI4" {
      $SamplingPeriod=86400
    }
  }

  $result = New-Object PSObject -Property @{
    Value = $pinterval
    SamplingPeriod = $SamplingPeriod
  }

  return $result
}

Function Global:Get-Metrics {
  <#
    .Synopsis
       This function collets statisctics for selected metrics of objects provided in list for selected period.
    .DESCRIPTION
       This function collets statisctics for selected metrics of objects provided in list for selected period.
       Statisctics would be saved to %temp% folder with next file names:
       For period 1:
         p1_<managed object reference ID>_Metrics.csv
       For period 2:
         p2_<managed object reference ID>_Metrics.csv
    .EXAMPLE
       $somedate = Get-Date

       $metricslist = @()
       $metricslist += "cpu.usage.average"
       $metricslist += "cpu.usagemhz.average"
       $metricslist += "mem.usage.average"
       $metricslist += "mem.active.average"
       $metricslist += "cpu.ready.summation"

       $vmlist = Get-View -ViewType VirtualMachine -Property Name

       Get-Metrics -selecteddate $somedate -period1 30 -metricslist $metricslist -list $vmlist

       As a result you would see files containing statistics and named like this:
         p1_VirtualMachine-vm-2595_Metrics.csv 
       in you temp folder.
    .EXAMPLE
       $somedate = (Get-Date).AddDays(-7)

       $metricslist = @()
       $metricslist += "cpu.usage.average"
       $metricslist += "cpu.usagemhz.average"

       $vmlist = Get-View -ViewType VirtualMachine -Property Name

       Get-Metrics -selecteddate $somedate -period1 7 -includePeriod2 True -period2 30 -metricslist $metricslist -list $vmlist

       As a result you would see files containing statistics and named like this:
         p1_VirtualMachine-vm-2595_Metrics.csv
         p2_VirtualMachine-vm-2595_Metrics.csv 
       in you temp folder.
    .PARAMETER selecteddate
      Last date of selected period, from which statisctics are going to be collected.
    .PARAMETER period1
      Amount of days in 1st period.
    .PARAMETER includePeriod2
      Determines if statistics for second period should be collected or not.
    .PARAMETER period2
      Amount of days in 2nd period.
    .PARAMETER metricslist
      List of metrics to collect.
    .PARAMETER list
      List of objects for which statistics should be collected. Usually it's virtual machine or host.
    .PARAMETER selectcount
      Amount of objects that should be processed at one time.
    .PARAMETER singlefile
      Forces function to save all metrics for period in one file instead of many.
    .PARAMETER groupbymetrics
      Forces function to group all metrics by counter names.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function collets statisctics for selected metrics of objects provided in list for selected period.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(Mandatory = $true, ParameterSetName = "basic")]$selecteddate,
    [parameter(Mandatory = $true, ParameterSetName = "basic")][int]$period1,
    [parameter(Mandatory = $false, ParameterSetName = "basic")][ValidateSet($true,$false)][bool]$includePeriod2 = $false,
    [parameter(Mandatory = $false, ParameterSetName = "basic")][int]$period2,
    [parameter(Mandatory = $true, ParameterSetName = "basic")][ValidateScript({
      $_ | %{
        if ($_ -match "[A-Za-z]+\.[A-Za-z]+\.[A-Za-z]+") {$true} else {$false}
      }
    })][PSObject]$metricslist,
    [parameter(Mandatory = $true, ParameterSetName = "basic")][PSObject]$list,
    [parameter(Mandatory = $false, ParameterSetName = "basic")][int]$selectcount = 100,
    [parameter(Mandatory = $false, ParameterSetName = "basic")]
    [parameter(Mandatory = $false, ParameterSetName = "singlefile")][switch]$singlefile,
    [parameter(Mandatory = $false, ParameterSetName = "basic")]
    [parameter(Mandatory = $false, ParameterSetName = "groupbymetrics")][switch]$groupbymetrics
  )

  $enddate = Get-Date $selecteddate

  #1 период
  $p1startdate = $(Get-Date $enddate).AddDays("-$period1")
  # вычисляем, в какой истории искать значения
  $p1interval = Get-Interval -startdate $p1startdate -enddate $enddate
  [int]$skiplines = 0
  $first = $true
  while ($skiplines -lt @($list).Count) {
    Write-Host "Получаем метрики для $skiplines - $($skiplines + $selectcount) объектов за 1ый период..." -f gray -NoNewline
    $exectime = Measure-Command {
      $list2 = $list | select -First $selectcount -Skip $skiplines
      if (($p1interval.Value -eq "HI1") -or ($p1interval.Value -eq "RT")) {
        $p1out = Get-Stat2 -Entity $list2 -Interval $p1interval.Value -Stat $metricslist -SkipInstanceCheck -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      } else {
        $p1out = Get-Stat2 -Entity $list2 -Start $p1startdate -Finish $enddate -Interval $p1interval.Value -Stat $metricslist -SkipInstanceCheck -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      }
      if ($singlefile.IsPresent) {
        $csvFile = ($env:temp + "\p1_" + $(Get-Date $enddate -Format dd.MM.yyyy) + "_Metrics.csv")
        if ($first) {
          Remove-File $csvFile
          $first = $false
        }
        $p1out | Export-Csv -NoTypeInformation -Encoding Default -Delimiter ";" -Append -Path $csvFile
      } elseif ($groupbymetrics.IsPresent) {
          $group = $p1out | Group-Object -Property CounterName
          ForEach ($item in $group) {
            $csvFile = ($env:temp + "\p1_" + $($item.Name) + "_Metrics.csv")
            if ($first) {
              Remove-File $csvFile
            }
            $item.Group | Export-Csv -NoTypeInformation -Encoding Default -Delimiter ";" -Append -Path $csvFile
          }
          $first = $false
          if ($item) {
            Remove-Variable -Name item -Force
          }
          Remove-Variable -Name group -Force
      } else {
        $group = $p1out | Group-Object -Property EntityId
        ForEach ($item in $group) {
          $csvFile = ($env:temp + "\p1_" + $($item.Name) + "_Metrics.csv")
          Remove-File $csvFile
          $item.Group | Export-Csv -NoTypeInformation -Encoding Default -Delimiter ";" -Path $csvFile
        }
        if ($item) {
          Remove-Variable -Name item -Force
        }
        Remove-Variable -Name group -Force
      }
      Remove-Variable -Name p1out -Force
      if ($list2) {
        Remove-Variable -Name list2 -Force
      }
      [System.GC]::Collect()
      $skiplines += $selectcount
    }
    Write-Host "Готово!" -f Green -NoNewline
    Write-Host " ($($exectime.Minutes) м., $($exectime.Seconds) с.)" -f Yellow
  }

  # если 2ой период выбран
  if ($includePeriod2 -eq $true) {
    # если период 2 равен периоду 1
    if ($period2 -eq $period1) {
      Write-Host "Копируем метрики для $($list.Count) объектов во 2ой период..." -f gray -NoNewline
      $exectime = Measure-Command {
        ForEach ($litem in $list) {
          $csvFile1 = ($env:temp + "\p1_" + $($litem.MoRef.ToString()) + "_Metrics.csv")
          $csvFile2 = ($env:temp + "\p2_" + $($litem.MoRef.ToString()) + "_Metrics.csv")
          if (Test-Path $csvFile1) {
            Copy-Item -Path $csvFile1 -Destination $csvFile2 -Force -Confirm:$false
          }
          if ($csvFile1) {
            Remove-Variable -Name csvFile1 -Force -Confirm:$false
          }
          if ($csvFile2) {
            Remove-Variable -Name csvFile2 -Force -Confirm:$false
          }
        }
      }
      Write-Host "Готово!" -f Green -NoNewline
      Write-Host " ($($exectime.Minutes) м., $($exectime.Seconds) с.)" -f Yellow
    } else {
      #2 период
      $p2startdate = $(Get-Date $enddate).AddDays("-$period2")
      # вычисляем, в какой истории искать значения
      $p2interval = Get-Interval -startdate $p2startdate -enddate $enddate
      [int]$skiplines = 0
      $first = $true
      while ($skiplines -lt @($list).Count) {
        Write-Host "Получаем метрики для $skiplines - $($skiplines + $selectcount) объектов за 2ой период..." -f gray -NoNewline
        $exectime = Measure-Command {
          $list2 = $list | select -First $selectcount -Skip $skiplines
          if (($p2interval.Value -eq "HI1") -or ($p2interval.Value -eq "RT")) {
            $p2out = Get-Stat2 -Entity $list2 -Interval $p2interval.Value -Stat $metricslist -SkipInstanceCheck -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
          } else {
            $p2out = Get-Stat2 -Entity $list2 -Start $p2startdate -Finish $enddate -Interval $p2interval.Value -Stat $metricslist -SkipInstanceCheck -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
          }
          if ($singlefile.IsPresent) {
            $csvFile = ($env:temp + "\p2_Metrics.csv")
            if ($first) {
              Remove-File $csvFile
              $first = $false
            }
            $p2out | Export-Csv -NoTypeInformation -Encoding Default -Delimiter ";" -Append -Path $csvFile
          } elseif ($groupbymetrics.IsPresent) {
            $group = $p2out | Group-Object -Property CounterName
            ForEach ($item in $group) {
              $csvFile = ($env:temp + "\p2_" + $($item.Name) + "_Metrics.csv")
              if ($first) {
                Remove-File $csvFile
              }
              $item.Group | Export-Csv -NoTypeInformation -Encoding Default -Delimiter ";" -Append -Path $csvFile
            }
            $first = $false
            if ($item) {
              Remove-Variable -Name item -Force
            }
            Remove-Variable -Name group -Force
          } else {
            $group = $p2out | Group-Object -Property EntityId
            ForEach ($item in $group) {
              $csvFile = ($env:temp + "\p2_" + $($item.Name) + "_Metrics.csv")
              Remove-File $csvFile
              $item.Group | Export-Csv -NoTypeInformation -Encoding Default -Delimiter ";" -Path $csvFile
            }
            if ($item) {
              Remove-Variable -Name item -Force
            }
            Remove-Variable -Name group -Force
          }
          Remove-Variable -Name p2out -Force
          if ($list2) {
            Remove-Variable -Name list2 -Force
          }
          [System.GC]::Collect()
          $skiplines += $selectcount
        }
        Write-Host "Готово!" -f Green -NoNewline
        Write-Host " ($($exectime.Minutes) м., $($exectime.Seconds) с.)" -f Yellow
      }
    }
  }

}

Function Global:New-VM-SDK {
  <#
    .Synopsis
       This function creates a new virtual machine.
    .DESCRIPTION
       This function creates a new virtual machine with the provided parameters. The network adapter and the SCSI adapter of the new virtual machine are created of the recommended type for the OS that is specified by the GuestId parameter. If  the OSCustomizationSpec parameter is used,  the virtual machine is customized according to the spec.
    .EXAMPLE
       $folder = Get-Folder "Some folder"

       $task = New-VM-SDK -Name "VM001" -ResourcePool "Cluster001" -Template "Some_OS_template" -datastore "DS-CLUSTER-001" -Location $folder -custSpec $customization_spec
    .EXAMPLE
       $folder = Get-Folder "Some folder"

       $task = New-VM-SDK -Name "VM001" -VMHost "VMHost001" -Template "Some_OS_template" -datastore "DS-CLUSTER-001" -Location $folder -custSpec $customization_spec
    .EXAMPLE
       $folder = Get-Folder "Some folder"

       $task = New-VM-SDK -Name "VM001" -VMHost "VMHost001" -Template "Some_OS_template" -datastore "DS-001" -Location $folder
    .PARAMETER Name
      Specifies a name for the new virtual machine.
    .PARAMETER Template
      Specifies the virtual machine template you want to use for the creation of the new virtual machine.
    .PARAMETER VMHost
      Specifies the host on which you want to create the new virtual machine.
    .PARAMETER ResourcePool
      Specifies Cluster where you want to place the new virtual machine.
    .PARAMETER datastore
      Specifies the datastore where you want to place the new virtual machine.
      If a DatastoreCluster is passed to the Datastore parameter, the virtual machine is placed in the DatastoreCluster in an automated SDRS mode and with enabled intra-VM affinity rule (unless another rule is specified).
    .PARAMETER Location
      Specifies the folder where you want to place the new virtual machine.
    .PARAMETER custSpec
      Specifies a customization specification that is to be applied to the new virtual machine.
    .PARAMETER RunAsync
      Indicates that the command returns immediately without waiting for the task to complete.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function creates a new virtual machine.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(Mandatory = $true)][string]$Name,
    [parameter(Mandatory = $true)][string]$Template,
    [parameter(Mandatory = $true, ParameterSetName = "vmhost")][string]$VMHost,
    [parameter(Mandatory = $true, ParameterSetName = "cluster")][string]$ResourcePool,
    [parameter(Mandatory = $true)][string]$datastore,
    [parameter(Mandatory = $true)][PSObject]$Location,
    [VMware.Vim.CustomizationSpecItem]$custSpec,
    [switch]$RunAsync
  )
  $start_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$start_date	New-VM-SDK	Started execution"

  #Спецификация, содержащая датастор для ВМ, а так же кластер/хост для деплоя
  $vmrSpec = New-Object VMware.Vim.VirtualMachineRelocateSpec

  #Датастор
  # Если переданный датастор не является кластером, то
  $exec_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$exec_date	New-VM-SDK	Датастор"
  $LUN = get-datastore $datastore -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
  if ($LUN) {
    $storcluster = $false
    $LUNview = get-view $LUN.id -Property Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    $vmrSpec.datastore = $LUNview.moref
  } else { # если является кластером, то
    $LUN = Get-DatastoreCluster $datastore -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    $storcluster = $true
    $LUNview = get-view $LUN.id -Property Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
  }
  
  #ресурсный пул (хост/кластер)
  $exec_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$exec_date	New-VM-SDK	ресурсный пул"
  if ($ResourcePool) {
    $cluster = Get-View (get-cluster $ResourcePool).id -Property Name,ResourcePool
	$vmrSpec.pool = $cluster.resourcepool
  } elseif($VMHost) {
    $VMHost = $VMHost -replace "\(","\(" -replace "\)","\)" -replace "\.","\." -replace "\^","\^" -replace "\$","\$" -replace "\+","\+"
    $hostview = Get-View -ViewType HostSystem -Filter @{Name="^$VMHost$"} -Property Name,Parent -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	$vmrSpec.host = $hostview.MoRef
    $pool = (Get-View $hostview.Parent -Property Name,ResourcePool -ErrorAction SilentlyContinue -WarningAction SilentlyContinue).ResourcePool
    $vmrSpec.pool = $pool
  } else {
    Write-Verbose "New-VM-SDK: Ошибка :`r`nНе указан хост или кластер!"
    Write-Error "Ошибка:`r`nНе указан хост или кластер!" -TargetObject $Name
    return $null
  }

  #Спецификации для клонирования
  $exec_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$exec_date	New-VM-SDK	Спецификации для клонирования"
  $vmcSpec = New-Object VMware.Vim.VirtualMachineCloneSpec
  if ($custSpec) {
    $vmcSpec.Customization = New-Object VMware.Vim.CustomizationSpec
    $vmcSpec.Customization = $custSpec.Spec
  }
			
  #Не включать ВМ после деплоя
  $vmcSpec.powerOn = $false
			
  #Целевая ВМ не будет шаблоном
  $vmcSpec.template = $false

  #Получения каталога для ВМ
  $exec_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$exec_date	New-VM-SDK	Получения каталога для ВМ"
  if ($Location) {
    if ($Location.ID) {
      $target = $Location
    } else {
      $target = Get-Folder $Location -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    }
    $targetview = get-view $target.ID
  } else {
    Write-Verbose "New-VM-SDK: Ошибка :`r`nНе указан каталог для деплоя!"
    Write-Error "Ошибка:`r`nНе указан каталог для деплоя!" -TargetObject $Name
    return $null
  }
			
  #Поулчение шаблона
  $exec_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$exec_date	New-VM-SDK	Поулчение шаблона"
  if ($Template) {
    $vmmor = Get-View2 -ViewType Template -Name $Template -Property Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    $vmmorview = get-view $vmmor.MoRef
  } else {
    Write-Verbose "New-VM-SDK: Ошибка :`r`nНе указан шаблон для деплоя!"
    Write-Error "Ошибка:`r`nНе указан шаблон для деплоя!" -TargetObject $Name
    return $null
  }

  #Спецификация датастора
  $vmcSpec.location = $vmrSpec
			
  #Задача деплоя
  if ($storcluster -eq $true) {
    $podSpec = New-Object VMware.Vim.StorageDrsPodSelectionSpec
    $podSpec.StoragePod = $LUNview.moref
    $cloneSpec = $vmcSpec
    $storageSpec = New-Object VMware.Vim.StoragePlacementSpec
      $storageSpec.Type = "clone"
      $storageSpec.CloneName = $Name
      $storageSpec.Folder = $targetview.MoRef
      $storageSpec.PodSelectionSpec = $podSpec
      $storageSpec.Vm = $vmmorview.MoRef
      $storageSpec.CloneSpec = $cloneSpec
    $stormgr = get-view StorageResourceManager
    try {
      $result = $stormgr.RecommendDatastores($storageSpec)
    }
    catch {
      Write-Verbose "New-VM-SDK: Ошибка создания DRS рекомендации:`r`n$_"
      Write-Error "Ошибка создания DRS рекомендации:`r`n$_" -TargetObject $Name
      return $null
    }
    $key = $result.Recommendations[0].key
    try {
      $task = $stormgr.ApplyStorageDrsRecommendation_Task($key)
    }
    catch {
      Write-Verbose "New-VM-SDK: Ошибка создания ВМ:`r`n$_"
      Write-Error "Ошибка создания DRS рекомендации:`r`n$_" -TargetObject $Name
      return $null
    }
  } else {
    try {
      $task = $vmmorview.CloneVM_Task($targetview.MoRef,$Name, $vmcSpec )
    }
    catch {
      Write-Verbose "New-VM-SDK: Ошибка создания ВМ:`r`n$_"
      Write-Error "Ошибка создания ВМ:`r`n$_" -TargetObject $Name
      return $null
    }
  }
  $task = Get-task -Id "Task-$($task.Value)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

  if ($RunAsync.IsPresent) {
    $finish_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
    Write-Verbose "$finish_date	New-VM-SDK	Finished execution"
    return $task
  } else {
    while ($task.ExtensionData.Info.State -eq "Running")  {
      sleep 1
      $task.ExtensionData.UpdateViewData('Info.State')
    }

    $task.ExtensionData.UpdateViewData('Info')

    $finish_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
    Write-Verbose "$finish_date	New-VM-SDK	Finished execution"

    if ($task.ExtensionData.Info.State -eq "success") {
      return $task.ExtensionData.Info
    } else {
      Write-Verbose "New-VM-SDK: $($task.ExtensionData.Info.Error.LocalizedMessage)"
      Write-Error "$($task.ExtensionData.Info.Error.LocalizedMessage)" -TargetObject $Name
      return $task.ExtensionData.Info
    }
  }
}

Function Global:New-HardDisk-SDK {
  <#
    .Synopsis
       This function creates a new hard disk on the specified location.
    .DESCRIPTION
       This function creates a new hard disk on the specified virtual machine (and datastore).
    .EXAMPLE
       $vm = Get-View -ViewType VirtualMachine -Filter @{Name="^VM001$"}

       $task = $vm | New-HardDisk-SDK -CapacityGB 10
    .EXAMPLE
       $vm = Get-View -ViewType VirtualMachine -Filter @{Name="^VM001$"}

       $task = $vm | New-HardDisk-SDK -CapacityGB 10 -Controller "SCSI controller 0" -Datastore "DS-CLUSTER-001" -ThinProvisioned
    .EXAMPLE
       $vm = Get-View -ViewType VirtualMachine -Filter @{Name="^VM001$"}

       $task = $vm | New-HardDisk-SDK -CapacityGB 10 -Controller "SATA controller 0" -Datastore "DS-001"
    .PARAMETER CapacityGB
      Specifies the capacity of the new virtual disk in gigabytes (GB).
    .PARAMETER Datastore
      Specifies the datastore where you want to place the new hard disk. If a DatastoreCluster object is passed to the Datastore parameter, the hard disk is added to the DatastoreCluster in an automated SDRS mode.
    .PARAMETER Controller
      Specifies a SCSI or SATA controller to which you want to attach the new hard disk.
      By default SATA controller would be used if it's exist on virtual machine.
    .PARAMETER VM
      Specifies the virtual machines to which you want to add the new disk.
    .PARAMETER ThinProvisioned
      Indicates to the underlying file system, that the virtual disk backing file should be allocated lazily (using thin provisioning).
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function creates a new hard disk on the specified location.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(Mandatory = $true)][int]$CapacityGB,
    [string]$Datastore,
    [string]$Controller, #Имя контроллера
    [Parameter(Mandatory = $true, ValueFromPipeline=$True, Position = 0)][VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM,
    [switch]$ThinProvisioned
  )

  $start_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$start_date	New-HardDisk-SDK	Started execution"

  $entity_view = Get-View $VM
  $vm_devices = $entity_view.Config.Hardware.Device

  # Выбираем имя vmdk-файла диска
  $maxlen = 0
  ForEach ($vm_device in $vm_devices) {
    if ($vm_device.GetType().Name -eq "VirtualDisk") {
      if ($vm_device.Backing.FileName.Length -ge $maxlen) {
        $maxlen = $vm_device.Backing.FileName.Length
        $vm_disk_filename_cur = $vm_device.Backing.FileName
        if (!($vm_disk_filename_cur -replace "^(\[.*\]\s+.*\/.*)\.vmdk$")) {
          $vm_disk_filename = $vm_disk_filename_cur -replace "\.vmdk$"
          [int]$vm_disk_filename_increment = 0
        }
        if (!($vm_disk_filename_cur -replace "^(.*)_([0-9]+)\.vmdk$")) {
          $vm_disk_filename = $vm_disk_filename_cur -replace "_([0-9]+)\.vmdk$"
          [int]$vm_disk_filename_increment = $vm_disk_filename_cur -replace "^(.*)_" -replace "\.vmdk$"
        }
      }
    }
  }
  $vm_disk_filename = $vm_disk_filename + "_$($vm_disk_filename_increment + 1).vmdk"

  # Выбираем первый подходящий контроллер
  ForEach ($vm_device in $vm_devices) {
    if ($Controller) {
      if ($vm_device.DeviceInfo.Label -match "^$($Controller).*") {
        $vm_controller = $vm_device
        break
      }
    } else {
      if (($vm_device.DeviceInfo.Label -match "^SCSI.*") -or ($vm_device.DeviceInfo.Label -match "^SATA.*")) {
        $vm_controller = $vm_device
        break
      }
    }
  }
  $controllerKey = $vm_controller.Key

  # bulding unit numbers array
  $unitNumbers = New-Object System.Collections.ArrayList
  0..15 | %{
    $unitNumbers.Add($_) | Out-Null
  }
  $unitNumbers.Remove($unitNumbers[7]) # Removing number 7 as it's reserved
  # removing already used unit numbers
  ForEach ($devicekey in $vm_controller.Device) {
    $vmdisk = $vm_devices | ?{ $_.Key -eq $devicekey }
    $unitNumbers.Remove($($unitNumbers | ?{ $_ -eq $vmdisk.UnitNumber }))
  }
  if ($unitNumbers.Count -gt 0) {
    $unitNumber = $unitNumbers[0]
  } else {
    Write-Verbose "New-HardDisk-SDK: Ошибка создания диска:`r`nНа одном контроллере может быть не более 15 дисков!"
    Write-Error "Ошибка создания диска:`r`nНа одном контроллере может быть не более 15 дисков!" -TargetObject $VM
    return $null
  }

  # Получем ID датастора, если он был указан
  if ($Datastore) {
    # Если переданный датастор не является кластером, то
    $LUN = get-datastore $datastore -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($LUN) {
      $LUNview = get-view $LUN.id -Property Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      $simpleaddition = $true
    } else { # если является кластером, то
      $LUN = Get-DatastoreCluster $datastore -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      $LUNview = get-view $LUN.id -Property Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
      $simpleaddition = $false
    }
    $vm_disk_filename = $vm_disk_filename -replace "\[.*\]","[$($LUN.Name)]"
  } else {
    $simpleaddition = $true
  }

  #новый вариант
  if ($simpleaddition -eq $true) {
    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (1)
    $spec.deviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $spec.deviceChange[0].operation = "add"
    $spec.deviceChange[0].fileOperation = "create"
    $spec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
    $spec.deviceChange[0].device.key = -100
    $spec.deviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
    if ($LUN) {
      $spec.deviceChange[0].device.backing.fileName = "[$($LUN.Name)]"
    } else {
      $spec.deviceChange[0].device.backing.fileName = $null
    }
    $spec.deviceChange[0].device.backing.diskMode = "persistent"
    if ($ThinProvisioned.IsPresent) {
      $spec.deviceChange[0].device.backing.ThinProvisioned = $true
      $spec.deviceChange[0].device.backing.eagerlyScrub = $false
    }
    $spec.deviceChange[0].device.connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
    $spec.deviceChange[0].device.connectable.startConnected = $true
    $spec.deviceChange[0].device.connectable.allowGuestControl = $false
    $spec.deviceChange[0].device.connectable.connected = $true
    $spec.deviceChange[0].device.controllerKey = $controllerKey
    $spec.deviceChange[0].device.unitNumber = $unitNumber
    $spec.deviceChange[0].device.capacityInKB = ($CapacityGB * 1024 * 1024)
    try {
      $task = $entity_view.ReconfigVM_Task($spec)
    }
    catch {
      Write-Verbose "New-HardDisk-SDK: Ошибка создания диска:`r`n$_"
      Write-Error "Ошибка создания диска:`r`n$_" -TargetObject $VM
      return $null
    }
  } else {
    $storageSpec = New-Object VMware.Vim.StoragePlacementSpec
    $storageSpec.type = "reconfigure"
    $storageSpec.vm = $entity_view.MoRef
    $storageSpec.podSelectionSpec = New-Object VMware.Vim.StorageDrsPodSelectionSpec
    $storageSpec.podSelectionSpec.initialVmConfig = New-Object VMware.Vim.VmPodConfigForPlacement[] (1)
    $storageSpec.podSelectionSpec.initialVmConfig[0] = New-Object VMware.Vim.VmPodConfigForPlacement
    $storageSpec.podSelectionSpec.initialVmConfig[0].storagePod = $LUNview.MoRef
    $storageSpec.podSelectionSpec.initialVmConfig[0].disk = New-Object VMware.Vim.PodDiskLocator[] (1)
    $storageSpec.podSelectionSpec.initialVmConfig[0].disk[0] = New-Object VMware.Vim.PodDiskLocator
    $storageSpec.podSelectionSpec.initialVmConfig[0].disk[0].diskId = -100
    $storageSpec.podSelectionSpec.initialVmConfig[0].disk[0].diskBackingInfo = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
    $storageSpec.podSelectionSpec.initialVmConfig[0].disk[0].diskBackingInfo.fileName = "[$($LUN.Name)]"
    $storageSpec.podSelectionSpec.initialVmConfig[0].disk[0].diskBackingInfo.diskMode = "persistent"
    $storageSpec.podSelectionSpec.initialVmConfig[0].disk[0].diskBackingInfo.split = $false
    if ($ThinProvisioned.IsPresent) {
      $storageSpec.podSelectionSpec.initialVmConfig[0].disk[0].diskBackingInfo.thinProvisioned = $true
    } else {
      $storageSpec.podSelectionSpec.initialVmConfig[0].disk[0].diskBackingInfo.thinProvisioned = $false
    }
    $storageSpec.podSelectionSpec.initialVmConfig[0].disk[0].diskBackingInfo.eagerlyScrub = $false
    $storageSpec.configSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $storageSpec.configSpec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (1)
    $storageSpec.configSpec.deviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $storageSpec.configSpec.deviceChange[0].operation = "add"
    $storageSpec.configSpec.deviceChange[0].fileOperation = "create"
    $storageSpec.configSpec.deviceChange[0].device = New-Object VMware.Vim.VirtualDisk
    $storageSpec.configSpec.deviceChange[0].device.key = -100
    $storageSpec.configSpec.deviceChange[0].device.backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
    $storageSpec.configSpec.deviceChange[0].device.backing.fileName = "[$($LUN.Name)]"
    $storageSpec.configSpec.deviceChange[0].device.backing.diskMode = "persistent"
    if ($ThinProvisioned.IsPresent) {
      $storageSpec.configSpec.deviceChange[0].device.backing.thinProvisioned = $true
    }
    $storageSpec.configSpec.deviceChange[0].device.connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
    $storageSpec.configSpec.deviceChange[0].device.connectable.startConnected = $true
    $storageSpec.configSpec.deviceChange[0].device.connectable.allowGuestControl = $false
    $storageSpec.configSpec.deviceChange[0].device.connectable.connected = $true
    $storageSpec.configSpec.deviceChange[0].device.controllerKey = $controllerKey
    $storageSpec.configSpec.deviceChange[0].device.unitNumber = $unitNumber
    $storageSpec.configSpec.deviceChange[0].device.capacityInKB = ($CapacityGB * 1024 * 1024)
    $stormgr = get-view StorageResourceManager
    try {
      $result = $stormgr.RecommendDatastores($storageSpec)
    }
    catch {
      Write-Verbose "New-HardDisk-SDK: Ошибка создания DRS рекомендации:`r`n$_"
      Write-Error "Ошибка создания DRS рекомендации:`r`n$_" -TargetObject $VM
      return $null
    }
    $key = $result.Recommendations[0].key
    try {
      $task = $stormgr.ApplyStorageDrsRecommendation_Task($key)
    }
    catch {
      Write-Verbose "New-HardDisk-SDK: Ошибка создания диска:`r`n$_"
      Write-Error "Ошибка создания диска:`r`n$_" -TargetObject $VM
      return $task.ExtensionData.Info
    }
  }
  $task = Get-task -Id "Task-$($task.Value)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
  while ($task.ExtensionData.Info.State -eq "Running")  {
    sleep 1
    $task.ExtensionData.UpdateViewData('Info.State')
  }
  $task.ExtensionData.UpdateViewData('Info')

  $finish_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$finish_date	New-HardDisk-SDK	Finished execution"

  if ($task.ExtensionData.Info.State -eq "success") {
    return $task.ExtensionData.Info
  } else {
    Write-Verbose "New-HardDisk-SDK: $($task.ExtensionData.Info.Error.LocalizedMessage)"
    Write-Error "$($task.ExtensionData.Info.Error.LocalizedMessage)" -TargetObject $VM
    return $null
  }
}

Function Global:Get-FolderPath {
  <#
    .Synopsis
       This function returns full path to specified Virtual Infrasctructure folder.
    .DESCRIPTION
       This function returns full path to specified Virtual Infrasctructure folder.
    .EXAMPLE
       $folder = Get-Folder "Some folder"

       $folderpath = Get-FolderPath -folder $folder.ExtensionData.MoRef
    .EXAMPLE
       $vm = Get-View -ViewType VirtualMachine -Filter @{Name="^VM001$"}

       $folderpath = Get-FolderPath -folder $vm.Parent
    .PARAMETER folder
      Managed object reference ID of some folder.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function returns full path to specified Virtual Infrasctructure folder.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(Mandatory = $true)][VMware.Vim.ManagedObjectReference]$folder
  )
  $fullpath = ""
  $curfolder = Get-View $folder
  if ($curfolder.Name -ne "vm") {
    $fullpath = "\$($curfolder.Name)"
    $fullpath = "$(Get-FolderPath -folder $curfolder.Parent)" + "$fullpath"
  }
  return $fullpath
}

Function Global:Set-VM-SDK {
  <#
    .Synopsis
       This function modifies the configuration of the virtual machine.
    .DESCRIPTION
       This function modifies the configuration of the virtual machine. Main feature of this function - is ability to set amount of Cores Per Socket which is not available in Set-VM cmdlet.
    .EXAMPLE
       $VM = Get-View -ViewType VirtualMachine -Filter @{"Config.Template"="False";Name="^VM001$"}

       $task = $vm | Set-VM-SDK -NumCpu 8 -CoresPerSocket 2 -MemoryGB 12
    .PARAMETER VM
       Specifies the virtual machine you want to configure.
    .PARAMETER NumCpu
       Specifies the number of virtual CPUs.
    .PARAMETER CoresPerSocket
       Specifies the number of cores per socket.
    .PARAMETER MemoryGB
       Specifies the memory size in gigabytes (GB).
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function modifies the configuration of the virtual machine.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [PSObject]$VM,
    [int]$NumCpu,
    [int]$CoresPerSocket,
    [int]$MemoryGB
  )
  $start_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$start_date	Set-VM-SDK	Started execution"

  if ($VM.MoRef) {
    $view = Get-View $VM.MoRef
  } else {
    $view = Get-View $VM
  }

  $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
  if ($NumCpu) {
    $spec.numCPUs = $NumCpu
  }
  if ($CoresPerSocket) {
    $spec.NumCoresPerSocket = $CoresPerSocket
  }
  if ($MemoryGB) {
    $spec.memoryMB = ($MemoryGB * 1024)
  }
  try {
    $task = $view.ReconfigVM_Task($spec)
  }
  catch{
    Write-Verbose "Set-VM-SDK: Ошибка:`r`n$_"
    Write-Error "$_" -TargetObject $VM.Name
    $finish_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
    Write-Verbose "$finish_date	Set-VM-SDK	Finished execution"
    return $null
  }
  $task = Get-task -Id "Task-$($task.Value)" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
  while ($task.ExtensionData.Info.State -eq "Running")  {
    sleep 1
    $task.ExtensionData.UpdateViewData('Info.State')
  }
  $task.ExtensionData.UpdateViewData('Info')

  $finish_date = Get-Date -Format "dd.MM.yyyy HH.mm.ss"
  Write-Verbose "$finish_date	Set-VM-SDK	Finished execution"

  if ($task.ExtensionData.Info.State -eq "success") {
    return $task.ExtensionData.Info
  } else {
    Write-Verbose "Set-VM-SDK: $($task.ExtensionData.Info.Error.LocalizedMessage)"
    Write-Error "$($task.ExtensionData.Info.Error.LocalizedMessage)" -TargetObject $VM.Name
    return $task.ExtensionData.Info
  }
}

Function Global:Get-VMEvents {
  <#
    .Synopsis
       This function retrieves information about the events of VM on a vCenter Server system.
    .DESCRIPTION
       This function retrieves information about the events of VM on a vCenter Server system. An event is any action in the vCenter Server system or ESX/ESXi host.
    .EXAMPLE
       $VM = Get-View -ViewType VirtualMachine -Filter @{"Config.Template"="False";Name="^VM001$"}

       Get-VMEvents -vmname $VM.Name
    .EXAMPLE
       $VM = Get-View -ViewType VirtualMachine -Filter @{"Config.Template"="False";Name="^VM001$"}

       Get-VMEvents -Id $VM.MoRef
    .PARAMETER vmname
       Specifies the name of virtual machine for which you want to get events.
    .PARAMETER Id
       Specifies the managed object reference id of virtual machine for which you want to get events.
    .PARAMETER types
       Specifies event types you want to get.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function retrieves information about the events of VM on a vCenter Server system.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [parameter(ParameterSetName = "Name", Mandatory = $true)][string]$vmname,
    [parameter(ParameterSetName = "Id", Mandatory = $true)][PSObject]$Id,
    [String[]]$types
  )

  $si = Get-View serviceinstance
  $em = Get-View $si.Content.EventManager
  $EventFilterSpec = New-Object VMware.Vim.EventFilterSpec
  $EventFilterSpec.EventTypeId = $types
  if ($vmname) {
    $vmentity = get-view -ViewType virtualmachine -Filter @{'name'="^$vmname$"}
  } else {
    $vmentity = get-view $Id
  }
  $EventFilterSpec.Entity = New-Object VMware.Vim.EventFilterSpecByEntity
  $EventFilterSpec.Entity.Entity = $vmentity.moref

  return $em.QueryEvents($EventFilterSpec)
}

Function Global:Clone-OSCustomizationSpec-SDK {
  <#
    .Synopsis
       This functions clones existing OS customization specification to new non persistent one.
    .DESCRIPTION
       This functions clones existing OS customization specification to new non persistent one.
    .EXAMPLE
       $NonPersCust = Clone-OSCustomizationSpec-SDK -Name "NewCustomization" -OSCustomizationSpec "Windows2012"
    .PARAMETER Name
       Specifies a name for the new specification.
    .PARAMETER OSCustomizationSpec
       Specifies an OS customization specification that you want to clone.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This functions clones existing OS customization specification to new non persistent one.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [string]$Name,
    [parameter(Mandatory = $true)][string]$OSCustomizationSpec
  )
  $objCustSpec = (Get-View CustomizationSpecmanager).GetCustomizationSpec($OSCustomizationSpec)
  if ($Name) {
    $objCustSpec.Info.Name = $Name
  }
  return $objCustSpec
}

Function Global:Set-OSCustomizationNicMapping-SDK {
  <#
    .Synopsis
       This function modifies the provided OS customization NIC mappings.
    .DESCRIPTION
       This function modifies the provided OS customization NIC mappings.
    .EXAMPLE
       $NonPersCust = $NonPersCust | Set-OSCustomizationNicMapping-SDK -IpMode UseDhcp
    .EXAMPLE
       $NonPersCust = $NonPersCust | Set-OSCustomizationNicMapping-SDK -IpMode UseStaticIP -IpAddress 10.10.10.100 -SubnetMask 255.255.255.0 -DefaultGateway 10.10.10.10
    .PARAMETER OSCustomizationSpec
       Specifies an OS customization specification that you want to change.
    .PARAMETER IpMode
       Specifies the IP configuration mode. The valid values are UseDhcp and UseStaticIP.
    .PARAMETER IpAddress
       Specifies an IP address.
    .PARAMETER SubnetMask
       Specifies a subnet mask.
    .PARAMETER DefaultGateway
       Specifies a default gateway.
    .PARAMETER Dns
       Specifies a DNS address.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function modifies the provided OS customization NIC mappings.
    .OUTPUTS
       [CustomizationSpecItem]
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline=$True, Position = 0)]
    [VMware.Vim.CustomizationSpecItem]$OSCustomizationSpec,
    [ValidateSet("UseDhcp","UseStaticIP")]
    [string]$IpMode="UseDhcp",
    [parameter(ParameterSetName = "StaticIP")]
    [ValidatePattern("\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")]
    [string]$IpAddress,
    [parameter(ParameterSetName = "StaticIP")]
    [ValidatePattern("\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")]
    [string]$SubnetMask,
    [parameter(ParameterSetName = "StaticIP")]
    [ValidatePattern("\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")]
    [string]$DefaultGateway,
    [string[]]$Dns
  )
  
  #Создание объекта CUSTOMIZATIONADAPTERMAPPING
  $OSCustomizationSpec.Spec.NicSettingMap = @(New-Object VMware.Vim.CustomizationAdapterMapping)

  #Создание объекта CUSTOMIZATIONIPSETTINGS
  $OSCustomizationSpec.Spec.NicSettingMap[0].Adapter = New-Object VMware.Vim.CustomizationIPSettings

  if ($IpMode -eq "UseStaticIP") {
    #Создание объекта CUSTOMIZATIONFIXEDIP
    $OSCustomizationSpec.Spec.NicSettingMap[0].Adapter.Ip = New-Object VMware.Vim.CustomizationFixedIp

    #Спецификация сети
    if ($IpAddress) {
      $OSCustomizationSpec.Spec.NicSettingMap.Adapter[0].Ip.IpAddress = $IpAddress
    }
    if ($SubnetMask) {
      $OSCustomizationSpec.Spec.NicSettingMap.Adapter[0].SubnetMask = $SubnetMask
    }
    if ($Dns) {
      $OSCustomizationSpec.Spec.NicSettingMap.Adapter[0].DnsServerList = $Dns
    }
    if ($DefaultGateway) {
      $OSCustomizationSpec.Spec.NicSettingMap.Adapter[0].Gateway = $DefaultGateway
    }
  } elseif ($IpMode -eq "UseDhcp") {
    #Создание объекта CustomizationDhcpIpGenerator
    $OSCustomizationSpec.Spec.NicSettingMap[0].Adapter.Ip = New-Object VMware.Vim.CustomizationDhcpIpGenerator
  }

  return $OSCustomizationSpec
}

Function Global:Set-OSCustomizationSpec-SDK {
  <#
    .Synopsis
       This function modifies the specified OS customization specification.
    .DESCRIPTION
       This function modifies the specified OS customization specification.
    .EXAMPLE
       $NonPersCust = $NonPersCust | Set-OSCustomizationSpec-SDK -Domain "alpha.beta.ru" -DomainCredentials $creds
    .EXAMPLE
       $NonPersCust = $NonPersCust | Set-OSCustomizationSpec-SDK -Workgroup "WORKGROUP"
    .EXAMPLE
       $NonPersCust = $NonPersCust | Set-OSCustomizationSpec-SDK  -AutoLogonCount 3 -GuiRunOnce $GuiRunOnce
    .PARAMETER OSCustomizationSpec
       Specifies the specification you want to modify.
    .PARAMETER Domain
       Specifies the domain name.
    .PARAMETER DomainCredentials
       Specifies credentials for authentication with the specified domain. This parameter applies only to Windows operating systems.
    .PARAMETER Workgroup
       Specifies the workgroup. This parameter applies only to Windows operating systems.
    .PARAMETER AutoLogonCount
       Specifies the number of times the virtual machine should automatically login as an administrator. The valid values are in the range between 0 and Int32.MaxValue. Specifying 0 disables auto log-on. This parameter applies only to Windows operating systems.
    .PARAMETER GuiRunOnce
       Provides a list of commands to run after first user login. This parameter applies only to Windows operating systems.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function modifies the specified OS customization specification.
    .OUTPUTS
       [CustomizationSpecItem]
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline=$True, Position = 0)]
    [VMware.Vim.CustomizationSpecItem]$OSCustomizationSpec,
    [parameter(ParameterSetName = "Domain")]
    [string]$Domain,
    [parameter(ParameterSetName = "Domain")]
    [PSCredential]$DomainCredentials,
    [parameter(ParameterSetName = "Workgroup")]
    [string]$Workgroup,
    [parameter(ParameterSetName = "GuiUnattended")]
    [int]$AutoLogonCount,
    [parameter(ParameterSetName = "GuiUnattended")]
    [string[]]$GuiRunOnce
  )
  if ($Domain) {
    $OSCustomizationSpec.Spec.Identity.Identification = New-Object VMware.Vim.CustomizationIdentification
    $OSCustomizationSpec.Spec.Identity.Identification.JoinDomain = $Domain
    if ($DomainCredentials) {
      $OSCustomizationSpec.Spec.Identity.Identification.DomainAdmin = $DomainCredentials.UserName
      $OSCustomizationSpec.Spec.Identity.Identification.DomainAdminPassword = New-Object VMware.Vim.CustomizationPassword
      $OSCustomizationSpec.Spec.Identity.Identification.DomainAdminPassword.Value = $(($DomainCredentials).GetNetworkCredential().password)
      $OSCustomizationSpec.Spec.Identity.Identification.DomainAdminPassword.PlainText = $true
    }
  }
  if ($Workgroup) {
    $OSCustomizationSpec.Spec.Identity.Identification = New-Object VMware.Vim.CustomizationIdentification
    $OSCustomizationSpec.Spec.Identity.Identification.JoinWorkgroup = $Workgroup
  }
  if ($AutoLogonCount -and ($AutoLogonCount -ne 0)) {
    $OSCustomizationSpec.Spec.Identity.GuiUnattended.AutoLogon = $true
    $OSCustomizationSpec.Spec.Identity.GuiUnattended.AutoLogonCount = $AutoLogonCount
  } elseif ($AutoLogonCount -eq 0) {
    $OSCustomizationSpec.Spec.Identity.GuiUnattended.AutoLogonCount = $AutoLogonCount
    $OSCustomizationSpec.Spec.Identity.GuiUnattended.AutoLogon = $false
  }
  if ($GuiRunOnce) {
    $OSCustomizationSpec.Spec.Identity.GuiRunOnce = New-Object VMware.Vim.CustomizationGuiRunOnce
    $OSCustomizationSpec.Spec.Identity.GuiRunOnce.CommandList = $GuiRunOnce
  }

  return $OSCustomizationSpec
}

Function Global:AddTag {
  <#
    .Synopsis
       This function adds tag to VM in existing catgory.
    .DESCRIPTION
       This function adds tag to VM in existing catgory. If tag already exists then it'd add it, if tag doesn't exist yet tyhen it'd create and add it.
    .EXAMPLE
       $vm = Get-View -ViewType VirtualMachine -Filter @{Name="^VM001$"}

       $vm | AddTag -Category "Change" -Tag "C00342104" -description "КЭ ЛС"
    .PARAMETER Category
      Specifies category name.
    .PARAMETER Tag
      Specifies tag name.
    .PARAMETER VM
      Specifies the virtual machine to which you want to add the tag.
    .PARAMETER description
      Specifies description of tag.
    .NOTES
       Author:  Andrey Nevedomskiy
    .FUNCTIONALITY
       This function adds tag to VM in existing catgory.
    .LINK
       https://github.com/monosoul/powercli_functions.ps1
  #>
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline=$True, Position = 0)]
    [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VirtualMachineImpl]$VM,
    [Parameter(Mandatory = $true)]
    [string]$Category,
    [Parameter(Mandatory = $true)]
    [string]$Tag,
    [Parameter(Mandatory = $false)]
    [string]$description = ""
  )

  $tagObj = Get-Tag $Tag -Category $Category -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
  if (!($tagObj)) {
    $tagObj = New-Tag -Name $Tag -Category $Category -ErrorAction Continue -WarningAction Continue
  }
  $out = $VM | New-TagAssignment -Tag $tagObj
  if ($out) {
    Write-Verbose "Добавлен тег $description`: $($tagObj.Name)"
    Remove-Variable -Name out -Force -Confirm:$false
  } else {
    Write-Verbose "Ошибка добавления тега $description`: $($tagObj.Name)"
    Write-Error "Ошибка добавления тега $description`: $($tagObj.Name)" -TargetObject $VM
  }
}