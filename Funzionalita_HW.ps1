<# TO DO:
- check error handling
- redirect gp90 folder location
- open gp90 folder
 #>


#This will self elevate the script so with a UAC prompt since this script needs to be run as an Administrator in order to function properly.

#$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal( [Security.Principal.WindowsIdentity]::GetCurrent() )

if (-not $currentPrincipal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )) {
 (get-host).UI.RawUI.Backgroundcolor = "DarkRed"
    clear-host
    write-host "Warning: PowerShell is not running as an Administrator.`n"
    start-sleep 2
}


# Define the WinApiHelper class using Add-Type with here-string
Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;

namespace net.same2u.WinApiHelper {
    public static class IniFile {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        // Note the need to use `[Out] byte[]` instead of `System.Text.StringBuilder` in order to support strings with embedded NUL chars.
        public static extern uint GetPrivateProfileString(string lpAppName, string lpKeyName, string lpDefault, [Out] byte[] lpBuffer, uint nSize, string lpFileName);
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
        public static extern bool WritePrivateProfileString(string lpAppName, string lpKeyName, string lpString, string lpFileName);
    }
}
"@
Clear-Host

Function Get-IniValue {
    <#
    .SYNOPSIS
    Gets a given entry's value from an INI file, as a string.
    Optionally *enumerates* elements of the file:
    * section names (if -Section is omitted)
    * entry keys in a given section (if -Key is omitted)
    can be returned.
    .EXAMPLE
    Get-IniValue file.ini section1 key1
    Returns the value of key key1 from section section1 in file file.ini.
    Get-IniValue file.ini section1 key1 defaultVal1
    Returns the value of key key1 from section section1 in file file.ini
    and returns 'defaultVal1' if no such key exists.
    .EXAMPLE
    Get-IniValue file.ini section1
    Returns the names of all keys in section section1 in file file.ini.
    .EXAMPLE
    Get-IniValue file.ini
    Returns the names of all sections in file file.ini.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $LiteralPath,
        [string] $Section,
        [string] $Key,
        [string] $DefaultValue
    )
    # Make sure that bona fide `null` is passed for omitted parameters, as only true `null`
    # values are recognized as requests to enumerate section names / key names in a section.
    $enumerate = $false
    if (-not $PSBoundParameters.ContainsKey('Section')) { $Section = [NullString]::Value; $enumerate = $true }
    if (-not $PSBoundParameters.ContainsKey('Key')) { $Key = [NullString]::Value; $enumerate = $true }

    # Convert the path to an *absolute* one, since .NET's and the WinAPI's
    # current dir. is usually differs from PowerShell's.
    $fullPath = Convert-Path -ErrorAction Stop -LiteralPath $LiteralPath
    $bufferCharCount = 0
    $bufferChunkSize = 1024 # start with reasonably large default value.

    do {
        $bufferCharCount += $bufferChunkSize
        # Note: We MUST use raw byte buffers, because [System.Text.StringBuilder] doesn't support
        #       returning values with embedded NULs - see https://stackoverflow.com/a/15274893/45375
        $buffer = New-Object byte[] ($bufferCharCount * 2)
        # Note: The return value is the number of bytes copied excluding the trailing NUL / double NUL
        #       It is only ever 0 if the buffer char. count is pointlessly small (1 with single NUL, 2 with double NUL)
        $copiedCharCount = [net.same2u.WinApiHelper.IniFile]::GetPrivateProfileString($Section, $Key, $DefaultValue, $buffer, $bufferCharCount, $fullPath)
    } while ($copiedCharCount -ne 0 -and $copiedCharCount -eq $bufferCharCount - (1, 2)[$enumerate]) # Check to see if the full value was retrieved or whether the buffer was too small.

    # Convert the byte buffer contents back to a string.
    if ($copiedCharCount -eq 0) {
        # Nothing was copied (non-existent section or entry or empty value) - return the empty string.
        ''
    }
    else {
        # If entries are being enumerated (if -Section or -Key were omitted),
        # the resulting string must be split by embedded NUL chars. to return the enumerated values as an *array*
        # If a specific value is being retrieved, this splitting is an effective no-op.
        [Text.Encoding]::Unicode.GetString($buffer, 0, ($copiedCharCount - (0, 1)[$enumerate]) * 2) -split "`0"
    }
}
Function Set-IniValue {
    <#
        .SYNOPSIS
        Updates a given entry's value in an INI file.
        Optionally *deletes* from the file:
        * an entry (if -Value is omitted)
        * a entire section (if -Key is omitted)
        If the target file doesn't exist yet, it is created on demand,
        with UTF-16LE enoding (the target file's diretory must already exist).
        A preexisting file that doesn't have a UTF-16LE BOM is invariably
        treated as ANSI-encoded.
        .EXAMPLE
        Set-IniValue file.ini section1 key1 value1
        Updates the value of the entry whose key is key1 in section section1 in file
        file.ini.
        .EXAMPLE
        Set-IniValue file.ini section1 key1
        Deletes the entry whose key is key1 from section section1 in file file.ini.
        .EXAMPLE
        Set-IniValue file.ini section1
        Deletes the entire section section1 from file file.ini.
        #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $LiteralPath,
        [Parameter(Mandatory)] [string] $Section,
        [string] $Key,
        [string] $Value
    )
    # Make sure that bona fide `null` is passed for omitted parameters, as only true `null`
    # values are recognized as requests to *delete* entries.
    if (-not $PSBoundParameters.ContainsKey('Key')) { $Key = [NullString]::Value }
    if (-not $PSBoundParameters.ContainsKey('Value')) { $Value = [NullString]::Value }

    # Convert the path to an *absolute* one, since .NET's and the WinAPI's
    # current dir. is usually differs from PowerShell's.
    $fullPath =
    try {
        Convert-Path -ErrorAction Stop -LiteralPath $LiteralPath
    }
    catch {
        # Presumably, file doesn't exist, so we create it on deman, as WriteProfileString() would,
        # EXCEPT that we want to create a "Unicode" (UTF-16LE) file, whereas WriteProfileString()
        # - even when calling the Unicode version - ceates an *ANSI* file.
        # Note: As WriteProfileString() does, we require that the *directory* for the new file alreay exist.
        Set-Content -ErrorAction Stop -Encoding Unicode -LiteralPath $LiteralPath -Value @()
              (Get-Item -LiteralPath $LiteralPath).FullName # Output the full, native path.
    }
    $ok = [net.same2u.WinApiHelper.IniFile]::WritePrivateProfileString($Section, $Key, $Value, $fullPath)
    if (-not $ok) { Throw "Updating INI file failed: $fullPath" }

}
function Get-ServiceStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )

    $serviceDetails = "" | Select-Object -Property state, message

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if (-not $service) {

        $serviceDetails.message = @{Object = "        $ServiceName is not installed on this computer." }
    }
    else {
        $status = $service.Status

        $serviceDetails.state = $status -eq 'Running'

        $color = $(switch ($status) {
                'Running' { 'Green' }
                default { 'Red' }
            })

        $serviceDetails.message = @{Object = "        $ServiceName service is $status" ; ForegroundColor = $color }
    }
    return $serviceDetails

}
function Stop-RdConsole {
    [CmdletBinding()]
    param()
    # Get the process object for OSLRDServer
    $appConsole = Get-Process OSLRDServer -ErrorAction SilentlyContinue

    if ($appConsole) {
        Write-Host 'Trying to gracefully close the AppConsole...'
        # Try to close the main window gracefully first
        $appConsole.CloseMainWindow()

        # Wait for 5 seconds to let the window close
        Start-Sleep -Seconds 5

        # Check if the process is still running and kill it if needed
        if (!$appConsole.HasExited) {
            Write-Host 'AppConsole did not close gracefully. Killing the process...'
            $appConsole | Stop-Process -Force
        }
        else {
            Write-Host 'AppConsole closed gracefully.'
        }
    }
    else {
        Write-Host 'AppConsole is not running.'
    }
}

