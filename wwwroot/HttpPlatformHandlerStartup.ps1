param(
    [string]$ApplicationInsightsApiKey = $Env:Deployment_Telemetry_Instrumentation_Key
)

function log($message) {
    [DateTime]$dateTime = [System.DateTime]::Now
    Write-Output "$($dateTime.ToLongTimeString()) $message" 
}

function TrackMetric {
    param (
        [Microsoft.ApplicationInsights.TelemetryClient]$Client,
        [string]$EventName
    )

    if($Client)
    {
        $properties = New-Object 'System.Collections.Generic.Dictionary[[string],[string]]'
        $properties.Add("Location", $Env:REGION_NAME)
        $properties.Add("SKU", $Env:WEBSITE_SKU)
        $properties.Add("Processor Count", $Env:NUMBER_OF_PROCESSORS)
        $properties.Add("Always On", $Env:WEBSITE_SCM_ALWAYS_ON_ENABLED)
        $Client.TrackEvent($EventName, $properties)
    }
}

log('Starting HttpPlatformHandler Script')

log('Loading Telemetry Library')
$telemetryDllName = 'Microsoft.ApplicationInsights.dll'
$telemetryDllPath = Join-Path $PSScriptRoot $telemetryDllName -Resolve
$client = $null
if((Test-Path $telemetryDllPath) -and $ApplicationInsightsApiKey)
{
    log('Telemetry client library found.')
    Add-Type -Path $telemetryDllPath
    $client = New-Object 'Microsoft.ApplicationInsights.TelemetryClient'
    $client.InstrumentationKey=$ApplicationInsightsApiKeys
}

TrackMetric -Client $client -EventName 'SQ Starting'

$port = $env:HTTP_PLATFORM_PORT
log("HTTP_PLATFORM_PORT is: $port")
log('Searching for sonar.properties file')
$propFile = Get-ChildItem 'sonar.properties' -Recurse
if(!$propFile) {
    log("Could not find sonar.properties")
    exit
}
log("File found at: $($propFile.FullName)")
log("Writing to sonar.properties file")
$configContents = Get-Content -Path $propFile.FullName -Raw
$configContents -ireplace '#?sonar.web.port=.+', "sonar.web.port=$port" | Set-Content -Path $propFile.FullName

log('Searching for wrapper.conf file')
$wrapperConfig = Get-ChildItem 'wrapper.conf' -Recurse
if(!$wrapperConfig) {
    log("Could not find wrapper.conf")
    exit
}
log("File found at: $($wrapperConfig.FullName)")
log("Writing to wrapper.conf file")
$wrapperConfigContents = Get-Content -Path $wrapperConfig.FullName -Raw
$wrapperConfigContents -ireplace 'wrapper.java.command=java', "wrapper.java.command=%JAVA_HOME%\bin\java" | Set-Content -Path $wrapperConfig.FullName

log("Searching for StartSonar.bat")
$startScript = Get-ChildItem 'StartSonar.bat' -Recurse
if(!$startScript) {
    log("Could not find StartSonar.bat")
    exit
}
log("File found at: $($startScript[-1].FullName)")
log("Executing StartSonar.bat")
& $startScript[-1].FullName