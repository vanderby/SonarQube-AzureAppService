Write-Output 'Setting Security to TLS 1.2'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Output 'Prevent the progress meter from trying to access the console mode'
$ProgressPreference = "SilentlyContinue"

Write-Output 'Getting a list of downloads'
$downloadSource = 'https://binaries.sonarsource.com/Distribution/sonarqube/'
$allDownloads = Invoke-WebRequest -Uri $downloadSource -UseBasicParsing
$zipFiles = $allDownloads[0].Links | Where-Object { $_.href.EndsWith('.zip') -and !($_.href.contains('alpha') -or $_.href.contains('RC')) }
$latestFile = $zipFiles[-1]
$downloadUri = $downloadSource + $latestFile.href

Write-Output "Downloading '$downloadUri'"
Invoke-WebRequest -Uri $downloadUri -OutFile $latestFile.href -UseBasicParsing
Write-Output 'Done downloading file'

Write-Output 'Extracting zip'
Expand-Archive $latestFile.href -DestinationPath .
Write-Output 'Extraction complete'