Write-Host 'Querying For Web Apps'
Login-AzureRmAccount
$subscriptions = Get-AzureRmSubscription
$subscription = $null;
$inputSubscription = 0
if(!$subscriptions) {
    Write-Host 'No subscriptions found.'
    exit
} elseif ($subscriptions.Count -and ($subscriptions.Count -gt 1)) {
    for($i=0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "[$i] $($subscriptions[$i].Name)"
    }

    $inputSubscription = Read-Host 'Select the subscription to use'
    if ($inputSubscription -lt 0 -or $inputSubscription -gt $subscriptions.Count) {
        Write-Host 'Value is outside of expected range.'
        exit
    }
}

$subscription = $subscriptions[$inputSubscription]
Select-AzureRmSubscription $subscription
$webApps = Get-AzureRmWebApp
if(!$webApps) {
    Write-Host 'No web apps found.'
    exit
}

for($i=0; $i -lt $webApps.Count; $i++) {
    Write-Host "[$i] $($webApps[$i].Name)"
}

$input = Read-Host 'Select the web app to upload SonarQube to'
if ($input -lt 0 -or $input -gt $webApps.Count) {
    Write-Host 'Value is outside of expected range.'
    exit
}

$webApp = $webApps[$input]
Write-Host "  WebApp: '$($webApp.Name)' Resource Group: '$($webApp.ResourceGroup)'"

Write-Host 'Setting Security to TLS 1.2'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host 'Getting a list of downloads'
$downloadSource = 'https://binaries.sonarsource.com/Distribution/sonarqube/'
$allDownloads = Invoke-WebRequest -Uri $downloadSource
$zipFiles = $allDownloads.Links | Where-Object { $_.innerText.EndsWith('.zip') -and !($_.innerText.contains('alpha') -or $_.innerText.contains('RC')) }
$latestFile = $zipFiles[-1]
$downloadUri = $downloadSource + $latestFile.href

Write-Host "Downloading '$downloadUri'"
$outFile = '.\SonarQube.zip'
Invoke-WebRequest -Uri $downloadUri -OutFile $outFile

Write-Host 'Getting FTP Upload User Info'
$publishSettings = [xml](Get-AzureRmWebAppPublishingProfile -Name $webApp.Name -ResourceGroupName $webApp.ResourceGroup -OutputFile $null)
$website = $publishSettings.SelectSingleNode("//publishData/publishProfile[@publishMethod='MSDeploy']")
$username = $webSite.userName
$password = $webSite.userPWD

$apiUrl = "https://$($webApp.Name).scm.azurewebsites.net/api/zipdeploy"
Write-Host "Uploading Zip Deployment to '$apiUrl'"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $password)))
$userAgent = "powershell/1.0"
Invoke-RestMethod -Uri $apiUrl -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} -UserAgent $userAgent -Method POST -InFile $outFile -ContentType "multipart/form-data" -Verbose
Write-Host 'Upload Complete.'