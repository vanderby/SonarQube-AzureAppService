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

These instructions apply to the Windows App Service installation deployed by this repository, not a Linux container. Changing the application settings alone does **not** download or install a new version.

Before starting, check SonarSource's [upgrade guide](https://docs.sonarsource.com/sonarqube-server/server-upgrade-and-maintenance/upgrade/upgrade-the-server/) for the supported upgrade path, database requirements, and plugin compatibility. Back up the database and App Service files before making changes. For an upgrade from 9.5 to 9.9, Java 17 is required; ensure the App Service's Java runtime is set to Java 17. Also ensure the deployed `HttpPlatformHandlerStartup.ps1` includes this repository's support for SonarQube 9.6 and later (`SONAR_JAVA_PATH`).

### 1. Save the application settings

In the Azure portal, open your existing **App Service → Configuration → Application settings** (or **Settings → Environment variables**, depending on the portal layout). Add or update these settings and save/apply the changes. For example, when upgrading Community Edition from 9.5 to 9.9:

| Name | Value |
| ---- | ----- |
| SonarQubeEdition | Community |
| SonarQubeOldVersion | 9.5.0.56709 |
| SonarQubeVersion | 9.9.0.65466 |

Use the full version numbers matching your installed and target distributions. Keep your existing `sonar.jdbc.*` settings so the new installation connects to the same database.

### 2. Stop SonarQube and open Kudu PowerShell

In the App Service **Overview**, select **Stop** and wait for the app to stop. Then open **Development Tools → Advanced Tools → Go** to launch Kudu, and select **Debug console → PowerShell**. You can also open `https://YOUR-WEB-APP-NAME.scm.azurewebsites.net/DebugConsole/?shell=powershell` directly, replacing `YOUR-WEB-APP-NAME` with your App Service name. Kudu is separate from the stopped web app and remains available.

Run the commands below in the **PowerShell command input at the bottom of the Kudu page**, not in Azure Cloud Shell, a local PowerShell window, or the App Service application-settings editor. For the short commands, paste one line at a time and press **Enter**. For the multiline download script, use the file-upload method in the next step.

### 3. Download and extract the new version

On your computer, copy the following block (without the Markdown backticks) into a text editor and save it as `Upgrade-SonarQube.ps1`, not `.ps1.txt`. In Kudu's file browser above the console, navigate to `site` → `wwwroot` and drag the saved file into the file listing to upload it. The script will run on the App Service, not on your computer.

```powershell
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
Execute the uploaded script by entering this command in Kudu PowerShell:

```powershell
& "$env:HOME\site\wwwroot\Upgrade-SonarQube.ps1"
```

It uses the saved application settings and absolute paths, so the console's current directory does not matter. Wait for it to finish without errors, then confirm that the new `sonarqube-<version>` folder exists under `$env:HOME\site\wwwroot`. If the environment variables still show the old settings, reopen Kudu after saving the settings before running the script again. Delete the uploaded `Upgrade-SonarQube.ps1` file through Kudu's file browser after use.

### 4. Install compatible plugins

Only copy plugins that support the target SonarQube version. Download compatible replacements for any incompatible plugins rather than copying them. If there are no custom plugins, skip this step. For compatible plugins, run in the same Kudu PowerShell console:

```powershell
$oldVersion = $env:SonarQubeOldVersion; 
$newVersion = $env:SonarQubeVersion; 
Copy-Item "$env:HOME\site\wwwroot\sonarqube-$oldVersion\extensions\plugins\*.jar" "$env:HOME\site\wwwroot\sonarqube-$newVersion\extensions\plugins\" -Force
```

### 5. Move the old installation out of wwwroot

The startup script searches recursively for SonarQube configuration and startup files. Do not leave both installations in `wwwroot`, even with the old folder renamed. Keep the old installation outside that directory as a backup:

```powershell
$oldVersion = $env:SonarQubeOldVersion
$backupPath = "$env:HOME\site\sonarqube-backups"
New-Item -ItemType Directory -Path $backupPath -Force
Move-Item -Path "$env:HOME\site\wwwroot\sonarqube-$oldVersion" -Destination $backupPath
```

Do not continue if any command fails. Verify that only the new SonarQube installation remains in `wwwroot`, alongside this repository's `web.config` and `HttpPlatformHandlerStartup.ps1`.

### 6. Start the app and complete the database upgrade

Return to the Azure portal and select **Start** in the App Service **Overview**. Allow several minutes for startup, then browse to `https://YOUR-WEB-APP-NAME.azurewebsites.net/setup` (or your custom hostname followed by `/setup`). Follow the SonarQube prompts to upgrade the database if requested. After completion, open the normal SonarQube URL, sign in, and verify the version, projects, and plugins.

If startup fails, inspect the new installation's `logs` folder through Kudu. To roll back after a database migration, stop the app and restore **both** the database backup and the matching old installation; simply changing `SonarQubeVersion` back does not roll back the database or select the old binaries.

For additional safety, rehearse the upgrade in a staging slot with a separate copy of the database. Do not let a staging slot upgrade the live production database. Check SonarSource's licensing requirements when testing a commercial edition against a copied database.

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
