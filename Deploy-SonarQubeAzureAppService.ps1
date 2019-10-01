﻿param(
    [string]$ApplicationInsightsApiKey = ''
)

function TrackTimedMetric {
    param (
        [Microsoft.ApplicationInsights.TelemetryClient]$Client,
        [string]$EventName,
        [scriptblock]$ScriptBlock,
        [Object[]]$ScriptBlockArguments
    )

    [System.Diagnostics.Stopwatch]$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ScriptBlockArguments
    $stopwatch.Stop()
    if($Client)
    {
        $metrics = New-Object 'System.Collections.Generic.Dictionary[[string],[double]]'
        $metrics.Add('duration (ms)', $stopwatch.ElapsedMilliseconds)
        $Client.TrackEvent($EventName, $null, $metrics)
    }
}

Write-Output 'Loading Telemetry Library'
$telemetryDllName = 'Microsoft.ApplicationInsights.dll'
$telemetryDllPath = Join-Path $PSScriptRoot $telemetryDllName -Resolve
$client = $null
if((Test-Path $telemetryDllPath) -and $ApplicationInsightsApiKey)
{
    Write-Output 'Telemetry client library found.'
    Add-Type -Path $telemetryDllPath
    $client = New-Object 'Microsoft.ApplicationInsights.TelemetryClient'
    $client.InstrumentationKey=$ApplicationInsightsApiKey
    $client.TrackTrace('Client Loaded.')
}

TrackTimedMetric -Client $client -EventName 'Download And Extract Binaries' -ScriptBlock {
    Write-Output 'Copy wwwroot folder'
    xcopy wwwroot ..\wwwroot /YI

    Write-Output 'Setting Security to TLS 1.2'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Output 'Prevent the progress meter from trying to access the console'
    $global:progressPreference = 'SilentlyContinue'
    
    Write-Output 'Getting a list of downloads'
    $downloadSource = 'https://binaries.sonarsource.com/Distribution/sonarqube/'
    $allDownloads = Invoke-WebRequest -Uri $downloadSource -UseBasicParsing
    $zipFiles = $allDownloads[0].Links | Where-Object { $_.href.EndsWith('.zip') -and !($_.href.contains('alpha') -or $_.href.contains('RC')) }

    # We sort by a custom expression so that we sort based on a version and not as a string. This results in the proper order given values such as 7.9.zip and 7.9.1.zip.
    #   In the expression we use RegEx to find the "Version.zip" string, then split and grab the first to get just the "Version" and finally cast that to a version object
    $sortedZipFiles = $zipFiles | Sort-Object -Property @{ Expression = { [Version]([RegEx]::Match($_.href, '\d+.\d+.?(\d+)?.zip').Value -Split ".zip")[0] } }
    $latestFile = $sortedZipFiles[-1]
    $downloadUri = $downloadSource + $latestFile.href

    Write-Output "Downloading '$downloadUri'"
    $outputFile = "..\wwwroot\$($latestFile.href)"
    Invoke-WebRequest -Uri $downloadUri -OutFile $outputFile -UseBasicParsing
    Write-Output 'Done downloading file'

    TrackTimedMetric -Client $client -EventName 'Extract Binaries' -ScriptBlockArguments $outputFile -ScriptBlock {
        param([string]$outputFile)
        Write-Output 'Extracting zip'
        Expand-Archive -Path $outputFile -DestinationPath '..\wwwroot' -Force
        Write-Output 'Extraction complete'
    }
}
