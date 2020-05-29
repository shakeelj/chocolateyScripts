# ***************************************************************************
# ***************************************************************************
# Variables

$releaseDir = Get-ChildItem "$toolsDir\app_code\$serverConf" -Recurse | Where-Object { $_.PSIsContainer -and $_.Name.StartsWith("CHART")}
$dateStr = "_$((Get-Date).ToString('yyyyMMddhhmm'))"
$archiveFolderName = "$releaseDir" + "$dateStr"
$webappInstallDir = $toolsDir + "\app_code\" + $serverConf + "\tomcat\webapps"

if (Test-Path "$toolsDir\app_code\$serverConf\tomcat\lib") {
	$libInstallDir = $toolsDir + "\app_code\" + $serverConf + "\tomcat\lib"
	} elseif (Test-Path "$toolsDir\app_code\$serverConf\tomcat\lib_atms") {
		$libInstallDir = $toolsDir + "\app_code\" + $serverConf + "\tomcat\lib_atms"
		}

# ***************************************************************************
# ***************************************************************************


# ***************************************************************************
# REWRITE THIS AS A CASE STATEMENT TO ERROR IF NO TOMCAT
# get location of tomcat install
# ***************************************************************************

write-host "Locating Tomcat home"
$tomcat9Key = 'HKLM:\SOFTWARE\Apache Software Foundation\Tomcat\9.0\Tomcat9'
$tomcat9Installed = (test-path $tomcat9Key)

if ($tomcat9Installed) {
	$tomcat9Home = (Get-ItemProperty -Path "$tomcat9Key" -Name InstallPath).InstallPath
	}


# ***************************************************************************
# Define webapps to update
# ***************************************************************************

$updateWebapps = (Get-ChildItem $webappInstallDir\*.war | Select-Object -ExpandProperty BaseName)

$webappFolders = @()

foreach ($app in $updateWebapps) {
	if (Test-Path "$tomcat9Home\webapps\$app") {
		#write-host "Webapp $app is found"
		$webappFolders += $app
		}
	}


# ***************************************************************************
# Archive any currently installed webapps and common library files
# ***************************************************************************

if ($webappFolders -And $stringName -ne 'neptune') {
	write-host "CHART Webapps found - Archiving"
	new-item -path $tomcat9Home -name $archiveFolderName -type directory
	foreach ($folder in $webappFolders) {
		move-item -path "$tomcat9Home\webapps\$folder" -destination $tomcat9Home\$archiveFolderName\$folder -force
		}
	
	write-host "Archiving CHART Libraries"
	new-item -path $tomcat9Home\$archiveFolderName -name "lib" -type directory

	if (Test-Path "$tomcat9Home\lib\jacorb.jar") {move-item -path "$tomcat9Home\lib\jacorb.jar" -destination "$tomcat9Home\$archiveFolderName\lib"}
	if (Test-Path "$tomcat9Home\lib\log4j-1.2.15.jar") {move-item -path "$tomcat9Home\lib\log4j-1.2.15.jar" -destination "$tomcat9Home\$archiveFolderName\lib"}
	if (Test-Path "$tomcat9Home\lib\logkit-1.2.jar") {move-item -path "$tomcat9Home\lib\logkit-1.2.jar" -destination "$tomcat9Home\$archiveFolderName\lib"}
	if (Test-Path "$tomcat9Home\lib\slf4j-api-1.5.6.jar") {move-item -path "$tomcat9Home\lib\slf4j-api-1.5.6.jar" -destination "$tomcat9Home\$archiveFolderName\lib"}
	if (Test-Path "$tomcat9Home\lib\slf4j-log4j12-1.5.6.jar") {move-item -path "$tomcat9Home\lib\slf4j-log4j12-1.5.6.jar" -destination "$tomcat9Home\$archiveFolderName\lib"}
	}


# ***************************************************************************
# Install new webapps
# ***************************************************************************

foreach ($app in $updateWebapps) {
	if (!(Test-Path "$tomcat9Home\webapps\$app")) {
		write-host "Updating $app"
		copy-item "$webappInstallDir\$app.war" "$tomcat9Home\webapps\$app.zip"
		Expand-Archive -Path "$tomcat9Home\webapps\$app.zip" -DestinationPath "$tomcat9Home\webapps\$app"
		
		# Reinstall archived admin files
		if (Test-Path "$tomcat9Home\$archiveFolderName\$app\AdminFiles") {
			write-host "Reinstalling archived Admin files for $app"
			copy-item -path "$tomcat9Home\$archiveFolderName\$app\AdminFiles" -destination "$tomcat9Home\webapps\$app" -recurse
			}
		
		# Remove unzipped webapp
		remove-item "$tomcat9Home\webapps\$app.zip"
		}
	}


# ***************************************************************************
# Install common library files to Tomcat/lib
# ***************************************************************************

write-host "Updating Tomcat library files"
copy-item "$libInstallDir\*.jar" "$tomcat9Home\lib"
