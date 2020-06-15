$ErrorActionPreference = 'Stop';
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$fileLocation = Join-Path $toolsDir 'app_code'
#$clearTrader = "False"

# set server string variable based on passed parameters
$pp = Get-PackageParameters

#if ($pp['ENV'] -eq 'true') {

	$stringName = $pp['ENV']
	$serverConf = $pp['CFG']
	$serviceCfg = $pp['STARTSERVICES']
	
	write-host $stringName
	write-host $serverConf
	write-host $serviceCfg
	
#}else{

#  $stringName = $env:COMPUTERNAME

#}

#if($env:COMPUTERNAME -match 'lcp1'){

#  $stringName = $env:COMPUTERNAME.ToLower()
#  $stringName = $stringname.Replace("lcp1"," ")

#}else{

#  $stringName = $env:COMPUTERNAME

#}

# Call script to clean up PATH entries - NOTE: THIS IS LAB SPECIFIC
Invoke-Expression "$toolsDir/scripts/cleanPath.ps1"

# Call script to stop services
Invoke-Expression "$toolsDir/scripts/stopServices.ps1"

# Call script to update services
Invoke-Expression "$toolsDir/scripts/updateServices.ps1"

# Call script to update webapps
Invoke-Expression "$toolsDir/scripts/updateWebapps.ps1"

# Call config script
Invoke-Expression "$toolsDir/conf/reconfigure-atms.ps1 -serverString $stringName"

#if ($pp['STARTSERVICES'] -eq 'true') {
if ($serviceCfg) {

	# Call script to start services
	Invoke-Expression "$toolsDir/scripts/startServices.ps1"

}
