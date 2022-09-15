
#Start in Admin mode
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

Add-Type -Namespace net.same2u.WinApiHelper -Name IniFile -MemberDefinition @'
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
  // Note the need to use `[Out] byte[]` instead of `System.Text.StringBuilder` in order to support strings with embedded NUL chars.
  public static extern uint GetPrivateProfileString(string lpAppName, string lpKeyName, string lpDefault, [Out] byte[] lpBuffer, uint nSize, string lpFileName);
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
  public static extern bool WritePrivateProfileString(string lpAppName, string lpKeyName, string lpString, string lpFileName);
'@
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
Function Get-Service-Status {
    param(
        [Parameter (Mandatory = $true)] $sName
    )
    # Purpose: To check whether a service is installed
    $service = Get-Service -display $sName -ErrorAction SilentlyContinue
    
    If ( -not $service ) {
        Write-Host $sName  ' is not installed on this computer.'
    }
    else {
        if ($service.Status -eq 'Running') { Write-Host $sName   'Service is running' -ForegroundColor green } else { Write-Host $sName 'Service is not running' -ForegroundColor Red }
    }
    
    Remove-Variable sName
}
Function Write-INIT-OSLRDServer {
    param(
        [Parameter (Mandatory = $false)] $ObjectCustom,
        [Parameter (Mandatory = $false)] [string] $Directory
    )
    
    # START WRITE
    $InputObject = $ObjectCustom
    Remove-Item -Path $Directory -Force
    $outFile = New-Item -ItemType file -Path $Directory
    foreach ($i in $InputObject.keys) {
        if (!($($InputObject[$i].GetType().Name) -eq 'Hashtable')) {
            #No Sections
            Add-Content -Path $outFile -Value “$i=$($InputObject[$i])”
        }
        else {
            #Sections
            Add-Content -Path $outFile -Value '[$i]'
            Foreach ($j in ($InputObject[$i].keys | Sort-Object)) {
                if ($j -match '^Comment[\d]+') {
                    Add-Content -Path $outFile -Value “$($InputObject[$i][$j])”
                }
                else {
                    Add-Content -Path $outFile -Value “$j=$($InputObject[$i][$j])”
                }

            }
            Add-Content -Path $outFile -Value “”
        }
    } # END WRITE
}
Function Stop-RdConsole {

    # get appConsole process
    $appConsole = Get-Process OSLRDServer -ErrorAction SilentlyContinue
    if ($appConsole) {
        # try gracefully first
        Write-Host 'is AppConsole closed?'
        $appConsole.CloseMainWindow()
        # kill after five seconds
        Start-Sleep 3
        if (!$appConsole) {
            $appConsole | Stop-Process -Force
            Write-Host 'AppConsole Killed'
        }
        
    }
    Remove-Variable appConsole
    
}
Function Stop-RdService {

    # get RdService service
    $rdService = Get-Service OSLRDServer -ErrorAction SilentlyContinue
    if ($rdService.Status -ne 'Stopped') {
        # try gracefully first
        Stop-Service $rdService
        # kill after five seconds
        Start-Sleep 3
        if ($rdService.Status -ne 'Stopped') {
            Stop-Process -name OSLRDServerService -Force
            write-Host 'OSLRDService Killed'
        }
        write-Host 'OSLRDService now Stopped'
    }
    Remove-Variable rdService
    
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
Function Get-AppPath {
    param ([Parameter (Mandatory = $true)] [string] $serviceName) 

    $service = Get-CimInstance -ClassName win32_service | Where-Object Name -eq $servicename
    $serviceBinaryPath = if ($service.pathname -like '"*') { 
    ($service.pathname -split '"')[1] # get path without quotes
    }
    else {
    (-split $service.pathname)[0] # get 1st token
    }

    return $serviceBinaryPath    
}
Function Sync-INIT-Console {
    #check init from service to appconsole if are equal
    if (Test-Path -Path $pathInitConsole -PathType Leaf) {
        if (!((Get-FileHash $pathInitService).Hash -eq (Get-FileHash $pathInitConsole).Hash)) {
            Write-Host 'Console ini not aligned...'
            Copy-Item $pathInitService -Destination $pathInitConsole
            Write-Host 'Copied from Service...Completed'
            Start-Sleep 3
            Clear-Host
        }
    }
    else {
        Write-Host 'Console ini missing...'
        Copy-Item $pathInitService -Destination $pathInitConsole
        Write-Host 'Copied from Service...Completed'
        Start-Sleep 3
        Clear-Host
    }
}
#Main-Function
Function main {

    #Path Application
    $pathGp90 = Split-Path -Path (Get-AppPath('OSLRDServer'))
    $pathOverOne = Split-Path -Path (Get-AppPath('OverOneMonitoringWindowsService'))

    #Path file
    $pathInitService = Join-Path -Path $pathGp90 -childpath (Get-ChildItem $pathGp90 -Filter ?nit.ini)
    $pathInitConsole = Join-Path -Path ($pathGp90 + '\AppConsole' )  -childpath (Get-ChildItem ($pathGp90 + '\AppConsole' ) -Filter ?nit.ini)
    $pathLogOverOne = Join-Path -Path ($pathOverOne + '\Log') -childpath (Get-ChildItem ($pathOverOne + '\Log' ) -Filter overOneMonitoringService.log)

    #Path exe
    $pathConsole = join-Path -Path $pathGp90 -childpath '\AppConsole\OSLRDServer.exe'

    $iniDict = Get-Ini $pathInitService

    #$IndirizzoIP = Get-NetIPAddress -InterfaceIndex ((Get-NetIPConfiguration).Where({ $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.status -ne "Disconnected" })).InterfaceIndex
    $IndirizzoIP = (Get-NetIPAddress | Where-Object { $_.AddressState -eq "Preferred" -and $_.ValidLifetime -lt "24:00:00" }).IPAddress

    Sync-INIT-Console

    FOR ($Conteggio = 0; $Conteggio = -1; $Conteggio++) {
        Write-Host '                                                         
  ██████  ███████ ██              ██████  ███████ ██████  ██    ██  ██████   ██████  ███████ ██████  
 ██    ██ ██      ██              ██   ██ ██      ██   ██ ██    ██ ██       ██       ██      ██   ██ 
 ██    ██ ███████ ██              ██   ██ █████   ██████  ██    ██ ██   ███ ██   ███ █████   ██████  
 ██    ██      ██ ██              ██   ██ ██      ██   ██ ██    ██ ██    ██ ██    ██ ██      ██   ██ 
  ██████  ███████ ███████         ██████  ███████ ██████   ██████   ██████   ██████  ███████ ██   ██'

        #Garbage collection
        if (($i % 200) -eq 0) {
            [System.GC]::Collect()
        }


        Write-Host '
    Segnali su tabella'
        if ($iniDict.Config.segnaliSuTabella -eq -1) { Write-Host 'Segnali su Tabella Attivo' -ForegroundColor green } else { Write-Host 'Segnali su Tabella disattivo' -ForegroundColor Red }
        if ($iniDict.Config.UsoCollegamentoUnico -eq -1) { Write-Host 'Collegamento Unico Attivo' -ForegroundColor green } else { Write-Host 'Collegamento Unico disattivo' -ForegroundColor Red }

        Write-Host '
    Indirizzi IP:'
        Write-Host 'Indirizzo IP inserito dentro INIT:'  $iniDict.Config.serverTCPListener
        Write-Host 'Indirizzo IP del PC: ' $IndirizzoIP

        Write-Host '
    Servizi:'
        Get-Service-Status('OSLRDServer')
        Get-Service-Status('OverOne Monitoring Service')

        Write-Host " 
    Inizializzazione dati completata----------------------------------------------------------------------" -ForegroundColor green
        Write-Host "                                                                                                  
    Funzionalità di controllo OSLRDServer e servizi annessi al Coll.Macchina, comandi in elenco qui sotto: 
    - Avviare OSLRDServer in [C]onsole                                              
    - Avviare [S]ervizio OSLRDServer                                    
    - [K]illare tutti i servizi                              
    - Riavviare [O]verOneMonitoring, cancello il LOG e lo apro                                                        
    - Apro [I]nit di OSLRDServer                                          
    " 
        #Digitare [TCP] Per modificare TCPListener All'interno del init                                  
        #Digitare [E]dit per modificare INIT di OSLRDserver   
    
        write-output "Digitare la LETTERA del COMANDO:"
        $key = $Host.UI.RawUI.ReadKey()
        Write-Host''   

        Switch ($key.Character) {
            S {
                # [S]ervice per avviare la modalita servizio
                Write-Host 'Avvio Servizio...' -ForegroundColor Green
                Stop-RdConsole
                Restart-Service  OSLRDServer
                Get-Service OSLRDServer
            }
            C {
                #[C]onsole per avviare la modalita console
                Write-Host 'Avvio Console...' -ForegroundColor Green
                Stop-RdConsole
                Stop-RdService
                Start-Process $pathConsole -Verb RunAs
            }
            K {
                #[K]ill per arrestare il servizio o console e OverOne
                Write-Host 'Killo i servizi...' -ForegroundColor Green
                Stop-RdConsole
                Stop-RdService
                Stop-OverOneMonitoring      
                Write-Host "Servizi FERMI"
            }
            O {
                #[O]verOne per riavviare il servizio OverOneMonitoring e cancellare il LOG
                Write-Host 'Killo Overone...' -ForegroundColor Green
                Stop-OverOneMonitoring
                Remove-Item -Path $pathLogOverOne -Force
                Start-Sleep 2
                Start-Service  OverOneMonitoringWindowsService  
                Write-Host 'Aspetto i segnali...'   
                Start-Sleep 5
                Invoke-Item $pathLogOverOne
            }
            I {
                #[I] per la lettura del Init di OSLRDServer   
                Write-Host 'Apro Init...' -ForegroundColor Green
                notepad $pathInitService  
            }
            X {    
                #[X] chiude script
                #Garbage collection
                if (($i % 200) -eq 0) {
                    [System.GC]::Collect()
                }   
                Clear-Host   
                Exit
            }
            default { write-host 'Invalid option' -ForegroundColor red }
        } 

        


        #############################################################################
        #                da Controllare                                             #
        #############################################################################
        #--------------------------------------------------
        #TODO eccezioni su porte firewall
        #TODO auto firewall
        #TODO get Machine LIST and check firewall
        #TODO check if overone is installed

        #dsn 
        <# $PathDSN = $pathGp90.Substring(0,$pathGp90.IndexOf("GP90Next"))
        $PathDSN =  join-Path -Path $PathDSN -childpath '\GP90Next\DSN\GP90.dsn'
            try {
                $DSNGP90 = Get-Ini $PathDSN                
                }
                catch [System.Net.WebException],[System.IO.IOException] {                
                }catch {
                $DSNGP90 = 'File GP90.dsn non trovato'    
                } #>

        #--------------------------------------------------

        #[TCP] Per modificare TCPListener All'interno del init
        if ($SCELTA -eq "TCP") {       

            $IP = Read-Host -Prompt 'Inserisci IP da modificare '
            $iniDict.Config.serverTCPListener = $IP     
            # Salvo la modifica, scrivendola nel file 
            Write-INIT-OSLRDServer -ObjectCustom $iniDict -Directory $pathInitService
            #Ricarico il file in memoria
            $iniDict = Get-Ini $pathInitService
        }

        #TODO REFACTOR# conpilazione automatica DSN
        if ($SCELTA -eq "AU") {       
            IF ($DSNGP90 -eq 'File GP90.dsn non trovato') {
                Write-Host "  
         Non Esiste il GP90.dsn, probabilmente
         " -ForegroundColor red
            }
            else {
                $iniDict.Config.serverDB = $DSNGP90.ODBC.SERVER
                $iniDict.Config.database = $DSNGP90.ODBC.DATABASE
                $iniDict.Config.username = $DSNGP90.ODBC.UID
                $iniDict.Config.password = $DSNGP90.ODBC.password
                $iniDict.Config.ServerTCPListener = $IndirizzoIP.IPAddress
                $iniDict.Task1.secondi = 15
                $iniDict.Task2.secondi = 19
                Write-Host "  
          Riepilogo delle informazzioni che verranno scritte dentro init : " -ForegroundColor green
                $iniDict.Config
                Start-Sleep 10
                try {
                    Write-INIT-OSLRDServer -ObjectCustom $iniDict -Directory $pathInit
                    $iniDict = Get-Ini $pathInit
                    Write-Host "               
              Scrittura Eseguita" -ForegroundColor green      
                }
                catch [System.Net.WebException], [System.IO.IOException] {       
                }
                catch {
                    Write-Host "  
             Scrittura non risucita" -ForegroundColor red    
                }
            }
        }

        #TODO REFACTOR# ON/OFF segnali su tabella
        if ($SCELTA -eq "TAB") {     
            IF (($iniDict.Config.UsoCollegamentoUnico -eq -1) -or ( $iniDict.Config.segnaliSuTabella -eq -1) ) {            
                $iniDict.Config.UsoCollegamentoUnico = 0
                $iniDict.Config.segnaliSuTabella = 0
                Write-Host "   Disabilitata " -ForegroundColor RED
            }
            else {
                $iniDict.Config.UsoCollegamentoUnico = -1
                $iniDict.Config.segnaliSuTabella = -1
                Write-Host "   Abilitata " -ForegroundColor green
            }
            Write-Host "  
           Modifica effettuata, tra poco verrà effettuata la scrittura su File " -ForegroundColor white
            Start-Sleep 10
            try {
                Write-INIT-OSLRDServer -ObjectCustom $iniDict -Directory $pathInit
                $iniDict = Get-Ini $pathInit
                Write-Host "             
             Scrittura Eseguita" -ForegroundColor green      
            }
            catch [System.Net.WebException], [System.IO.IOException] {       
            }
            catch {
                Write-Host "
           Scrittura non risucita" -ForegroundColor red    
            }
        }

        #[E]dit per modificare INIT di OSLRDserver
        if ($SCELTA -eq "E") {          
            FOR ($Continuo = -1; $Continuo -lt 10; $Continuo++) {
                Write-Host "Quale TAG del file INIT vuoi modificare ? " -ForegroundColor green   
                $iniDict.keys

                $TAG = Read-Host -Prompt "Quale vuoi modificare ? "
                Write-Host "Perfetto, il TAG contiene questi valori:  " -ForegroundColor green
                $iniDict[$TAG]

                Write-Host "Cosa vuoi modificare ? " -ForegroundColor green
                $MOD = Read-Host -Prompt "indica il TAG:  "
                #Write-Host "Valore ? " -ForegroundColor green
                $VAL = Read-Host -Prompt  "Quale Valore: "

                $iniDict[$TAG][$MOD] = $VAL
                Clear-Host
                $iniDict[$TAG]
                $YESNO = Read-Host Prompt  "Continuare a fare delle modifiche ? [S/N]: "
                if ($YESNO -ne 'S') {
                    $Continuo = 11
                }       
                #END FOR
            } #Write File
            Write-INIT-OSLRDServer -ObjectCustom $iniDict -Directory $pathInitService
        }

            
        start-sleep 2
        Clear-Host
    }

}

main