Function Stop-RdService {
    param()

    # Get RdService service
    $rdService = Get-Service -Name OSLRDServer -ErrorAction SilentlyContinue

    if (!$rdService) {
        Write-Host 'OSLRDServer service is not installed on this computer.'
        return
    }

    # Stop service if it is running
    if ($rdService.Status -ne 'Stopped') {
        Write-Host 'Stopping OSLRDServer service...'

        # Try stopping the service gracefully first
        $rdService.Stop()

        # Wait for the service to stop
        $rdService.WaitForStatus('Stopped', '00:00:05')

        # If the service is still running, force kill it
        if ($rdService.Status -ne 'Stopped') {
            Stop-Process -Name OSLRDServerService -Force
            Write-Host 'OSLRDServer service killed.'
        }
    }

    Write-Host 'OSLRDServer service stopped.'
}
Function Stop-OverOneMonitoring {
    #lo uso per killare il servizio da interfaccia
    # get OverOneMonitoring service
    $OverOneMonitoring = Get-Service OverOneMonitoringWindowsService -ErrorAction SilentlyContinue
    if ($OverOneMonitoring.Status -ne 'Stopped') {
        Stop-Process -name OverOneMonitoringWindowsService -Force
        write-Host 'OverOneMonitoring Killed'
    }
    Remove-Variable OverOneMonitoring

}
function Get-AppPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$serviceName
    )

    $service = Get-CimInstance -ClassName win32_service -Filter "Name='$serviceName'"
    if (!$service) {
        Write-Error "Service $serviceName not found"
        return
    }

    $serviceBinaryPath = if ($service.pathname -like '"*') {
        ($service.pathname -split '"')[1] # get path without quotes
    }
    else {
        (-split $service.pathname)[0] # get 1st token
    }

    return $serviceBinaryPath
}
Function Sync-InitConsole {
    #check init from service to appconsole if are equal
    if (Test-Path -Path $InitConsole -PathType Leaf) {
        if (!((Get-FileHash $InitService).Hash -eq (Get-FileHash $InitConsole).Hash)) {
            Write-Host 'Console ini not aligned...'
            Copy-Item $InitService -Destination $InitConsole
            Write-Host 'Copied from Service...Completed'
            Start-Sleep 3
            Clear-Host
        }
    }
    else {
        Write-Host 'Console ini missing...'
        Copy-Item $InitService -Destination $InitConsole
        Write-Host 'Copied from Service...Completed'
        Start-Sleep 3
        Clear-Host
    }
}
function Start-OslRdServerService {
    # [S] per avviare la modalita servizio
    Write-Host 'Avvio Servizio OslRdServer...' -ForegroundColor Green
    Stop-RdConsole
    Restart-Service  OSLRDServer
    Get-Service OSLRDServer
}
function Stop-OslRdServerService {
    # [F] per avviare la modalita servizio
    Write-Host 'Fermo Servizio OslRdServer...' -ForegroundColor Green
    Stop-RdConsole
    Stop-Service  OSLRDServer
    Get-Service OSLRDServer
}
function Start-OslRdServerConsole {
    #[C] per avviare la modalita console
    Write-Host 'Avvio Console...' -ForegroundColor Green
    Stop-RdConsole
    Stop-RdService
    Start-Process $pathExeConsole -Verb RunAs
}
function Stop-OslRdServerConsole {
    #[B] per avviare la modalita console
    Write-Host 'Stop Console...' -ForegroundColor Green
    Stop-RdConsole
}
function Stop-AllService {
    #[K] per arrestare il servizio o console e OverOne
    Write-Host 'Killo i servizi...' -ForegroundColor Green
    Stop-RdConsole
    Stop-RdService
    Stop-OverOneMonitoring
    Write-Host "Servizi FERMI"
}
function Restart-Overone {
    #[O] per riavviare il servizio OverOneMonitoring e cancellare il LOG
    if ($global:isOverOneInstalled) {
        Write-Host 'Killo Overone...' -ForegroundColor Green
        Stop-OverOneMonitoring
        Remove-Item -Path $LogOverOne -Force
        Start-Sleep 2
        Start-Service  OverOneMonitoringWindowsService
        Write-Host 'Aspetto i segnali...'
        Start-Sleep 15
        Invoke-Item $LogOverOne
    }
    else {
        Write-Host 'OverOne non installato' -ForegroundColor Red
    }
}
function Open-Init {
    #[I] per la lettura del Init di OSLRDServer
    Write-Host 'Apro Init...' -ForegroundColor Green
    Start-Process notepad.exe $InitService -NoNewWindow -Wait
    write-host 'Controllo modifiche...' -ForegroundColor Green
}
function Edit-Tcplistener {
    #[L] Per modificare TCPListener All'interno del init
    $IP = Read-Host -Prompt 'Inserisci IP da modificare '
    Set-IniValue $InitService 'Config' 'serverTCPListener' $IP
    Write-Host 'scritto ip...' -ForegroundColor Green
}
function Switch-SegnaliSuTabella {
    #[T] ON/OFF segnali su Tabella
    $usoCollegamentoUnico = Get-IniValue $InitService 'Config' 'usoCollegamentoUnico'
    $segnaliSutabella = Get-IniValue $InitService 'Config' 'segnaliSuTabella'

    if (($usoCollegamentoUnico -ne 0) -or ($segnaliSutabella -ne 0)) {
        Set-IniValue $InitService 'Config' 'usoCollegamentoUnico' 0
        Set-IniValue $InitService 'Config' 'segnaliSuTabella' 0
        Write-Host "Disabilitati segnali su tabella " -ForegroundColor RED
    }
    else {
        Set-IniValue $InitService 'Config' 'usoCollegamentoUnico' -1
        Set-IniValue $InitService 'Config' 'segnaliSuTabella' -1
        Write-Host "Abilitati segnali su tabella" -ForegroundColor green
    }
}
function Copy-DsnToInit {
    #[D] Copio dati di un dsn dentro init servizio
    Write-Host "DSN check"
    $selection = Get-ChildItem $PathDSN |  Out-GridView -OutputMode Single

    $title = "DSN overwrite"
    $question = "è stato selezionato il seguente dsn $($selection.Name) procedere?"
    $choices = '&Yes', '&No'

    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    if ($decision -eq 0) {
        Write-Host 'confirmed'

        $dsnDatabase = Get-IniValue $selection.FullName 'ODBC' 'DATABASE'
        Set-IniValue $InitService 'Config' 'database' $dsnDatabase

        $dsnServer = Get-IniValue $selection.FullName 'ODBC' 'SERVER'
        Set-IniValue $InitService 'Config' 'database' $dsnServer

        $dsnUser = Get-IniValue $selection.FullName 'ODBC' 'UID'
        Set-IniValue $InitService 'Config' 'database' $dsnUser

        $dsnPassword = Get-IniValue $selection.FullName 'ODBC' 'PASSWORD'
        Set-IniValue $InitService 'Config' 'database' $dsnPassword
    }
    else {
        Write-Host 'cancelled'
    }
}
function Show-FirewallStatus {

    $enabledFirewalls = Get-NetFirewallProfile | Where-Object { $_.Enabled }
    if ($enabledFirewalls) {
        Write-Host ' Firewall:'
        Write-Host ' Firewall Active'  -ForegroundColor Yellow
    }

}
function Open-Firewall {


    foreach ($port in $global:ports) {
        $ruleDisplayNameInbound = "OSL Allow inbound traffic on port $port"
        $ruleInbound = Get-NetFirewallRule -DisplayName $ruleDisplayNameInbound -ErrorAction SilentlyContinue

        if ($null -eq $ruleInbound) {
            New-NetFirewallRule -DisplayName $ruleDisplayNameInbound -Group "OSL" -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow
        }

        $ruleDisplayNameOutbound = "OSL Allow outbound traffic on port $port"
        $ruleOutbound = Get-NetFirewallRule -DisplayName $ruleDisplayNameOutbound -ErrorAction SilentlyContinue

        if ($null -eq $ruleOutbound) {
            New-NetFirewallRule -DisplayName $ruleDisplayNameOutbound -Group "OSL" -Direction Outbound -Protocol TCP -LocalPort $port -Action Allow
        }
    }
}

