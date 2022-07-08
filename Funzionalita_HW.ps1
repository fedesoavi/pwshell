# iwr -useb  | iex

#TODO eccezioni su porte firewall


If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

function MEMInit {
    param(
        [Parameter (Mandatory = $false)] [String]$Directory
    )
    
    $init = @{}
    switch -regex -file $Directory {
        “^\[(.+)\]” {
            # Section
            $section = $matches[1]
            $init[$section] = @{}
            $CommentCount = 0
        }
        “^(;.*)$” {
            # Comment
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = “Comment” + $CommentCount
            $init[$section][$name] = $value
        }
        “(.+?)\s*=(.*)” {
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
        if (!($($InputObject[$i].GetType().Name) -eq “Hashtable”)) {
            #No Sections
            Add-Content -Path $outFile -Value “$i=$($InputObject[$i])”
        }
        else {
            #Sections
            Add-Content -Path $outFile -Value “[$i]”
            Foreach ($j in ($InputObject[$i].keys | Sort-Object)) {
                if ($j -match “^Comment[\d]+”) {
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

function Kill-RdConsole {

    # get appConsole process
    $appConsole = Get-Process OSLRDServer -ErrorAction SilentlyContinue
    if ($appConsole) {
        # try gracefully first
        Write-Host 'is AppConsole closed?'
        $appConsole.CloseMainWindow()
        # kill after five seconds
        Start-Sleep 3
        if (!$appConsole.HasExited) {
            $appConsole | Stop-Process -Force
            Write-Host 'AppConsole Killed'
        }
        
    }
    Remove-Variable appConsole
    
}

function Kill-RdService {

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
function Kill-OverOneMonitoring {

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

Write-Progress -Activity 'Starting' -Status 'Loading' -PercentComplete 0

#Path Services
$pathGp90 = Split-Path -Path (Get-AppPath('OSLRDServer'))
$pathOverOne = Split-Path -Path (Get-AppPath('OverOneMonitoringWindowsService'))

Write-Progress -Activity 'Starting' -Status 'Loading' -PercentComplete 20

#Path file
$pathInit = Join-Path -Path $pathGp90 -childpath (Get-ChildItem $pathGp90 -Filter ?nit.ini)
$pathLogOverOne =  Join-Path -Path ($pathOverOne + '\Log') -childpath (Get-ChildItem ($pathOverOne + '\Log' ) -Filter overOneMonitoringService.log)

Write-Progress -Activity 'Starting' -Status 'Loading' -PercentComplete 40

#Path exe
$pathConsole = join-Path -Path $pathGp90 -childpath '\AppConsole\OSLRDServer.exe'

Write-Progress -Activity 'Starting' -Status 'Loading' -PercentComplete 60

$iniDict = MEMInit $pathInit

Write-Progress -Activity 'Starting' -Status 'Loading' -PercentComplete 80

$IndirizzoIP = Get-NetIPAddress -InterfaceIndex (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -ne $null -and $_.NetAdapter.status -ne "Disconnected" }).InterfaceIndex

Write-Progress -Activity 'Starting' -Status 'Loading' -PercentComplete 100

FOR ($Conteggio = 0; $Conteggio = -1; $Conteggio++) {

    if ($iniDict.Config.segnaliSuTabella -eq -1) { Write-Host '  Segnali su Tabella Attivo' -ForegroundColor green } else { Write-Host '  Segnali su Tabella disattivo' -ForegroundColor Red }
    if ($iniDict.Config.UsoCollegamentoUnico -eq -1) { Write-Host '  Collegamento Unico Attivo' -ForegroundColor green } else { Write-Host '  Collegamento Unico disattivo' -ForegroundColor Red }

    Write-Host '
      Indirizzo IP inserito dentro INIT:'  $iniDict.Config.serverTCPListener

    # leggo Id sheda di rete attiva e reverso l'indirizzo ip e dettagli

    Write-Host '
      Indirizzi IP del PC attuali: ' $IndirizzoIP.IPAddress $IndirizzoIP.InterfaceAlias $IndirizzoIP.PrefixOrigin

    Write-Host " Inizializzazione dati completata----------------------------------------------------------------------" -ForegroundColor green
    Write-Host "                                                                                                  
    Funzionalità di controllo OSLRDServer e servizi annessi al Coll.Macchina, comandi in elenco qui sotto: 
    Digitare [C]onsole per avviare la modalita console                                              
    Digitare [S]ervice per avviare la modalita servizio                                             
    Digitare [K]ill per arrestare il servizio o console e OverOne                                   
    Digitare [O]verOne per riavviare il servizio OverOneMonitoring e cancellare il LOG              
    Digitare [TCP] Per modificare TCPListener All'interno del init                                  
    Digitare [E]dit per modificare INIT di OSLRDserver                                              
    Digitare [INIT] per la lettura del Init di OSLRDServer                                          
    Digitare [R]estricted, verfiicare stato restrizione policy esecuione script, ed impostarlo a REstricted
    " 
    
    $SCELTA = Read-Host -Prompt "   Digitare la LETTERA del COMANDO: "
    Write-Host ' '

    # [S]ervice per avviare la modalita servizio 
    if ($SCELTA -eq "s") {
        Kill-RdConsole
        Restart-Service  OSLRDServer
        Get-Service OSLRDServer
        start-sleep 3
        Clear-Host
    }

    #[C]onsole per avviare la modalita console
    if ($SCELTA -eq "c") { 
        Kill-RdConsole
        Kill-RdService
        Start-Process $pathConsole -Verb RunAs 
        start-sleep 3
        Clear-Host
    }

    #[K]ill per arrestare il servizio o console e OverOne             
    if ($SCELTA -eq "k") { 
        Kill-RdConsole
        Kill-RdService
        Kill-OverOneMonitoring      
        Write-Host "Servizi FERMI"
        start-sleep 3
        Clear-Host
    }
    if ($SCELTA -eq "o") {
        Kill-OverOneMonitoring
        Remove-Item -Path $pathLogOverOne -Force
        Start-Service  OverOneMonitoringWindowsService     
        TIMEOUT /t 5
        Start-Process $pathLogOverOne
        start-sleep 3
        Clear-Host
    }
    if ($SCELTA -eq "TCP") {       

        $IP = Read-Host -Prompt 'Inserisci IP da modificare '
        $iniDict.Config.serverTCPListener = $IP     
        # Salvo la modifica, scrivendola nel file 
        Write-INIT-OSLRDServer -ObjectCustom $iniDict -Directory $pathInit
        #Ricarico il file in memoria
        $iniDict = MEMInit $pathInit

    }
    if ($SCELTA -eq "INIT") {       
        Clear-Host
        notepad $pathInit
        Clear-Host
        pause   
        Clear-Host    
    }
    if ($SCELTA -eq "R") {       
        get-executionpolicy
        set-executionpolicy RemoteSigned    

        pause       
    }

    if ($SCELTA -eq "task") {       
        Get-CimInstance  -ClassName win32_service | Where-Object Name -eq OSLRDServer | Select-Object name, state,status, starttype
        Get-CimInstance  -ClassName win32_service | Where-Object Name -eq OSLProcessiService | Select-Object name, state,status, starttype
        Get-CimInstance  -ClassName win32_service | Where-Object Name -eq OverOneMonitoringWindowsService | Select-Object name, state,status, starttype
        Pause
        Clear-Host
    }
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
        Write-INIT-OSLRDServer -ObjectCustom $iniDict -Directory $pathInit
           

    }
    if ($SCELTA -eq "x") {          
        Exit
    }

}