param(
    [string]$Edition = $Env:SonarQubeEdition,
    [string]$Version = $Env:SonarQubeVersion
)

Write-Output 'Copy wwwroot folder'
xcopy wwwroot ..\wwwroot /YI

Write-Output 'Setting Security to TLS 1.2'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Write-Output 'Prevent the progress meter from trying to access the console'
$global:progressPreference = 'SilentlyContinue'

if (!$Version -or ($Version -ieq 'Latest')) {
    # binaries.sonarsource.com moved to S3 and is not easily searchable anymore. Getting the latest version from GitHub releases.
    $releasesFromApi = (Invoke-WebRequest -Uri 'https://api.github.com/repos/SonarSource/sonarqube/releases' -UseBasicParsing).Content
    $releasesPS = $releasesFromApi | ConvertFrom-Json
    $Version = $releasesPS.Name | ForEach-Object { if ($_) { [version]$_ } } | Sort-Object -Descending | Select-Object -First 1
    Write-Output "Found the latest release to be $Version"
}

if (!$Edition) {
    $Edition = 'Community'
}

$downloadFolder = 'Distribution/sonarqube' # Community Edition
$fileNamePrefix = 'sonarqube' # Community Edition
switch ($Edition) {
    'Developer' {
        $downloadFolder = 'CommercialDistribution/sonarqube-developer'
        $fileNamePrefix = 'sonarqube-developer'
    }
    'Enterprise' {
        $downloadFolder = 'CommercialDistribution/sonarqube-enterprise'
        $fileNamePrefix = 'sonarqube-enterprise'
    }
    'Data Center' {
        $downloadFolder = 'CommercialDistribution/sonarqube-datacenter'
        $fileNamePrefix = 'sonarqube-datacenter'
    }
}

$fileName = "$fileNamePrefix-$Version.zip"
$downloadUri = "https://binaries.sonarsource.com/$downloadFolder/$fileName"

if (!$downloadUri -or !$fileName) {
    throw 'Could not get download uri or filename.'
}

Write-Output "Downloading '$downloadUri'"
$outputFile = "..\wwwroot\$fileName"
Invoke-WebRequest -Uri $downloadUri -OutFile $outputFile -UseBasicParsing
Write-Output 'Done downloading file'

Write-Output 'Extracting zip'
Expand-Archive -Path $outputFile -DestinationPath '..\wwwroot' -Force
Write-Output 'Extraction complete'
