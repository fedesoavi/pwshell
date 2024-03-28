Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/fedesoavi/pwshell/main/Funzionalita_HW.ps1')

(new-object net.webclient).DownloadFile('https://raw.githubusercontent.com/fedesoavi/pwshell/main/Funzionalita_HW.ps1','local.ps1')
./local.ps1 "test"