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

## Azure SQL
If you wish to switch SQ to use an Azure SQL database deploy out the database with a case-sensative collation (e.g.  SQL_Latin1_General_CP1_CS_AS) and update the Web App app settings with entries similar to: 

| Name | Value |
| ---- | ----- |
| sonar.jdbc.url | jdbc:sqlserver://AzureSQLDatabaseServer.database.windows.net:1433;database=DatabaseName;encrypt=true; |
| sonar.jdbc.username | SqlUserLogin |
| sonar.jdbc.password | SqlUserLoginPassword |

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
