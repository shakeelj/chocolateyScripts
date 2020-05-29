@echo off
setlocal enabledelayedexpansion

REM ***************************************************************************
REM This script installs the webapps from the installation medium to the target host.
REM It can either perform an immediate installation of the webapps, or a delayed
REM installation, based on the answer to a prompt question.
REM
REM An immediate installation will stop Tomcat and will move the existing webapps
REM to the tomcat\archive_<date>_<time> directory.  It will then copy the new
REM webapp WAR files to the tomcat\webapps directory, expand them, and (if all goes well)
REM delete the WAR files. This script also
REM copies any service ID files from the old webapps directories.
REM
REM A delayed installation will copy the install files (including this script)
REM to the tomcat\install_atms directory, so that this script can be run later
REM from that directory.  An immediate installation (as described above)
REM can be done from that directory at a later time.  When doing a delayed install,
REM it prompts you whether to expand the WAR files immediately within the staging
REM directory, which may be useful for comparing the configuration against
REM the currently running services and/or modifying the props files if needed,
REM BEFORE doing the final install.  When the final install is done, if any
REM webapp directories are expanded in the staging dir, those are copied from
REM the staging area (instead of the WAR files) so that any configuration changes
REM made in the staging dir will be used.
REM
REM After the webapps and other files are copied, it prompts whether to start Tomcat.
REM ***************************************************************************

set "TOMCAT_DIR=e:\tomcat"
set "DELAYED_INSTALL_DIR=%TOMCAT_DIR%\install_atms\CHART R22.0.0"
set "GUI_WEBAPP_NAME=chartlite"
set "TOMCAT_SCM_NAME=Tomcat9"

REM ***************************************************************************
REM If we are in the delayed install dir, set the IS_DELAYED_INSTALL variable for later use.
REM ***************************************************************************

set "IS_DELAYED_INSTALL="

if /i "%CD%" EQU "%DELAYED_INSTALL_DIR%" (
   set "IS_DELAYED_INSTALL=true"
)


echo.

if not defined IS_DELAYED_INSTALL (
   echo This script installs the CHART ATMS web applications to the target host.
   echo It can do either an immediate install or just copy files for a future install.
) else (
   echo This script installs the CHART ATMS web applications.
)

echo.


REM ***************************************************************************
REM First verify that the Tomcat dir on the target host actually exists.
REM (Even if it was correctly set in the server config file previously, it could have changed on the
REM target host if someone installed Tomcat in another location or changed drives).
REM ***************************************************************************

if not exist "%TOMCAT_DIR%\webapps" (
   echo The Tomcat directory "%TOMCAT_DIR%" does not exist or is not valid.
   echo Aborting webapps install.
   pause
   exit /B 1
)


REM ***************************************************************************
REM Make sure it's executed from a directory containing the installation files
REM (either from the installation medium, or from the delayed install dir)
REM ***************************************************************************

REM Check that we're in an install directory, although this isn't rigorous.
REM If we aren't some files should fail to copy.

if not exist install_webapps.cmd (
   echo This script must be run from an installation directory.
   echo Aborting webapps install.
   pause
   exit /B 1
)

REM Save the current directory for use when we are in other directories.
set "SCRIPT_STARTING_DIR=%CD%"


REM ***************************************************************************
REM Make the user confirm that they want to perform an immediate install.
REM If not, and if we are still in the installation medium directory, copy
REM the files to a delayed installation directory under Tomcat.
REM This is helpful if you do not want to stop Tomcat immediately or alter
REM the web services, as may be the case for a production install when the
REM files are copied early.
REM ***************************************************************************

set "INSTALLER_FILES_SUBDIR=installer_files"
set "DELAYED_INSTALL_DIR_INSTALLER_FILES=%DELAYED_INSTALL_DIR%\%INSTALLER_FILES_SUBDIR%"

echo.


set "OPT_DELAYED_INSTALL_INSTRUCTION="

if not defined IS_DELAYED_INSTALL (
   set "OPT_DELAYED_INSTALL_INSTRUCTION= ('N' for staged / future install)"
)


