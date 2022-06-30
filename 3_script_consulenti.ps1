Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
choco install adobereader  -y
choco install googlechrome  -y
choco install 7zip.install  -y
choco install notepadplusplus.install  -y
choco install winmerge  -y
choco install filezilla.server  -y
choco install spacesniffer -y
choco install vnc-viewer  -y
choco install vscode -y
choco install ultravnc -y
choco install greenshot -y