function Open-ConfiguraCollegamenti {

    #[V] Apri Configuratore Collegamenti

    $ps = Start-Process -PassThru -FilePath (join-Path -path $pathGp90OslRdServer -childpath '\ConfiguratoreCollegamenti\ConfiguratoreCollegamenti.exe') -WindowStyle Normal

    $wshell = New-Object -ComObject wscript.shell

    # Wait until activating the target process succeeds.
    # Note: You may want to implement a timeout here.
    while (-not $wshell.AppActivate($ps.Id)) {
        Start-Sleep -MilliSeconds 200
    }

    $wshell.SendKeys('osl')
    Sleep 0.5
    $wshell.SendKeys('{TAB}')
    Sleep 0.5
    $wshell.SendKeys('Osl5888')
    sleep 0.5
    $wshell.SendKeys('{ENTER}')

}
function Get-TCPOsl {
    $appConsole = Get-Process OSLRDServer -ErrorAction SilentlyContinue
    if ((Get-ServiceStatus('OSLRDServer')).state) {
        write-Host 'service running'
        $name = 'OSLRDServerService'
    }
    elseif ($appConsole) {
        Write-Host 'console runnning'
        $name = 'OSLRDServer'
    }
    else {
        Write-Host 'Console o servizio non attivo' -ForegroundColor Yellow
        break
    }

    $ID_OslRdServer = Get-Process $name | Select-Object Id

    Get-NetTCPConnection -owningprocess $ID_OslRdServer.Id
    Read-Host -Prompt "Press any key to continue..."
}
function Get-notepad++ {

    $FileUri = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.6.4/npp.8.6.4.Installer.x64.exe"
    $Destination = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path

    $Destination = join-Path -path $Destination -childpath 'npp.8.6.4.Installer.x64.exe'

    $bitsJobObj = Start-BitsTransfer $FileUri -Destination $Destination

    switch ($bitsJobObj.JobState) {

        'Transferred' {
            Complete-BitsTransfer -BitsJob $bitsJobObj
            break
        }

        'Error' {
            throw 'Error downloading'
        }
    }

    $exeArgs = '/S'

    Start-Process -Wait $Destination -ArgumentList $exeArgs

    write-host 'Installato Notepad++'
}

