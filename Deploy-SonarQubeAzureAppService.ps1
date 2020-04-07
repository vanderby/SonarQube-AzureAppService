param(
    [string]$ApplicationInsightsApiKey = $Env:Deployment_Telemetry_Instrumentation_Key,
    [string]$Edition = $Env:SonarQubeEdition,
    [string]$Version = $Env:SonarQubeVersion
)

function TrackTimedEvent {
    param (
        [string]$InstrumentationKey,
        [string]$EventName,
        [scriptblock]$ScriptBlock,
        [Object[]]$ScriptBlockArguments
    )

    [System.Diagnostics.Stopwatch]$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ScriptBlockArguments
    $stopwatch.Stop()

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

        $measurements = @{
            'duration (ms)' = $stopwatch.ElapsedMilliseconds
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
                    measurements = $measurements;
				}
			};
        }

        Invoke-RestMethod -Method POST -Uri "https://dc.services.visualstudio.com/v2/track" -ContentType "application/json" -Body $body | out-null
    }
}

TrackTimedEvent -InstrumentationKey $ApplicationInsightsApiKey -EventName 'Download And Extract Binaries' -ScriptBlock {
    Write-Output 'Copy wwwroot folder'
    xcopy wwwroot ..\wwwroot /YI

    Write-Output 'Setting Security to TLS 1.2'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Output 'Prevent the progress meter from trying to access the console'
    $global:progressPreference = 'SilentlyContinue'
    
    if(!$Edition) {
        $Edition = 'Community'
    }

    Write-Output "Getting a list of downloads for $Edition edition."
    $downloadFolder = 'Distribution/sonarqube' # Community Edition
    switch($Edition) {
        'Developer' { $downloadFolder = 'CommercialDistribution/sonarqube-developer' }
        'Enterprise' { $downloadFolder = 'CommercialDistribution/sonarqube-enterprise' }
        'Data Center' { $downloadFolder = 'CommercialDistribution/sonarqube-datacenter' }
    }

    $downloadSource = "https://binaries.sonarsource.com/$downloadFolder"
    $downloadUri = ''
    $fileName = ''
    if(!$Version -or ($Version -ieq 'Latest')) {
        $allDownloads = Invoke-WebRequest -Uri $downloadSource -UseBasicParsing
        $zipFiles = $allDownloads[0].Links | Where-Object { $_.href.EndsWith('.zip') -and !($_.href.contains('alpha') -or $_.href.contains('RC')) }

        # We sort by a custom expression so that we sort based on a version and not as a string. This results in the proper order given values such as 7.9.zip and 7.9.1.zip.
        #   In the expression we use RegEx to find the "Version.zip" string, then split and grab the first to get just the "Version" and finally cast that to a version object
        $sortedZipFiles = $zipFiles | Sort-Object -Property @{ Expression = { [Version]([RegEx]::Match($_.href, '\d+.\d+.?(\d+)?.?(\d+)?.zip').Value -Split ".zip")[0] } }
        $latestFile = $sortedZipFiles[-1]
        $downloadUri = "$downloadSource/$($latestFile.href)"
        $fileName = $latestFile.href
    } else {
        $fileNamePart = 'sonarqube' # Community Edition
        switch($Edition) {
            'Developer' { $fileNamePart = 'sonarqube-developer' }
            'Enterprise' { $fileNamePart = 'sonarqube-enterprise' }
            'Data Center' { $fileNamePart = 'sonarqube-datacenter' }
        }

        $fileName = "$fileNamePart-$Version.zip"
        $downloadUri = "$downloadSource/$fileName"
    }

    if(!$downloadUri -or !$fileName) {
        throw 'Could not get download uri or filename.'
    }

    Write-Output "Downloading '$downloadUri'"
    $outputFile = "..\wwwroot\$fileName"
    Invoke-WebRequest -Uri $downloadUri -OutFile $outputFile -UseBasicParsing
    Write-Output 'Done downloading file'

    TrackTimedEvent -InstrumentationKey $ApplicationInsightsApiKey -EventName 'Extract Binaries' -ScriptBlockArguments $outputFile -ScriptBlock {
        param([string]$outputFile)
        Write-Output 'Extracting zip'
        Expand-Archive -Path $outputFile -DestinationPath '..\wwwroot' -Force
        Write-Output 'Extraction complete'
    }
}