choice   /m "STOP !TOMCAT_SCM_NAME! and install webapps NOW?%OPT_DELAYED_INSTALL_INSTRUCTION%"

if %ERRORLEVEL% GEQ 2 (

   REM If we are already running this from the delayed install directory, don't try to copy the files again.

   if not defined IS_DELAYED_INSTALL (

      REM Copy the files to the target host delayed install directory to be installed later.

      if exist "%DELAYED_INSTALL_DIR%" rd /q /s "%DELAYED_INSTALL_DIR%"

      if not exist "%DELAYED_INSTALL_DIR%" (

         mkdir "%DELAYED_INSTALL_DIR%"
         mkdir "%DELAYED_INSTALL_DIR_INSTALLER_FILES%"
         copy install_webapps.cmd "%DELAYED_INSTALL_DIR%"
         copy "%INSTALLER_FILES_SUBDIR%\expand_wars.cmd" "%DELAYED_INSTALL_DIR_INSTALLER_FILES%"
         copy "%INSTALLER_FILES_SUBDIR%\Unzip.exe" "%DELAYED_INSTALL_DIR_INSTALLER_FILES%"
         xcopy "tomcat\*" "%DELAYED_INSTALL_DIR%\tomcat" /s /e /i

         echo.
         echo.
         echo Copied files ^(for future installation^) to:
         echo    !DELAYED_INSTALL_DIR!
         echo.

         echo It may be useful to expand the WAR files now ^(within the staging directory^)
         echo to allow you to compare the configuration against the currently running webapps
         echo so you can make any modifications before performing the final install.
         echo.

         choice   /m "Expand WARs NOW"

         if !ERRORLEVEL! EQU 1 (

            echo.
            pushd "%DELAYED_INSTALL_DIR_INSTALLER_FILES%"
            call expand_wars.cmd "%DELAYED_INSTALL_DIR%\tomcat\webapps"
            popd

         )

         echo.
         echo When you are ready for final installation, change to the following
         echo directory and run the script install_webapps.cmd ^(as Administrator^):
         echo.
         echo    !DELAYED_INSTALL_DIR!

      ) else (

         echo ERROR: The delayed install directory already exists but could not
         echo        be removed.  A process may be using it ^(or a file it contains^).
         echo        Resolve the issue with the following directory:
         echo.
         echo        !DELAYED_INSTALL_DIR!
         echo.
         echo        After the issue is resolved, run this script again.
      )

   ) else (

      REM It IS a delayed install, but the user chose to not perform the final install at this time.

      echo Webapps installation aborted.
      echo Run this script again when you are ready for final install.

   )

   echo.
   pause
   exit /B 1
)


REM ***************************************************************************
REM Check if the specified Tomcat sevice actually exists.
REM ***************************************************************************

for /F "tokens=*" %%H in ('sc query "!TOMCAT_SCM_NAME!" ^| findstr /c:"does not exist"') do (
   echo.
   echo ERROR:  The service !TOMCAT_SCM_NAME! does not exist.
   echo         Tomcat is either not installed, or may be a different version than
   echo         specified in the server configuration file for this box.
   echo.
   echo         If a different version of Tomcat is installed,
   echo         please stop it now ^(manually^).
   echo.

   pause
)


REM ***************************************************************************
REM Stop Tomcat, if it is not already stopped.
REM We need to make sure this is successful before continuing - otherwise it
REM will still be using the webapps directories.
REM ***************************************************************************

for /F "tokens=3 delims=: " %%H in ('sc query "!TOMCAT_SCM_NAME!" ^| findstr "STATE"') do (
   if /I "%%H" NEQ "STOPPED" (

      echo Stopping Tomcat...
      net stop "!TOMCAT_SCM_NAME!"

      IF ERRORLEVEL 2 (
         echo Error stopping Tomcat.  If Tomcat is running, you must either run
         echo this script as an Administrator or stop Tomcat manually and run
         echo this script again.
         pause
         exit /B 1
      )

      for /F "tokens=3 delims=: " %%Z in ('sc query "!TOMCAT_SCM_NAME!" ^| findstr "STATE"') do (
         if /I "%%Z" NEQ "STOPPED" (
            echo Error stopping Tomcat.  If Tomcat is running, stop Tomcat manually
            echo and run this script again.
            pause
            exit /B 1
         )
      )

      echo Waiting a few seconds for Tomcat to release control of the files / directories
      echo so this script can move them.
      echo.
      timeout 15
   )
)


