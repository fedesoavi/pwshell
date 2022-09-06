

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

#Start in Admin mode
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}



Clear-Host
function Get-Ini {
    param(
        [Parameter (Mandatory = $false)] [String]$Directory
    )
    
    $init = @{}
    switch -regex -file $Directory {
        '^\[(.+)\]' {
            # Section
            $section = $matches[1]
            $init[$section] = @{}
            $CommentCount = 0
        }
        '^(;.*)$' {
            # Comment
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = 'Comment' + $CommentCount
            $init[$section][$name] = $value
        }
        '(.+?)\s*=(.*)' {
            # Key
            $name, $value = $matches[1..2]
            $init[$section][$name] = $value
        }
    }
    return $init
}

function Write-INIT-OSLRDServer {
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

function Stop-RdConsole {

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

function Stop-RdService {

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
function Stop-OverOneMonitoring {

    # get OverOneMonitoring service
    $OverOneMonitoring = Get-Service OverOneMonitoringWindowsService -ErrorAction SilentlyContinue
    if ($OverOneMonitoring.Status -ne 'Stopped') {
        Stop-Process -name OverOneMonitoringWindowsService -Force
        write-Host 'OverOneMonitoring Killed'        
    }
    Remove-Variable OverOneMonitoring
    
}

function Get-AppPath {
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

function Sync-INIT-Console {
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
  ██████  ███████ ███████         ██████  ███████ ██████   ██████   ██████   ██████  ███████ ██   ██                                                                                                                                                                                               
'

    #Garbage collection
    if (($i % 200) -eq 0) {
        [System.GC]::Collect()
    }

    if ($iniDict.Config.segnaliSuTabella -eq -1) { Write-Host '  Segnali su Tabella Attivo' -ForegroundColor green } else { Write-Host '  Segnali su Tabella disattivo' -ForegroundColor Red }
    if ($iniDict.Config.UsoCollegamentoUnico -eq -1) { Write-Host '  Collegamento Unico Attivo' -ForegroundColor green } else { Write-Host '  Collegamento Unico disattivo' -ForegroundColor Red }

    Write-Host '
    Indirizzo IP inserito dentro INIT:'  $iniDict.Config.serverTCPListener
    Write-Host '
    Indirizzo IP del PC: ' $IndirizzoIP



    if (Get-Service OSLRDServer) { Write-Host '  Segnali su Tabella Attivo' -ForegroundColor green } else { Write-Host '  Segnali su Tabella disattivo' -ForegroundColor Red }

    Get-Service OverOneMonitoringWindowsService, OSLRDServer | Format-Table Name, Status

    Write-Host " 
    Inizializzazione dati completata----------------------------------------------------------------------" -ForegroundColor green
    Write-Host "                                                                                                  
    Funzionalità di controllo OSLRDServer e servizi annessi al Coll.Macchina, comandi in elenco qui sotto: 
    Digitare [C]onsole per avviare la modalita console                                              
    Digitare [S]ervice per avviare la modalita servizio                                             
    Digitare [K]ill per arrestare il servizio o console e OverOne                                   
    Digitare [O]verOne per riavviare il servizio OverOneMonitoring e cancellare il LOG              
    Digitare [TCP] Per modificare TCPListener All'interno del init                                  
    Digitare [E]dit per modificare INIT di OSLRDserver                                              
    Digitare [INIT] per la lettura del Init di OSLRDServer                                          
    Digitare [R]estricted, verificare stato restrizione policy esecuione script, ed impostarlo a REstricted
    " 
    
    $SCELTA = Read-Host -Prompt "   Digitare la LETTERA del COMANDO: "
    Write-Host ' '

    # [S]ervice per avviare la modalita servizio
    if ($SCELTA -eq "s") {
        Stop-RdConsole
        Restart-Service  OSLRDServer
        Get-Service OSLRDServer
    }

    #[C]onsole per avviare la modalita console
    if ($SCELTA -eq "c") { 
        Stop-RdConsole
        Stop-RdService
        Start-Process $pathConsole -Verb RunAs 
    }
    #[K]ill per arrestare il servizio o console e OverOne
    if ($SCELTA -eq "k") { 
        Stop-RdConsole
        Stop-RdService
        Stop-OverOneMonitoring      
        Write-Host "Servizi FERMI"
    }
    #[O]verOne per riavviare il servizio OverOneMonitoring e cancellare il LOG
    if ($SCELTA -eq "o") {
        Stop-OverOneMonitoring
        Remove-Item -Path $pathLogOverOne -Force
        Start-Service  OverOneMonitoringWindowsService     
        TIMEOUT /t 5
        Start-Process $pathLogOverOne
    }
    #[TCP] Per modificare TCPListener All'interno del init
    if ($SCELTA -eq "TCP") {       

        $IP = Read-Host -Prompt 'Inserisci IP da modificare '
        $iniDict.Config.serverTCPListener = $IP     
        # Salvo la modifica, scrivendola nel file 
        Write-INIT-OSLRDServer -ObjectCustom $iniDict -Directory $pathInitService
        #Ricarico il file in memoria
        $iniDict = Get-Ini $pathInitService
    }
    #[INIT] per la lettura del Init di OSLRDServer
    if ($SCELTA -eq "INIT") {       
        notepad $pathInitService  
    }
    #[R]estricted, verificare stato restrizione policy esecuione script, ed impostarlo a REstricted
    if ($SCELTA -eq "R") {       
        get-executionpolicy
        set-executionpolicy RemoteSigned    
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
    #[task] show service
    if ($SCELTA -eq "task") {       
        Get-CimInstance  -ClassName win32_service | Where-Object Name -eq OSLRDServer | Select-Object name, state, status, starttype
        Get-CimInstance  -ClassName win32_service | Where-Object Name -eq OSLProcessiService | Select-Object name, state, status, starttype
        Get-CimInstance  -ClassName win32_service | Where-Object Name -eq OverOneMonitoringWindowsService | Select-Object name, state, status, starttype
        Pause
    }

    #[I]nfo get service Info and firewall
    if ($SCELTA -eq "I") {

        # Purpose: To check whether a service is installed
        Clear-Host
        $sName = "OSLRDServer"
        $service = Get-Service -display $sName -ErrorAction SilentlyContinue
        If ( -not $service ) {
            $sName + " is not installed on this computer. `n
                Did you really mean: " + $sName 
        }
        else {
            $sName + " is installed."
            $sName + "’s status is: " + $service.Status 
        }
        #Get-Service OverOneMonitoringWindowsService, OSLRDServer | Format-Table Name, Status
        #Get-NetFirewallProfile | Format-Table Name, Enabled
        Pause
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
    if ($SCELTA -eq "x") {    
        #Garbage collection
        if (($i % 200) -eq 0) {
            [System.GC]::Collect()
        }   
        Clear-Host   
        Exit
    }
    start-sleep 3
    Clear-Host
}