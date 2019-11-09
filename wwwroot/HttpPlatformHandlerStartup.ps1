param(
    [string]$ApplicationInsightsApiKey = $Env:Deployment_Telemetry_Instrumentation_Key
)

function log($message) {
    [DateTime]$dateTime = [System.DateTime]::Now
    Write-Output "$($dateTime.ToLongTimeString()) $message" 
}

function TrackEvent {
    param (
        [string]$InstrumentationKey,
        [string]$EventName
    )

    log($EventName)
    if($InstrumentationKey)
    {
        $uniqueId = ''
        if($Env:WEBSITE_INSTANCE_ID)
        {
            $uniqueId = $Env:WEBSITE_INSTANCE_ID.substring(5,15)
        }

        $properties = @{
            "Location" = $Env:REGION_NAME;
            "SKU" = $Env:WEBSITE_SKU;
            "Processor Count" = $Env:NUMBER_OF_PROCESSORS;
            "Always On" = $Env:WEBSITE_SCM_ALWAYS_ON_ENABLED;
            "UID" = $uniqueId
        }

        $body = ConvertTo-Json -Depth 5 -InputObject @{
			name = "Microsoft.ApplicationInsights.Dev.$InstrumentationKey.Event";
			time = [Datetime]::UtcNow.ToString("yyyy-MM-dd HH:mm:ss");
			iKey = $InstrumentationKey;
			data = @{
				baseType = "EventData";
				baseData = @{
					ver = 2;
					name = $EventName;
					properties = $properties;
				}
			};
        }

        Invoke-RestMethod -Method POST -Uri "https://dc.services.visualstudio.com/v2/track" -ContentType "application/json" -Body $body | out-null
    }
}

TrackEvent -InstrumentationKey $ApplicationInsightsApiKey -EventName 'Starting HttpPlatformHandler Script'

log('Searching for sonar.properties file')
$propFile = Get-ChildItem 'sonar.properties' -Recurse
if(!$propFile) {
    log('Could not find sonar.properties')
    exit
}
log("File found at: $($propFile.FullName)")
$configContents = Get-Content -Path $propFile.FullName

log('Resetting properties.')
$configContents = $configContents -ireplace '^#?sonar\.', '#sonar.'

log('Updating sonar.properties based on environment/application settings.')
Get-ChildItem Env: | Where-Object -Property Name -like -Value 'sonar.*' | ForEach-Object {
    $propertyName = $_.Name
    $propertyValue = $_.Value
    log("Setting $propertyName to $propertyValue")
    $configContents = $configContents -ireplace "^#?$propertyName=.*", "$propertyName=$propertyValue"
}

$port = $env:HTTP_PLATFORM_PORT
log("HTTP_PLATFORM_PORT is: $port")
log("Updating sonar.web.port to $port")
$configContents = $configContents -ireplace '^#?sonar\.web\.port=.*', "sonar.web.port=$port"

log('Saving updated sonar.properties contents')
$configContents | Out-String | Set-Content -Path $propFile.FullName -NoNewLine

log('Searching for wrapper.conf file')
$wrapperConfig = Get-ChildItem 'wrapper.conf' -Recurse
if(!$wrapperConfig) {
    log("Could not find wrapper.conf")
    exit
}

log("File found at: $($wrapperConfig.FullName)")
log("Writing to wrapper.conf file")	log('Updating wrapper.conf based on environment/application settings.')
$wrapperConfigContents = Get-Content -Path $wrapperConfig.FullName -Raw
$wrapperConfigContents -ireplace 'wrapper\.java\.command=.*', 'wrapper.java.command=%JAVA_HOME%\bin\java' | Set-Content -Path $wrapperConfig.FullName -NoNewLine

log('Searching for duplicate plugins.')
$plugins = Get-ChildItem '.\sonarqube-*\extensions\plugins\*' -Filter '*.jar'
$pluginBaseName = $plugins | ForEach-Object { $_.Name.substring(0, $_.Name.LastIndexOf('-')) }
$uniquePlugins = $pluginBaseName | Select-Object -Unique
$duplicates = Compare-Object -ReferenceObject $uniquePlugins -DifferenceObject $pluginBaseName
if($duplicates)
{
    log("Duplicates plugins found for: $($duplicates.InputObject)")a
    foreach($duplicate in $duplicates) { 
        $oldestFile = $plugins | Where-Object { $_.Name -imatch $duplicate.InputObject } | Sort-Object -Property 'LastWriteTime' | Select-Object -First 1
        log("Deleting $oldestFile")
        $oldestFile | Remove-Item
    }
}

log('Searching for StartSonar.bat')
$startScript = Get-ChildItem 'StartSonar.bat' -Recurse
if(!$startScript) {
    log('Could not find StartSonar.bat')
    exit
}

log("File found at: $($startScript[-1].FullName)")
log('Executing StartSonar.bat')
& $startScript[-1].FullName

TrackEvent -InstrumentationKey $ApplicationInsightsApiKey -EventName 'Exiting HttpPlatformHandler Script'