REM ***************************************************************************
REM Create an archive directory under Tomcat/temp
REM By using the current date/time in the dir name, it should ensure that the
REM directory does not already exist.
REM ***************************************************************************

set hr=%time:~0,2%
if "%hr:~0,1%" equ " " set hr=0%hr:~1,1%
set "ARCHIVE_SUBDIR=archive_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%hr%%time:~3,2%%time:~6,2%"
set "ARCHIVE_DIR_BASE=%TOMCAT_DIR%\temp"
set "ARCHIVE_DIR=%ARCHIVE_DIR_BASE%\%ARCHIVE_SUBDIR%"
set "WEBAPPS_ARCHIVE_DIR=%ARCHIVE_DIR%\webapps"
set "ARCHIVE_SUBDIRS_FILESPEC=archive_*_*"

mkdir "%WEBAPPS_ARCHIVE_DIR%"


REM ***************************************************************************
REM Move the webapp dirs and WAR files to the newly-created archive directory.
REM Although we hope the files / directories are no longer in use,
REM some of them could be, in which case this could fail to move some of the
REM directories.
REM ***************************************************************************

set "MOVE_OLD_WEBAPPS_ERROR="

if exist "%TOMCAT_DIR%\webapps" (

   pushd "%TOMCAT_DIR%\webapps"

   REM Iterate through all of the existing Tomcat webapp subdirs

   for /d %%X in (*.*) do (

      set "MOVE_WEBAPP="
      set "WEBAPP_NAME=%%~nxX"

      REM If the corresponding webapp subdir or WAR file exists in the installation medium
      REM or staging dir, we absolutely do need to move the existing webapp.

      if exist "!SCRIPT_STARTING_DIR!" (

         pushd "!SCRIPT_STARTING_DIR!"

         if exist "tomcat\webapps\!WEBAPP_NAME!" (
            set "MOVE_WEBAPP=true"
         )

         if exist "tomcat\webapps\!WEBAPP_NAME!.war" (
            set "MOVE_WEBAPP=true"
         )

         popd
      )


      REM If it wasn't one of the webapps we're trying to install,
      REM it may be either one of Tomcat's default webapps, another CHART ATMS webapp,
      REM or some entirely different webapp.  Unless it's a Tomcat webapp we need to
      REM ask whether to move it.

      if not defined MOVE_WEBAPP (

         REM Assume we do need to prompt, unless we recognize it as one of the Tomcat defaults

         set "PROMPT_TO_MOVE_WEBAPP=true"

         if /i "!WEBAPP_NAME!" == "ROOT" (
            set "PROMPT_TO_MOVE_WEBAPP="
         )

         if /i "!WEBAPP_NAME!" == "manager" (
            set "PROMPT_TO_MOVE_WEBAPP="
         )

         if defined PROMPT_TO_MOVE_WEBAPP (

            echo.
            echo The existing webapp: !WEBAPP_NAME! is NOT one of the ones
            echo this script needs to install / update, but IF the existing one could
            echo cause conflicts with the new webapps, it may need to be moved.
            echo.

            choice   /m "Move existing webapp !WEBAPP_NAME!"

            if !ERRORLEVEL! EQU 1 (
               set "MOVE_WEBAPP=true"
            )

            echo.
         )
      )

      if defined MOVE_WEBAPP (

         REM Call a soubroutine to move the specified web application directory and/or WAR file.
         REM If the webapp dir or WAR file exists but could not be moved, it echoes an error message
         REM and sets the value of the MOVE_OLD_WEBAPPS_ERROR variable.

         call :moveExistingWebapp "!WEBAPP_NAME!"
      )
   )

   popd

   if defined MOVE_OLD_WEBAPPS_ERROR (
      echo.
      echo One or more errors occurred when moving the old webapps to the directory:
      echo.
      echo    !WEBAPPS_ARCHIVE_DIR!
      echo.
      echo Manually resolve any problems and move the old webapps to this directory
      echo now, before proceeding.
      echo.
      pause
   )
)

