# iwr -useb  | iex

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
        “^\[(.+)\]” { # Section
            $section = $matches[1]
            $init[$section] = @{}
            $CommentCount = 0
        }
        “^(;.*)$” { # Comment
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = “Comment” + $CommentCount
            $init[$section][$name] = $value
        }
        “(.+?)\s*=(.*)” { # Key
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


FOR ($Conteggio = 0; $Conteggio = -1; $Conteggio++) {

    $pathGp90 = Get-CimInstance -ClassName win32_service | Where-Object Name -eq "OSLRDServer" | Select-Object PathName 
    $pathGp90 = Split-Path -Path $pathGp90.PathName

    $pathInit = Join-Path -Path $pathGp90 -childpath (Get-ChildItem $pathGp90 -Filter ?nit.ini)

    $iniDict = MEMInit $pathInit

             

    if ($iniDict.Config.segnaliSuTabella -eq -1) { Write-Host '  Segnali su Tabella Attivo' -ForegroundColor green } else { Write-Host '  Segnali su Tabella disattivo' -ForegroundColor Red }
    if ($iniDict.Config.UsoCollegamentoUnico -eq -1) { Write-Host '  Collegamento Unico Attivo' -ForegroundColor green } else { Write-Host '  Collegamento Unico disattivo' -ForegroundColor Red }
    Write-Host ' '
    Write-Host '  Indirizzo IP inserito dentro INIT:'  $iniDict.Config.serverTCPListener
    Write-Host '  Indirizzo IP del PC attuale: ' (Get-NetIPAddress | Where-Object { $_.AddressState -eq "Preferred" -and $_.ValidLifetime -lt "24:00:00" }).IPAddress
    Write-Host ' '

    Write-Host " Inizializzazione dati completata----------------------------------------------------------------------" -ForegroundColor green
    Write-Host "                                                                                                "
    Write-Host " Funzionalità di controllo OSLRDServer e servizi annessi al Coll.Macchina, comandi in elenco qui sotto: "
    Write-Host ' '
    Write-Host " Digitare [C]onsole per avviare la modalita console                                              "
    Write-Host " Digitare [S]ervice per avviare la modalita servizio                                             "
    Write-Host " Digitare [K]ill per arrestare il servizio o console e OverOne                                   "
    Write-Host " Digitare [O]verOne per riavviare il servizio OverOneMonitoring e cancellare il LOG              "
    Write-Host " Digitare [TCP] Per modificare TCPListener All'interno del init                                  "
    Write-Host " Digitare [E]dit per modificare INIT di OSLRDserver                                              "
    Write-Host " Digitare [INIT] per la lettura del Init di OSLRDServer                                          "
    Write-Host " Digitare [R]estricted, verfiicare stato restrizione policy esecuione script, ed impostarlo a REstricted"
    Write-Host " "
    $SCELTA = Read-Host -Prompt "   Digitare la LETTERA del COMANDO: "


    if ($SCELTA -eq "s") { 
        TASKKILL /f /IM "OSLRDServer.exe"
        Start-Service  OSLRDServer

        pause
    }

    if ($SCELTA -eq "c") { 
        TASKKILL /f /IM "OSLRDServerService.exe"
        $pathEXERDServer = $pathGp90 + '\AppConsole\OSLRDServer.exe' 

        Start-Process $pathEXERDServer | Write-Host " Il Servizio è stato avviato in modalità console"

        Clear-Host

    }

    if ($SCELTA -eq "k") { 
        TASKKILL /f /IM "OSLRDServer.exe"
        TASKKILL /f /IM "OSLRDServerService.exe"
        TASKKILL /f /IM "OverOneMonitoringWindowsService.exe"

        Write-Host "Servizi FERMI"

        pause
    }
    if ($SCELTA -eq "o") {       


        TASKKILL /f /IM "OverOneMonitoringWindowsService.exe"
        Remove-Item -Path "C:\Program Files (x86)\OverOne\Services\Monitor\Log\overOneMonitoringService.log" -Force
        Start-Service  OverOneMonitoringWindowsService     
        TIMEOUT /t 10
        Start-Process "C:\Program Files (x86)\OverOne\Services\Monitor\Log\overOneMonitoringService.log"

        pause
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

        $ourfilesdata = Get-Content $pathInit
        $ourfilesdata

        pause       
    }
    if ($SCELTA -eq "R") {       
        get-executionpolicy
        set-executionpolicy RemoteSigned    

        pause       
    }

    if ($SCELTA -eq "task") {       
        
        Get-Service -Name OSLRDServer | Select-Object name, status, starttype
        Get-Service -Name OSLProcessiService | Select-Object name, status, starttype
        Get-Service -Name OverOneMonitoringWindowsService | Select-Object name, status, starttype

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

}