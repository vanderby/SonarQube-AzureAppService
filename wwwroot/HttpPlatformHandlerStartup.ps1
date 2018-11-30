function log($message) {
    [DateTime]$dateTime = [System.DateTime]::Now
    Write-Output "$($dateTime.ToLongTimeString()) $message" 
}

log('Starting HttpPlatformHandler Script')

$port = $env:HTTP_PLATFORM_PORT
log("HTTP_PLATFORM_PORT is: $port")

log("Searching for sonar.properties file")
$propFile = Get-ChildItem 'sonar.properties' -Recurse
if(!$propFile) {
    log("Could not find sonar.properties")
    exit
}

log("File found at: $($propFile.FullName)")
log("Writing to sonar.properties file")
$configContents = Get-Content -Path $propFile.FullName -Raw
$configContents -ireplace '#?sonar.web.port=.+', "sonar.web.port=$port" | Set-Content -Path $propFile.FullName

log("Searching for StartSonar.bat")
$startScript = Get-ChildItem 'StartSonar.bat' -Recurse
if(!$startScript) {
    log("Could not find StartSonar.bat")
    exit
}

log("File found at: $($startScript[-1].FullName)")
log("Executing StartSonar.bat")
& $startScript[-1].FullName