REM ***************************************************************************
REM Ask whether to remove old logs
REM ***************************************************************************

choice   /m "Remove old logfiles"

if !ERRORLEVEL! EQU 1 (

   REM Remove log files from the Tomcat directories

   if exist "%TOMCAT_DIR%\bin\log*" del /q "%TOMCAT_DIR%\bin\log*"
   del /q "%TOMCAT_DIR%\logs\*"


   REM Remove log files from the archive directory

   pushd "%WEBAPPS_ARCHIVE_DIR%"

   for /d %%X in (*.*) do (

      if exist "%%~nxX\LogFiles"  (
         rd /s /q "%%~nxX\LogFiles"
      )
   )

   if exist "TestGISLaneConfigService\xml_output" rd /s /q "TestGISLaneConfigService\xml_output"
   if exist "CHARTExportClientService\xml-archive-test" rd /s /q "CHARTExportClientService\xml-archive-test"

   popd


   REM Remove log files from the Tomcat webapps directories

   pushd "%TOMCAT_DIR%\webapps"

   for /d %%X in (*.*) do (

      if exist "%%~nxX\LogFiles"  (
         rd /s /q "%%~nxX\LogFiles"
      )
   )

   if exist "TestGISLaneConfigService\xml_output" rd /s /q "TestGISLaneConfigService\xml_output"
   if exist "CHARTExportClientService\xml-archive-test" rd /s /q "CHARTExportClientService\xml-archive-test"

   popd
)


REM ***************************************************************************
REM Ask whether to remove archive dirs older than the current one.
REM ***************************************************************************

set "OLD_ARCHIVE_SUBDIRS_EXIST="

pushd "%ARCHIVE_DIR_BASE%"

for /d %%X in ("%ARCHIVE_SUBDIRS_FILESPEC%") do (

   if "%%X" NEQ "%ARCHIVE_SUBDIR%" (

      set "OLD_ARCHIVE_SUBDIRS_EXIST=true"
   )
)


if defined OLD_ARCHIVE_SUBDIRS_EXIST (

   echo.
   echo One or more older archive directories exist ^(other than the one just created:
   echo !ARCHIVE_DIR!^).
   echo This script can delete them now, if desired.
   echo.

   for /d %%X in ("%ARCHIVE_SUBDIRS_FILESPEC%") do (

      if "%%X" NEQ "%ARCHIVE_SUBDIR%" (

         choice   /m "Remove archive dir: %%X"

         if !ERRORLEVEL! == 1 (

            rd /s /q "%%X"
         )
      )
   )
)

popd


REM ***************************************************************************
REM Move the common library files from Tomcat/lib to the archive dir
REM NOTE: This is temporary code, to remove the Java 8 ATMS installation files.
REM       For Java 11 and higher, we are no longer using the lib directory for shared libs.
REM ***************************************************************************

set "LIB_ARCHIVE_DIR=%ARCHIVE_DIR%\lib"

if exist "%TOMCAT_DIR%\lib\jacorb.jar" (
   mkdir "!LIB_ARCHIVE_DIR!"

   move "!TOMCAT_DIR!\lib\jacorb.jar" "!LIB_ARCHIVE_DIR!"
   move "!TOMCAT_DIR!\lib\log4j-1.2.15.jar" "!LIB_ARCHIVE_DIR!"
   move "!TOMCAT_DIR!\lib\logkit-1.2.jar" "!LIB_ARCHIVE_DIR!"
   move "!TOMCAT_DIR!\lib\slf4j-api-1.7.30.jar" "!LIB_ARCHIVE_DIR!"
   move "!TOMCAT_DIR!\lib\slf4j-log4j12-1.7.30.jar" "!LIB_ARCHIVE_DIR!"
)


