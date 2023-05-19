﻿# Check if running in Administrator mode
if (!( [Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
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

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if (-not $service) {
        Write-Host "        $ServiceName is not installed on this computer."
    }
    else {
        $status = $service.Status
        Write-Host "        $ServiceName service is $status" -ForegroundColor $(switch ($status) {
                'Running' { 'Green' }
                default { 'Red' }
            })
    }
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

    Write-Host "================================================================================================
    "
    
    write-host "Funzionalità di controllo OSLRDServer e servizi annessi al Coll.Macchina, comandi in elenco qui sotto:"
    
    Write-Host "
    [A]: Forza Allineamento Init Servizio con init console
    [C]: Avviare OSLRDServer in Console
    [S]: Avviare Servizio OSLRDServer
    [K]: Killare tutti i servizi
    [O]: Riavviare OverOneMonitoring, cancello il LOG e lo apro
    [I]: Apro Init di OSLRDServer
    [L]: Modifica TCP Listener All'interno del init
    [T]: ON/OFF segnali su Tabella
    [D]: Copia da Dsn
    [X]: Chiude script
    " 
}
function Start-OslRdServerService {
    # [S] per avviare la modalita servizio
    Write-Host 'Avvio Servizio...' -ForegroundColor Green
    Stop-RdConsole
    Restart-Service  OSLRDServer
    Get-Service OSLRDServer
}

function Start-OslRdServerConsole {
    #[C] per avviare la modalita console
    Write-Host 'Avvio Console...' -ForegroundColor Green
    Stop-RdConsole
    Stop-RdService
    Start-Process $pathExeConsole -Verb RunAs
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
    if ($isOverOneInstalled) {
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

    if (($usoCollegamentoUnico -eq -1) -or ($segnaliSutabella -eq -1)) {
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


#Main-Function

<# ------------- TODO ------------------
- check su installazione va in errore se non presenti le voci reg capire come gestire

#>
Function main {

    #OverOne
    #check if Overone is installed   
    $is32OverOneInstalled = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq "OverOne Desktop" })
    $is64OverOneInstalled = $null -ne (Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq "OverOne Desktop" })
    $isOverOneInstalled = $is32OverOneInstalled -or $is64OverOneInstalled

    if ($isOverOneInstalled) {
        $pathOverOneMonitor = Split-Path -Path (Get-AppPath('OverOneMonitoringWindowsService'))
        $LogOverOne = Join-Path -Path ($pathOverOneMonitor + '\Log') -childpath (Get-ChildItem ($pathOverOneMonitor + '\Log' ) -Filter overOneMonitoringService.log -Name)        
    }

    #GP90
    #check if GP90 is installed   
    $is32GP90Installed = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.Publisher -eq "O.S.L." })
    $is64GP90Installed = $null -ne (Get-ItemProperty HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.Publisher -eq "O.S.L." })
    $isGP90Installed = $is32GP90Installed -or $is64GP90Installed

    if ($isGP90Installed) {
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
        if (!((Get-FileHash $InitService).Hash -eq (Get-FileHash $InitConsole).Hash)) {
            Write-Host 'CONSOLE INI NOT ALIGNED' -ForegroundColor Red          
        }
       
        Write-Host ''
        Write-Host ' INFORMAZIONI:'

        if ((Get-IniValue $InitService 'Config' 'segnaliSuTabella') -eq -1) { Write-Host '        Segnali su Tabella Attivo' -ForegroundColor green } else { Write-Host '        Segnali su Tabella disattivo' -ForegroundColor Red }        
        if ((Get-IniValue $InitService 'Config' 'usoCollegamentoUnico') -eq -1) { Write-Host '        Collegamento Unico Attivo' -ForegroundColor green } else { Write-Host '        Collegamento Unico disattivo' -ForegroundColor Red }
        Switch ($nodo = Get-IniValue $InitService 'Config' 'nodo') {
            '' { write-host '        Non sono presenti nodi' -ForegroundColor green}
            default { Write-Host '        Sono presenti nodi, questo è il nodo:',$nodo -ForegroundColor Yellow }
        }
      
        Write-Host ''
        Write-Host ' Indirizzi IP:'
        Write-Host '        Indirizzo IP inserito dentro INIT:'  (Get-IniValue $InitService 'Config' 'serverTCPListener')
        Write-Host ''
        Write-Host ' Servizi:'
        Get-ServiceStatus('OSLRDServer')
        Get-ServiceStatus('OverOne Monitoring Service')
        Write-Host ''

        Write-Host ' Firewall:'
        Get-NetFirewallProfile | Format-Table Name, @{
            Label      = "Enabled"
            Expression =
            {
                switch ($_.Enabled) {
                    'True' { $color = '91'; break }
                    default { $color = '0' }
                }
                $e = [char]27
                "$e[${color}m$($_.Enabled)${e}[0m"
            }
        }
        Show-Menu
        $key = Read-Host 'Digitare la lettera del comando e premere ENTER'
        Write-Host''

        Switch ($key) {
            A {
                #[A] Forza Allineamento Init Servizio con init console
                Sync-InitConsole
            }   
            S {
                # [S] per avviare la modalita servizio
                Start-OslRdServerService
            }
            C {
                #[C] per avviare la modalita console
                Start-OslRdServerConsole
            }
            K {
                #[K] per arrestare il servizio o console e OverOne
                Stop-AllService
            }
            O {
                #[O] per riavviare il servizio OverOneMonitoring e cancellare il LOG
                Restart-Overone
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
            X {    
                #[X] chiude script               
                Clear-Host   
                Exit
            }
            default { write-host 'Invalid option' -ForegroundColor red }
        }

        start-sleep 2
        Clear-Host
    }

}

main