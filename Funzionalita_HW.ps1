
# iwr -useb  | iex

If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
	Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
	Exit
}

$Conteggio = 0
FOR($Conteggio = -1){

$pathGp90 = Get-CimInstance -ClassName win32_service | Where-Object Name -eq "OSLRDServer" | Select-Object PathName 
$pathGp90 = Split-Path -Path $pathGp90.PathName

$pathInit = Join-Path -Path $pathGp90 -childpath (Get-ChildItem $pathGp90 -Filter ?nit.ini)

$iniDict = @{}
           switch -regex -file $pathInit
                {
                    “^\[(.+)\]” # Section
                    {
                        $section = $matches[1]
                        $iniDict[$section] = @{}
                        $CommentCount = 0
                    }
                    “^(;.*)$” # Comment
                    {
                        $value = $matches[1]
                        $CommentCount = $CommentCount + 1
                        $name = “Comment” + $CommentCount
                        $iniDict[$section][$name] = $value
                    }
                    “(.+?)\s*=(.*)” # Key
                    {
                        $name,$value = $matches[1..2]
                        $iniDict[$section][$name] = $value
                    }
                }


                Write-Host "Lettura INIT OSLRDserver:
                -
                -"

if ($iniDict.Config.segnaliSuTabella=-1) {Write-Host 'Segnali su Tabella Attivo'} else{Write-Host 'Segnali su Tabella disattivo'}
if ($iniDict.Config.UsoCollegamentoUnico=-1) {Write-Host 'UsoCollegamento Unico Attivo'} else{Write-Host 'UsoCollegamento Unico disattivo'}
Write-Host 'Indirizzo IP inserito dentro INIT:'  $iniDict.Config.serverTCPListener
Write-Host 'Indirizzo IP del PC attuale: ' (Get-NetIPAddress | Where-Object {$_.AddressState -eq "Preferred" -and $_.ValidLifetime -lt "24:00:00"}).IPAddress



ECHO " ---------------------------------------------------------------------------------------------- "

ECHO "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
ECHO "                                                                                                "
ECHO "Gestione avvii del servizio OSLRDServer, decidere le modalita seguendo le istruzioni qui sotto: "
ECHO "Digitare [C]onsole per avviare la modalita console                                              "
ECHO "Digitare [S]ervice per avviare la modalita servizio                                             "
ECHO "Digitare [K]ill per arrestare il servizio o console e OverOne                                   "
ECHO "Digitare [O]verOne per riavviare il servizio OverOneMonitoring e cancellare il LOG              "
ECHO "Digitare [TCP] Per modificare TCPListener All'interno del init                                  "
ECHO "Digitare [E]dit per modificare INIT di OSLRDserver                                              "
ECHO "Digitare [INIT] per la lettura del Init di OSLRDServer                                          "
ECHO "Digitare [R]estricted, per riabilitare le restrizioni sugli Script                              "
ECHO " "
$SCELTA = Read-Host -Prompt "indicami che cosa vuoi fare ? "


    if ($SCELTA -eq "s"){ 
       TASKKILL /f /IM "OSLRDServer.exe"
        Start-Service  OSLRDServer
        
    pause
    }

    if ($SCELTA -eq "c"){ 
    TASKKILL /f /IM "OSLRDServerService.exe"
    $DO = ($DO -REPLACE "OSLRDServerService.exe","AppConsole\OSLRDServer.exe")   

    start $DO | ECHO " Il Servizio è stato avviato in modalità console"
    
    }

    if ($SCELTA -eq "k"){ 
       TASKKILL /f /IM "OSLRDServer.exe"
       TASKKILL /f /IM "OSLRDServerService.exe"
       TASKKILL /f /IM "OverOneMonitoringWindowsService.exe"

       ECHO "Servizi FERMI"
      
       pause
     }
      if ($SCELTA -eq "o"){       


       TASKKILL /f /IM "OverOneMonitoringWindowsService.exe"
       Remove-Item -Path "C:\Program Files (x86)\OverOne\Services\Monitor\Log\overOneMonitoringService.log" -Force
       Start-Service  OverOneMonitoringWindowsService     
       TIMEOUT /t 10
        start "C:\Program Files (x86)\OverOne\Services\Monitor\Log\overOneMonitoringService.log"

       pause
     }
      if ($SCELTA -eq "TCP"){       

      $IP = Read-Host -Prompt 'Inserisci IP da modificare '

      (Get-Content $INIDictT) -replace ("ServerTCPListener="+$SEL3), ('ServerTCPListener='+$IP) | Set-Content $INIDictT 

      pause
       
     }
     if ($SCELTA -eq "INIT"){       
      CLS
      $ourfilesdata = Get-Content $INIDictT
      $ourfilesdata

      pause       
     }
     if ($SCELTA -eq "R"){       
      get-executionpolicy
      set-executionpolicy RemoteSigned    

      pause       
     }

      if ($SCELTA -eq "task"){       
         CLS
          Get-Service -Name OSLRDServer |Select name,status,starttype
          Get-Service -Name OSLProcessiService |Select name,status,starttype
          Get-Service -Name OverOneMonitoringWindowsService |Select name,status,starttype
      }
       if ($SCELTA -eq "E"){ 
         $iniDict = @{}
           switch -regex -file $INIDictT
                {
                    “^\[(.+)\]” # Section
                    {
                        $section = $matches[1]
                        $iniDict[$section] = @{}
                        $CommentCount = 0
                    }
                    “^(;.*)$” # Comment
                    {
                        $value = $matches[1]
                        $CommentCount = $CommentCount + 1
                        $name = “Comment” + $CommentCount
                        $iniDict[$section][$name] = $value
                    }
                    “(.+?)\s*=(.*)” # Key
                    {
                        $name,$value = $matches[1..2]
                        $iniDict[$section][$name] = $value
                    }
                }
         
         FOR($Continuo = -1;$Continuo -lt 10;$Continuo++){
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
           CLS
           $iniDict[$TAG]
           $YESNO = Read-Host Prompt  "Continuare a fare delle modifiche ? [S/N]: "
               if($YESNO -ne 'S'){
                 $Continuo = 11
               }       
            #END FOR
         }
                # START WRITE
                $InputObject = $iniDict
                 Remove-Item -Path $INIDictT -Force
                $outFile = New-Item -ItemType file -Path $INIDictT
                foreach ($i in $InputObject.keys)
                {
                    if (!($($InputObject[$i].GetType().Name) -eq “Hashtable”))
                    {
                        #No Sections
                        Add-Content -Path $outFile -Value “$i=$($InputObject[$i])”
                    } else {
                        #Sections
                        Add-Content -Path $outFile -Value “[$i]”
                        Foreach ($j in ($InputObject[$i].keys | Sort-Object))
                        {
                            if ($j -match “^Comment[\d]+”) {
                                Add-Content -Path $outFile -Value “$($InputObject[$i][$j])”
                            } else {
                                Add-Content -Path $outFile -Value “$j=$($InputObject[$i][$j])”
                            }

                        }
                        Add-Content -Path $outFile -Value “”
                    }
                 } # END WRITE
      
     }



$Conteggio = $Conteggio +1
}