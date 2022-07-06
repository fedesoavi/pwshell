<#:: I primi 2 comandi servono per avviare da CMD la power Shell
Set-ExecutionPolicy RemoteSigned
PowerShell c:\path\to\script\PowerShellScript.ps1 #>

Function Check-RunAsAdministrator()
{
  #Get current user context
  $CurrentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  
  #Check user is running the script is member of Administrator Group
  if($CurrentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator))
  {
       Write-host "Script is running with Administrator privileges!"
  }
  else
    {
       #Create a new Elevated process to Start PowerShell
       $ElevatedProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
 
       # Specify the current script path and name as a parameter
       $ElevatedProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"
 
       #Set the Process to elevated
       $ElevatedProcess.Verb = "runas"
 
       #Start the new elevated process
       [System.Diagnostics.Process]::Start($ElevatedProcess)
 
       #Exit from the current, unelevated, process
       Exit
 
    }
}
 
#Check Script is running with Elevated Privileges
Check-RunAsAdministrator
 
#Place your script here.
write-host "Avviato Come ADMINISTRATOR"


#Read more: https://www.sharepointdiary.com/2015/01/run-powershell-script-as-administrator-automatically.html#ixzz7VjEmvkmn

$Conteggio = 0
FOR($Conteggio = -1){

$DO = Get-CimInstance -ClassName win32_service | Where-Object Name -eq "OSLRDServer" | SELECT PathName
$DO = ($DO -split "PathName="|  Select -last 1).Trim("}")

<#  Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin Dhcp | SELECT IPAddress
    


<# Parte di lettura del file  #>
cls
        $INIT = ($DO -REPLACE "OSLRDServerService.exe","init.ini") 
        ECHO "Lettura INIT OSLRDserver: "
        ECHO "-"
        ECHO "-"
        $SEL = Select-String -Path  $INIT -Pattern "SegnaliSuTabella=-1"
        $SEL2 = Select-String -Path $INIT -Pattern "UsoCollegamentoUnico=-1" 
        $SEL3 = Select-String -Path $INIT -Pattern "TCPListener=" 
        $SEL3 = ($SEL3 -split "TCPListener="|  Select -last 1)
        ECHO ("Indirizzo IP inserito dentro INIT: "+$SEL3)
        $ipv4 = (Get-NetIPAddress | Where-Object {$_.AddressState -eq "Preferred" -and $_.ValidLifetime -lt "24:00:00"}).IPAddress
        ECHO ( 'Indirizzo IP del PC attuale: '+$ipv4)

        if ($SEL -ne $null)
        {
            echo "Segnali su Tabella Attivo"
        }
        else
        {
            echo "Segnali su Tabella Disattivo"
        }

        if ($SEL2 -ne $null)
        {
            echo "UsoCollegamento Unico Attivo"
        }
        else
        {
            echo "Uso collegamento Unico Disattivo"
        }
 <# Fine parte di lettura  #>

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

      (Get-Content $INIT) -replace ("ServerTCPListener="+$SEL3), ('ServerTCPListener='+$IP) | Set-Content $INIT 

      pause
       
     }
     if ($SCELTA -eq "INIT"){       
      CLS
      $ourfilesdata = Get-Content $INIT
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
         $ini = @{}
           switch -regex -file $INIT
                {
                    “^\[(.+)\]” # Section
                    {
                        $section = $matches[1]
                        $ini[$section] = @{}
                        $CommentCount = 0
                    }
                    “^(;.*)$” # Comment
                    {
                        $value = $matches[1]
                        $CommentCount = $CommentCount + 1
                        $name = “Comment” + $CommentCount
                        $ini[$section][$name] = $value
                    }
                    “(.+?)\s*=(.*)” # Key
                    {
                        $name,$value = $matches[1..2]
                        $ini[$section][$name] = $value
                    }
                }
         
         FOR($Continuo = -1;$Continuo -lt 10;$Continuo++){
          Write-Host "Quale TAG del file INIT vuoi modificare ? " -ForegroundColor green   
           $ini.keys

           $TAG = Read-Host -Prompt "Quale vuoi modificare ? "
           Write-Host "Perfetto, il TAG contiene questi valori:  " -ForegroundColor green
           $ini[$TAG]

           Write-Host "Cosa vuoi modificare ? " -ForegroundColor green
           $MOD = Read-Host -Prompt "indica il TAG:  "
           #Write-Host "Valore ? " -ForegroundColor green
           $VAL = Read-Host -Prompt  "Quale Valore: "

           $ini[$TAG][$MOD] = $VAL
           CLS
           $ini[$TAG]
           $YESNO = Read-Host Prompt  "Continuare a fare delle modifiche ? [S/N]: "
               if($YESNO -ne 'S'){
                 $Continuo = 11
               }       
            #END FOR
         }
                # START WRITE
                $InputObject = $ini
                 Remove-Item -Path $INIT -Force
                $outFile = New-Item -ItemType file -Path $INIT
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