REM ***************************************************************************
REM Move the common library files from Tomcat/lib_atms to the archive dir
REM Applies to Java 11 and higher installations.
REM ***************************************************************************

set "LIB_ATMS_ARCHIVE_DIR=%ARCHIVE_DIR%\lib_atms"

if exist "%TOMCAT_DIR%\lib_atms" (
   mkdir "!LIB_ATMS_ARCHIVE_DIR!"
   move "!TOMCAT_DIR!\lib_atms\*.jar" "!LIB_ATMS_ARCHIVE_DIR!"
)


REM ***************************************************************************
REM Verify that the webapp directories or WAR files do NOT already exist
REM under Tomcat for the webapps we are trying to install.  If they do,
REM abort installation to avoid a mess such as a mixture of old webapp dirs
REM and new WAR files, or a mixture of old and new webapp dirs.
REM ***************************************************************************

set "TOMCAT_WEBAPP_ALREADY_EXISTS_ERROR="

pushd tomcat\webapps

REM First check subdirectories, then check WAR files without corresponding subdirectories

for /d %%X in (*.*) do (
   call :verifyDestinationWebappDoesNotExist "%%~nxX"
)

for %%X in (*.war) do (
   if not exist "%%~nX" (
      call :verifyDestinationWebappDoesNotExist "%%~nX"
   )
)

popd


if defined TOMCAT_WEBAPP_ALREADY_EXISTS_ERROR (

   echo.
   echo Some webapp directories and/or WAR files already exist under
   echo the destination Tomcat webapps directory for webapps that we need to install.
   echo.
   echo You will need to resolve this problem before installation can proceed.
   echo Please make sure nothing is using them, and manually move them to the
   echo archive directory:
   echo.
   echo    !WEBAPPS_ARCHIVE_DIR!
   echo.
   echo Aborting installation to prevent a potential confusion that could happen
   echo if some webapps and/or WAR files could be copied but others were old.
   echo.
   echo No files were copied to the Tomcat directory.
   echo.

   pause
   exit /B 1
)


REM ***************************************************************************
REM Copy the common library files from the installation medium to the target host
REM ***************************************************************************

if not exist "%TOMCAT_DIR%\lib_atms" mkdir "%TOMCAT_DIR%\lib_atms"
copy tomcat\lib_atms\*.jar "%TOMCAT_DIR%\lib_atms"


REM ***************************************************************************
REM Copy any webapp subdirectories from the installation medium / staging dir
REM to Tomcat\webapps on the target host.  The webapps may have been expanded
REM previously in the staging dir for comparison purposes, especially for a
REM delayed install.
REM ***************************************************************************

pushd tomcat\webapps

for /d %%X in (*.*) DO (

   echo.
   echo Copying webapp subdirectory: %%~nxX
   xcopy "%%~nxX" "%TOMCAT_DIR%\webapps\%%~nxX" /s /i /q

)

popd


REM ***************************************************************************
REM Copy the WAR files from the installation medium to the target host,
REM except if the corresponding expanded subdirectory exists, as we just
REM attempted to copy those subdirectories / WARs above.
REM ***************************************************************************

pushd tomcat\webapps

for %%X in (*.war) do (

   REM Do not copy the WAR file if the corresponding subdirectory exists
   REM on the installation medium / staging dir, as we have already copied those subdirectories
   REM above, and they take precedence over the WAR files since config files
   REM in the subdirectories may have been modified.

   if not exist "%%~nX" (

      echo.
      echo Copying WAR file: %%~nX
      copy "%%~nX.war" "%TOMCAT_DIR%\webapps"

   )
)

popd


REM ***************************************************************************
REM Expand the WAR files, and delete the WAR files for each that was successfully expanded.
REM ***************************************************************************

pushd "%INSTALLER_FILES_SUBDIR%"
call expand_wars.cmd "%TOMCAT_DIR%\webapps"
popd

REM ***************************************************************************
REM Copy any ID files from the archive dir to the new webapp dirs.
REM ***************************************************************************

