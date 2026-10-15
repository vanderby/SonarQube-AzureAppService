# SonarQube-AzureAppService
This project is to facilitate hosting [SonarQube](https://www.sonarqube.org/) in an [Azure App Service](https://azure.microsoft.com/en-us/services/app-service/) directly. This does not require SonarQube to be in a Linux container. You can also use the same [HttpPlatformHandlerStartup.ps1](https://github.com/vanderby/SonarQube-AzureAppService/blob/master/HttpPlatformHandlerStartup.ps1) and [HttpPlatformHandler](https://docs.microsoft.com/en-us/iis/extensions/httpplatformhandler/httpplatformhandler-configuration-reference) extension to host SonarQube in IIS on a hosted machine. This would eliminate the need for more complicated setup of IIS as a reverse proxy.

This project uses the embedded database. It is recommended for production to move to a proper database (MSSQL, Oracle, MySQL, Postgre) which can also be a hosted in Azure.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvanderby%2FSonarQube-AzureAppService%2Fmaster%2Fazuredeploy.json)


## Azure Clouds
[Deploy to Azure Public Cloud](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvanderby%2FSonarQube-AzureAppService%2Fmaster%2Fazuredeploy.json)  
[Deploy to Azure US Government Cloud](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvanderby%2FSonarQube-AzureAppService%2Fmaster%2Fazuredeploy.json)   
[Deploy to Azure China Cloud](https://portal.azure.cn/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fvanderby%2FSonarQube-AzureAppService%2Fmaster%2Fazuredeploy.json)

## Getting Started
Use the ***Deploy to Azure*** button above to deploy out an Azure App Service along with the additional files from this project. SonarQube may take up to 10 minutes to start the first time. This will deploy out a Basic (B1) App Service and have SQ use an in-memory database.

## Passthrough Application Settings
You can set SonarQube sonar.properties settings based on the Azure application settings. Anything prefixed with sonar.* will at runtime be set in sonar.properties file if it matches a property there. This enables settings to be defined in the ARM template and set at runtime.

> Note: All entries in the sonar.properties file are commented out by the [HttpPlatformHandlerStartup](wwwroot/HttpPlatformHandlerStartup.ps1) script on startup. To change the Sonar properties add the application settings entry in the configuration blade (e.g. Name = sonar.jdbc.password; Value = XXXXX).

## In-Depth Details
After the ARM template is deployed a deployment script is executed to copy the wwwroot folder from the repository folder to the App Service wwwroot folder. It also finds the most recent release of SonarQube to download and extract into the App Service wwwroot folder.

The runtime execution is made possible by the [HttpPlatformHandler](https://docs.microsoft.com/en-us/iis/extensions/httpplatformhandler/httpplatformhandler-configuration-reference). This extension will start any executable and forward requests it receives onto the port defined in HTTP\_PLATFORM\_PORT environment variable. This port is randomly chosen at each invocation. A web.config file is used to tell the HttpPlatformHandler which file to execute and what parameters to pass along to the executing file.

 In order to make this work the [HttpPlatformHandlerStartup.ps1](https://github.com/vanderby/SonarQube-AzureAppService/blob/master/HttpPlatformHandlerStartup.ps1) script is executed by the HttpPlatformHandler. The script searches for the sonar.properties file and writes the port defined in the HTTP\_PLATFORM\_PORT environment variable to the properties file. It also writes the java.exe location to the wrapper.conf file. Finally it executes one of the StartSonar.bat file to start SonarQube.

### Logs cleanup web job
After installation, web app would be provided with logs cleanup web job, which would be removing all the logs older than 1 day (or value, specified in `LogsToKeep` app settings variable)

## Azure SQL
If you wish to switch SQ to use an Azure SQL database deploy out the database with a case-sensative collation (e.g.  SQL_Latin1_General_CP1_CS_AS) and update the Web App app settings with entries similar to: 

| Name | Value |
| ---- | ----- |
| sonar.jdbc.url | jdbc:sqlserver://AzureSQLDatabaseServer.database.windows.net:1433;database=DatabaseName;encrypt=true; |
| sonar.jdbc.username | SqlUserLogin |
| sonar.jdbc.password | SqlUserLoginPassword |

## Updating instructions

Before upgrading, check SonarSource's supported upgrade path (including any required intermediate releases), database compatibility, plugin compatibility, and Java requirements for the target version. Downloading a new archive does not upgrade the App Service Java runtime; ensure `JAVA_HOME` points to a supported Java installation.

Back up both the database and the existing `wwwroot` before proceeding. Do not run production and a staging slot against the same database during an upgrade. A slot alone is not a database backup.

1. Set application setting `SonarQubeOldVersion` to currently deployed version
1. Set application setting `SonarQubeVersion` to the exact new version to be deployed (not `Latest`), and verify `SonarQubeEdition` is unchanged (e.g. `Developer`)
1. Stop web app
1. Update `wwwroot\HttpPlatformHandlerStartup.ps1` with the current script from this repository
1. Download new zip archive by executing following scripts at Kudu (in most cases it is https://YOUR-WEB-APP-NAME.scm.azurewebsites.net/DebugConsole/?shell=powershell): 
```
    $Edition = $Env:SonarQubeEdition
    $Version = $Env:SonarQubeVersion
    $OldVersion = $Env:SonarQubeOldVersion
    if(!$Version -or ($Version -ieq 'Latest')) {
        # binaries.sonarsource.com moved to S3 and is not easily searchable anymore. Getting the latest version from GitHub releases.
        $releasesFromApi = (Invoke-WebRequest -Uri 'https://api.github.com/repos/SonarSource/sonarqube/releases' -UseBasicParsing).Content
        $releasesPS = $releasesFromApi | ConvertFrom-Json
        $Version = $releasesPS.Name | Sort-Object -Descending | Select-Object -First 1
        Write-Output "Found the latest release to be $Version"
    }

    if(!$Edition) {
        $Edition = 'Community'
    }

    $downloadFolder = 'Distribution/sonarqube' # Community Edition
    $fileNamePrefix = 'sonarqube' # Community Edition
    switch($Edition) {
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
    $wwwrootPath = "$env:Home\site\wwwroot"
    $outputFile = "$wwwrootPath\$fileName"
    Invoke-WebRequest -Uri $downloadUri -OutFile $outputFile -UseBasicParsing
    Expand-Archive -Path $outputFile -DestinationPath $wwwrootPath -Force
```
1. Install target-compatible versions of any third-party plugins in the new installation's `extensions\plugins` directory. Do not blindly copy all old JARs or overwrite bundled plugins. Use the actual extracted directory names: commercial archive names can differ from the directory names inside them.
```
Get-ChildItem "$env:Home\site\wwwroot" -Directory -Filter 'sonarqube-*'
```
1. Move the old installation outside `wwwroot` to retain it for recovery. Startup selects the exact `SonarQubeVersion`; if that setting is blank or `Latest`, only one installation may remain in `wwwroot`.
1. Keep database connection settings in App Service configuration (`sonar.jdbc.url`, `sonar.jdbc.username`, `sonar.jdbc.password`). Do not copy the old `sonar.properties`: startup resets it and applies matching `sonar.*` application settings.
1. Start web app
1. Browse to `https://YOUR-WEB-APP-NAME.azurewebsites.net/setup` and complete the database migration if requested. Wait for migration and startup to finish before sending normal traffic.

If the site reports “The specified CGI application encountered an error”, inspect the HttpPlatformHandler stdout logs in Kudu and the selected installation's `logs\sonar.log`, `logs\web.log`, and `logs\es.log`. The CGI message alone does not identify the cause; check these logs for unsupported Java, incompatible plugins, database connectivity, or a pending migration. Include the old/new SonarQube versions, Java version, and relevant log errors when requesting help, but redact credentials and connection secrets.

If recovery is necessary after a database migration, restore the matching database backup as well as the old installation; do not start an older SonarQube against an upgraded database. A separate staging database may require a separate commercial license; confirm licensing before testing.

## Alternative Hosting Methods
Some alternative hosting methods are below with the relevant links.

**Azure VM**  
<http://donovanbrown.com/post/how-to-setup-a-sonarqube-server-in-azure>  
<https://blogs.msdn.microsoft.com/visualstudioalmrangers/2016/10/06/easily-deploy-sonarqube-server-in-azure/>

**Azure App Service with a Linux Container**  
<https://azure.microsoft.com/en-us/resources/templates/webapp-linux-sonarqube-mysql/>

**Docker Image**  
<https://hub.docker.com/_/sonarqube/>

**IIS as a Reverse Proxy**  
<https://blogs.msdn.microsoft.com/visualstudioalmrangers/2016/06/04/running-sonarqube-behind-an-iis-reversed-proxy/>  
<https://jessehouwing.net/sonarqube-configure-ssl-on-windows/>