function Switch-DebugLog {

    $debugLog = Get-IniValue $InitService 'Config' 'debuglog'
    if ($debugLog -ne 0)  {
        Set-IniValue $InitService 'Config' 'debuglog' '0'
        Write-Host "Disabilitato DebugLog" -ForegroundColor RED
    }
    else {
        Set-IniValue $InitService 'Config' 'debuglog' '-1'
        Write-Host "Abilitato DebugLog" -ForegroundColor green
    }
}
function Open-GP90 {
    Start-Process $pathGp90
}

function Show-Title {
    Write-Host '
  ██████  ███████ ██              ██████  ███████ ██████  ██    ██  ██████   ██████  ███████ ██████
 ██    ██ ██      ██              ██   ██ ██      ██   ██ ██    ██ ██       ██       ██      ██   ██
 ██    ██ ███████ ██              ██   ██ █████   ██████  ██    ██ ██   ███ ██   ███ █████   ██████
 ██    ██      ██ ██              ██   ██ ██      ██   ██ ██    ██ ██    ██ ██    ██ ██      ██   ██
  ██████  ███████ ███████         ██████  ███████ ██████   ██████   ██████   ██████  ███████ ██   ██
  '
}
function Show-Menu {
    param (
        [string]$Title = 'Osl Debugger'
    )
    Write-Host""
    write-host " Funzionalità di controllo OSLRDServer e servizi annessi al Coll.Macchina, comandi in elenco qui sotto:"
    write-host "======================================================================================================="
    Write-Host "= [J] Open osl firewall"
    Write-Host "= [+] install Notepad++"
    Write-Host '= [G] ON/OFF DebugLog'
    Write-Host '= [9] Open Gp90 folder'


    if ($global:isGP90Installed) {
        Write-Host "= [A] Forza Allineamento Init Servizio con init console"
        Write-Host "= [I] per la lettura del Init di OSLRDServer"
        Write-Host "= [v] Apri Configuratore Collegamenti"
        Write-Host "= [L] Per modificare TCPListener All'interno del init"
        Write-Host "= [T] ON/OFF segnali su Tabella"
        Write-Host "= [D] Copio dati di un dsn dentro init servizio"
        write-Host "= [E] Check TCP servizio o console OSL"
    }
    if ($global:isGP90Installed -or $global:isOverOneInstalled) {
        Write-Host "======= Gestione servizi =============================="
        Write-Host "= [K] per arrestare tutti i servizi"
    }
    if ($global:isGP90Installed) {

        Write-Host "========== Servizio OslRdServer ======================="
        Write-Host "=   [S] per avviare la modalita servizio OSlRdServer"
        Write-Host "=   [F] per Fermare la modalita servizio OSlRdServer"
        Write-Host "========== Console OslRdServer ========================"
        Write-Host "=   [C] per avviare la modalita console"
        Write-Host "=   [B] per fermare la modalita console"
    }
    if ($global:isOverOneInstalled) {

        Write-Host "========== Overone ===================================="
        Write-Host "=   [O] per riavviare il servizio OverOneMonitoring e cancellare il LOG"
        Write-Host "=   [U] per fermare il servizio OverOneMonitoring"

    }
    Write-Host "======================================================================================================"
    Write-Host " [X] chiude script"
    Write-Host " [R] Reload script"
    Write-Host""
}
Function main {

    $global:ports = @(1433, 5888)

    #OverOne
    #check if Overone is installed
    $is32OverOneInstalled = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq "OverOne Desktop" })
    $is64OverOneInstalled = $null -ne (Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq "OverOne Desktop" })
    $global:isOverOneInstalled = $is32OverOneInstalled -or $is64OverOneInstalled

    if ($global:isOverOneInstalled) {
        $pathOverOneMonitor = Split-Path -Path (Get-AppPath('OverOneMonitoringWindowsService'))
        $LogOverOne = Join-Path -Path ($pathOverOneMonitor + '\Log') -childpath (Get-ChildItem ($pathOverOneMonitor + '\Log' ) -Filter overOneMonitoringService.log -Name)
    }

    #GP90
    #check if GP90 is installed
    $is32GP90Installed = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.Publisher -eq "O.S.L." })
    $is64GP90Installed = $null -ne (Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.Publisher -eq "O.S.L." })
    $global:isGP90Installed = $is32GP90Installed -or $is64GP90Installed

    if ($global:isGP90Installed) {
        $servicepath = Get-AppPath('OSLRDServer')
        $pathGp90 = $servicepath.Substring(0, $servicepath.IndexOf("Programmi_Aggiuntivi"))
        $pathGp90OslRdServer = split-path -path ($servicepath)
        $PathDSN = Join-Path -Path $pathGp90 "\dsn"
        $InitService = Join-Path -Path $pathGp90OslRdServer -childpath (Get-ChildItem $pathGp90OslRdServer -Filter ?nit.ini -Name)
        $InitConsole = Join-Path -Path ($pathGp90OslRdServer + '\AppConsole' )  -childpath (Get-ChildItem ($pathGp90OslRdServer + '\AppConsole' ) -Filter ?nit.ini -Name)
        $pathExeConsole = join-Path -Path $pathGp90OslRdServer -childpath '\AppConsole\OSLRDServer.exe'
    }

    while ($true) {

        Show-Title

        #controlli
        if ($global:isGP90Installed) {
            if (!((Get-FileHash $InitService).Hash -eq (Get-FileHash $InitConsole).Hash)) {
                Write-Host 'CONSOLE INI NOT ALIGNED' -ForegroundColor Red
            }

            Write-Host ''
            Write-Host ' INFORMAZIONI:'

            if ((Get-IniValue $InitService 'Config' 'segnaliSuTabella') -ne 0) { Write-Host '        Segnali su Tabella Attivo' -ForegroundColor green } else { Write-Host '        Segnali su Tabella disattivo' -ForegroundColor Red }
            if ((Get-IniValue $InitService 'Config' 'usoCollegamentoUnico') -ne 0) { Write-Host '        Collegamento Unico Attivo' -ForegroundColor green } else { Write-Host '        Collegamento Unico disattivo' -ForegroundColor Red }
            Switch ($nodo = Get-IniValue $InitService 'Config' 'nodo') {
                '' { write-host '        Non sono presenti nodi' -ForegroundColor green }
                default { Write-Host '        Sono presenti nodi, questo è il nodo:', $nodo -ForegroundColor Yellow }
            }
            Write-Host ' Indirizzi IP:'
            Write-Host '        Indirizzo IP inserito dentro INIT:'  (Get-IniValue $InitService 'Config' 'serverTCPListener')
        }

        Write-Host ' Servizi:'
        $serviceOSLRDServer = (Get-ServiceStatus('OSLRDServer')).message
        $serviceOverone = (Get-ServiceStatus('OverOne Monitoring Service')).message
        write-host @serviceOSLRDServer
        write-host @serviceOverone

        Show-FirewallStatus

        Write-Host ' Password: 1234-i4qfis-6in7'
        if ((Get-IniValue $InitService 'Config' 'debuglog') -ne 0) {Write-Host ' Debug log attivo'} else {Write-Host ' Debug log disattivo'}

        Show-Menu
        $key = Read-Host 'Digitare la lettera del comando e premere ENTER'
        Write-Host''

        #opzioni [A I L T D S C K O X F B R V E J + G 9]
        Switch ($key) {
            A {
                #[A] Forza Allineamento Init Servizio con init console
                Sync-InitConsole
            }
            I {
                #[I] per la lettura del Init di OSLRDServer
                Open-Init
            }
            L {
                #[L] Per modificare TCPListener All'interno del init
                Edit-Tcplistener
            }
            T {
                #[T] ON/OFF segnali su Tabella
                Switch-SegnaliSuTabella
            }
            D {
                #[D] Copio dati di un dsn dentro init servizio
                Copy-DsnToInit
            }
            V {
                #[V] Apri Configuratore Collegamenti
                Open-ConfiguraCollegamenti
            }
            ########## Gestione servizi ###############
            K {
                #[K] per arrestare tutti i servizi
                Stop-AllService
            }
            ########## servizio OslRdServer ##########
            S {
                # [S] per avviare la modalita servizio OSlRdServer
                Start-OslRdServerService
            }
            F {
                # [F] per Fermare la modalita servizio OSlRdServer
                Stop-OslRdServerService
            }
            ########## Console OslRdServer ##########
            C {
                #[C] per avviare la modalita console
                Start-OslRdServerConsole
            }
            B {
                #[B] per fermare la modalita console
                Stop-OslRdServerConsole
            }
            ########## Overone ##########
            O {
                #[O] per riavviare il servizio OverOneMonitoring e cancellare il LOG
                Restart-Overone
            }
            U {
                #[U] per fermare il servizio OverOneMonitoring
                Stop-OverOneMonitoring
            }
            #######################################
            +{
                #[+] installa notepad++
                Get-notepad++
            }
            G{
                #[G] ON/OFF Debug
                Switch-DebugLog
            }
            9{
                #[9] Open GP90
                Open-GP90
            }
            X {
                #[X] chiude script
                Clear-Host
                Exit
            }
            E {
                #[E] Check TCP servizio o console OSL
                Get-TCPOsl
            }
            J {
                #[J] Open firewall
                Open-Firewall
            }
            R {
                #[R] Reload script
                Clear-Host
            }
            default { write-host 'Invalid option' -ForegroundColor red }
        }

        start-sleep 2
        Clear-Host
    }

}

main