if exist "%WEBAPPS_ARCHIVE_DIR%" (

   echo.
   echo. Copying ID files from previous installation.

   pushd "%WEBAPPS_ARCHIVE_DIR%"

   for /d %%X in (*.*) do (

      if exist "%TOMCAT_DIR%\webapps\%%~nxX" (

         pushd "%%~nxX"
         xcopy *.id "%TOMCAT_DIR%\webapps\%%~nxX" /s /q
         popd
      )
   )

   popd
)

echo.
echo Webapps are installed, if no errors were indicated above.
echo.

REM Ask whether to start Tomcat. Errolevel 1=Y, 2=N

choice   /m "Start !TOMCAT_SCM_NAME! Service NOW"

if %ERRORLEVEL% EQU 1 (

   echo Starting Tomcat...
   net start "!TOMCAT_SCM_NAME!"
)


REM Skip over soubroutines below
goto :eof


REM ---------------------------------------------------------------------------

REM ***************************************************************************
REM This soubroutine moves an existing webapp subdirectory and/or WAR file
REM (specified by the first parameter, which is the name of the webapp)
REM to the archive directory.  If an error occurs, it will set the
REM MOVE_OLD_WEBAPPS_ERROR variable in the calling environment.
REM If no error occurred, the variable will retain its prior value.
REM ***************************************************************************
:moveExistingWebapp
(
   setlocal EnableDelayedExpansion

   set "WEBAPP_NAME=%~1"

   if exist "!WEBAPP_NAME!" (
      move "!WEBAPP_NAME!" "%WEBAPPS_ARCHIVE_DIR%"

      if !ERRORLEVEL! GTR 0 (
         echo ERROR:   Could not move existing !WEBAPP_NAME! webapp directory.
         set "MOVE_OLD_WEBAPPS_ERROR=true"
      )
   )

   if exist "!WEBAPP_NAME!.war" (
      move "!WEBAPP_NAME!.war" "%WEBAPPS_ARCHIVE_DIR%"

      if !ERRORLEVEL! GTR 0 (
         echo ERROR:   Could not move existing !WEBAPP_NAME!.war file.
         set "MOVE_OLD_WEBAPPS_ERROR=true"
      )
   )
)
(
    endlocal

    REM Export this to the calling environment.  The value is substituted when
    REM the enclosing block is parsed, freezing the value before endlocal executes.
    REM If this variable is NOT set in the subroutine, it should retain its former value.

    set "MOVE_OLD_WEBAPPS_ERROR=%MOVE_OLD_WEBAPPS_ERROR%"
    exit /b
)


REM ***************************************************************************
REM This soubroutine checks whether the specified webapp already exists
REM (either the webapp directory or corresponding WAR file).
REM If it does it echoes an error and sets the variable:
REM TOMCAT_WEBAPP_ALREADY_EXISTS_ERROR
REM ***************************************************************************

:verifyDestinationWebappDoesNotExist
(
   setlocal EnableDelayedExpansion

   set "WEBAPP_NAME=%~1"

   if exist "%TOMCAT_DIR%\webapps\!WEBAPP_NAME!" (

      echo ERROR:   The destination webapp dir exists: !WEBAPP_NAME!
      set "TOMCAT_WEBAPP_ALREADY_EXISTS_ERROR=true"

   ) else (

      if exist "%TOMCAT_DIR%\webapps\!WEBAPP_NAME!.war" (

         echo ERROR:   The destination WAR file exists: !WEBAPP_NAME!
         set "TOMCAT_WEBAPP_ALREADY_EXISTS_ERROR=true"

      )
   )
)
(
    endlocal

    REM Export this to the calling environment.  The value is substituted when
    REM the enclosing block is parsed, freezing the value before endlocal executes.
    REM If this variable is NOT set in the subroutine, it should retain its former value.

    set "TOMCAT_WEBAPP_ALREADY_EXISTS_ERROR=%TOMCAT_WEBAPP_ALREADY_EXISTS_ERROR%"
    exit /b
)
