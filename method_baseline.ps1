[cmdletbinding()] 
param([switch]$baseline, [switch]$persistence, [switch]$hash, [switch]$help)
if($baseline) 
{

Write-Host "Creating your results folder" -ForegroundColor Green -BackgroundColor Black

$path = "$home\desktop\baseline_$env:COMPUTERNAME"

#Create the folders that will store the data
New-Item -ItemType directory -Path $path | Out-Null
New-Item -ItemType directory -Path $path\network_info | Out-Null
New-Item -ItemType directory -Path $path\host_system_info | Out-Null 

#create a timestamp that will record when the script was ran
get-date | Out-File $path\timestamp.txt 

Write-Host "Collecting Process information" -ForegroundColor Green -BackgroundColor Black
Get-Process | Sort-Object -Descending WS | Out-File $path\host_system_info\tasklist_desceding.txt
Get-WmiObject win32_process | Select name, processid, executablepath, commandline | Out-File $path\host_system_info\tasklist_detailed.txt

#Collect information on the operating system
Write-Host "Collecting OS and NIC information" -ForegroundColor Green -BackgroundColor Black
Get-WmiObject win32_operatingsystem | Format-List * | Out-File $path\host_system_info\os_info_detailed.txt
Get-WmiObject win32_operatingsystem | Select-Object -property csname, osarchitecture, name, freephysicalmemory, freespaceinpagingfiles, freevirtualmemory, serialnumber | Out-File $path\host_system_info\architecture.txt

#print out network adapter info
Get-WmiObject win32_networkadapter | select netconnectionid, name, interfaceindex, netconnectionstatus | Format-Table | Out-File $path\network_info\netadapters.txt
ipconfig /all | Out-File $path\network_info\ipconfig.txt

#collect information on the current time and timezone
Write-Host "Collecting locattime information" -ForegroundColor Green -BackgroundColor Black
Get-WmiObject win32_localtime | Select-Object month,day,year,hour,minute,second | Out-File $path\host_system_info\time.txt
[system.timezone]::currenttimezone | Out-File $path\host_system_info\timezone.txt

#Collect information on network shares
Write-Host "Collecting Network Shares Information" -ForegroundColor Green -BackgroundColor Black
Get-WmiObject -Class Win32_Share | Out-File $path\network_info\network_shares.txt

Write-Host "Collecting Services Information" -ForegroundColor Green -BackgroundColor Black
Get-WmiObject win32_service | select Name, DisplayName, State | Out-File $path\host_system_info\services.txt
Get-WmiObject win32_service | select name, path | Out-File $path\host_system_info\services_path.txt

#collect information on reg keys of interest
Write-Host "Conducting Reg Queries" -ForegroundColor Green -BackgroundColor Black
Get-ItemProperty HKLM:\Software | Out-File $path\host_system_info\hklm_software_reg.txt
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Run | Out-File $path\host_system_info\hklm_run_reg.txt
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Runonce | Out-File $path\host_system_info\hklm_runonce_reg.txt
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run | Out-File $path\host_system_info\hkcu_run_reg.txt
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce | Out-File $path\host_system_info\hkcu_runonce_reg.txt
#this will tell you the internet explorer version being ran
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Internet Explorer' | Out-File $path\host_system_info\IE_Info.txt
#can tell you some IE defaults (search page, default page)
Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Internet Explorer\MAIN' | out-file $path\host_system_info\IE_defaults.txt
Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Internet Explorer\Typedurls' -ErrorAction silentlycontinue | Out-File $path\host_system_info\type_urls.txt

Write-Host "Conduncting scan of scheduled tasks" -ForegroundColor Green -BackgroundColor Black
function getTasks($path) 
{
    $out = @()
    # Get root tasks
    $schedule.GetFolder($path).GetTasks(0) | % {
        $xml = [xml]$_.xml
        $out += New-Object psobject -Property @{
            "Name" = $_.Name
            "Path" = $_.Path
            "LastRunTime" = $_.LastRunTime
            "NextRunTime" = $_.NextRunTime
            "Actions" = ($xml.Task.Actions.Exec | % { "$($_.Command) $($_.Arguments)" }) -join "`n"
        }
    }
    # Get tasks from subfolders
    $schedule.GetFolder($path).GetFolders(0) | % {
        $out += getTasks($_.Path)
    }
    #Output
    $out
}
$tasks = @()
$schedule = New-Object -ComObject "Schedule.Service"
$schedule.Connect() 
# Start inventory
$tasks += getTasks("\")
# Close com
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($schedule) | Out-Null
Remove-Variable schedule
# Output all tasks
$tasks | Out-File $path\host_system_info\scheduled_tasks.txt


#get local user accounts
Write-Host "Conduncting local user scan" -ForegroundColor Green -BackgroundColor Black
Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'" |
  Select PSComputername, Name, Status, Disabled, AccountType, Lockout, PasswordRequired, PasswordChangeable, SID | Out-File $path\host_system_info\local_users.txt
}

elseif($persistence) 
{

Write-Host "Creating the results folder" -ForegroundColor Green -BackgroundColor blac

$path = "$home\desktop\Persistence_$env:COMPUTERNAME"

#Creating the rest of the folders
New-Item -ItemType directory -Path $path | Out-Null
New-Item -ItemType directory -Path $path\persistence | Out-Null
New-Item -ItemType directory -Path $path\persistence\services | Out-Null
New-Item -ItemType directory -Path $path\persistence\run | Out-Null
New-Item -ItemType directory -Path $path\persistence\wmi | Out-Null

#Create a timestamp
get-date | out-file $path\timestamp.txt

#check for modifications of accessibility features (i.e. sticky keys)
Write-Host "Checking your accessibility features" -ForegroundColor Green -BackgroundColor Black
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' | Out-File $path\persistence\image_file_execution.txt
Get-ItemProperty C:\Windows\System32\sethc.exe | Format-List * | Out-File $path\persistence\sethc_info.txt
Get-FileHash C:\Windows\System32\sethc.exe -Algorithm MD5 -ErrorAction SilentlyContinue | Out-File $path\persistence\sethc_info.txt -Append

#check for modified or new services
Write-Host "Collecting information on your services" -ForegroundColor Green -BackgroundColor Black
Get-WmiObject win32_service | select -Property displayname, state, pathname | Out-File $path\persistence\services\service_list.txt
Get-WmiObject win32_service | where-object {$_.state -eq "Running"} | select -Property displayname, processid, state, pathname | Out-File $path\persistence\services\running.txt

#looks for services that were installed
Get-EventLog Security -InstanceId 4697 -ErrorAction silentlycontinue | Out-File $path\persistence\services\new_service_eventlog.txt

#check for run and runonce keys
Write-Host "Collecting information on your run and runonce keys" -ForegroundColor Green -BackgroundColor Black
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Run | Out-File $path\persistence\run\hklm_run_reg.txt
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Runonce | Out-File $path\persistence\run\hklm_runonce_reg.txt
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Run | Out-File $path\persistence\run\hkcu_run_reg.txt
Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce | Out-File $path\persistence\run\hkcu_runonce_reg.txt

#Write-Host "Collecting information on your startup folders" -ForegroundColor green

#Get-ChildItem 'C:\users\<user>\appdata\roaming\microsoft\windows\start menu\programs\startup' -ErrorAction silentlycontinue

#check for wmi event subscriptions
Write-Host "Collecting information on WMI" -ForegroundColor Green -BackgroundColor Black
Get-WmiObject -Namespace root\Subscription -Class __FiltertoConsumerBinding | Out-File $path\persistence\wmi\filter_to_consumer_binding.txt

}
elseif($hash)
{
Write-Host "Hashing C:\windows" -ForegroundColor Green -BackgroundColor Black
Get-ChildItem C:\Windows | Get-FileHash -Algorithm MD5 | Out-File $home\desktop\windows_hash.txt

Write-Host "Hashing C:\Windows\System32 -recurse" -ForegroundColor Green -BackgroundColor Black
Get-ChildItem C:\Windows\System32 -Recurse | Get-FileHash -Algorithm MD5 | Out-File $home\desktop\system32_hash.txt
}

elseif($help)
{ 
Write-Host "
  ___       _                 _     
 / _ \     | |               (_)    
/ /_\ \_ __| |_ ___ _ __ ___  _ ___ 
|  _  | '__| __/ _ \ '_ ` _ \ | / __| 
| | | | |  | ||  __/ | | | | | \__ \
\_| |_/_|   \__\___|_| |_| |_|_|___/
                                    
                                   
 " -ForegroundColor Green
Write-Host " -baseline `t`t Conduct a baseline scan of the host machine. Results stored on user's desktop." -ForegroundColor Green -BackgroundColor Black
Write-Host " -persistence `t Conduct a scan that scans common areas where persistence is found. Results stored on the Desktop."  -ForegroundColor Green -BackgroundColor Black
Write-Host " -hash `t`t`t Conduct a hash of files located in C:\windows and C:\windows\system32 -recurse" -ForegroundColor Green -BackgroundColor Black
}
else 
{
Write-Host "Use -help for switch options." -ForegroundColor Red -BackgroundColor Black
}




 