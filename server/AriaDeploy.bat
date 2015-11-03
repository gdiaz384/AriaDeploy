@echo off
setlocal enabledelayedexpansion
pushd %~dp0

if /i "%~1" equ "" goto usageNotes
if /i "%~1" equ "?" goto usageNotes
if /i "%~1" equ "/?" goto usageNotes
if /i "%~1" equ "/createConfig" goto genConfig
if /i "%~1" equ "createConfig" goto genConfig
if /i "%~1" equ "/genConfig" goto genConfig
if /i "%~1" equ "genConfig" goto genConfig

::These are the default values, and will be overriden by the configuration file (deploy.ini)
::Then those ini configuration settings can be overriden by settings at runtime

::start Default settings::
::Very important: pePathToClient is the path from Win PE where clients search to find the client 
::configuration files (like deployclient.bat and .ini) Syntax: networkdrive:\path\to\client   If the local path looks 
::like: D:\workspace\autodeploy\client, and if workspace is shared then
set default_pePathToClient=Y:\autodeploy\client
::Make sure the letter used in pePathToClient matches the network drive the clients are actually using.
::If using ftp to map the drive letter, change it by modifying credentials.txt in the ftp home directory.
::To enable the (optional) unicast fallback features, the original sources must be in the network share path (D:\workspace\images)
set default_pePathToImages=Y:\images
set default_pePathToDrivers=Y:\updates\drivers

::server-side configuration::
set default_seederClientPath=resources
set default_seederClientexe=aria2c.exe
::local port used for tracker (use the local port of the seeding client if running an embedded tracker)
set default_trackerPort=6969
set default_unattendfileSource=D:\autodeploy\server\resources\unattendXml

::server-side control flow::
set default_checkIfPythonIsInstalled=true
set default_startSeeding=true

::settings for both server and clients::
set default_createTorrent=true
set default_unattendfileType=invalid
set default_hashType=invalid
set default_repackageDrivers=true
set default_archiveType=zip

::client-side settings configuration::
set default_clientTargetDisk=0
::normal is MBR:[RE][Windows] or GPT:[EFI][MSR][RE][Windows]  so with an RE partition
::minimal is MBR:[Windows] or GPT:[EFI][MSR][Windows] so as simplistic as possible
set default_clientPartitionLayout=minimal
set default_enableUnicastFallbackForImage=true
set default_enableUnicastFallbackForDrivers=true
set default_targetTempFilesLocation=recovery\oem
::normal,red,yellow,green,miku,purple,white
set default_cmdcolor=normal
set default_torrentclientexe=aria2c.exe
set default_hashGenExe=7za.exe

::client-side control flow::
set default_requirePrompt=false
set default_postDownloadSeedTime=5
set default_deleteImageFileAfterDeploymentCompletes=true
set default_deleteDriverArchiveAfterApplying=true
set default_restartAutomatically=false

::custom client-side scripts::
::For custom extensibility scripts, specify the name only, and place them in the autodeploy\client directory
::supported formats are cmd, bat, vbs and exe,
::they will run from x:\windows\system32 in the PE enviornment and get called as "call Y:\autodeploy\client\myscript.bat"
set default_customPreImagingScript=invalid
::set default_customPreImagingScript=getExistingComputerNameAndMac.bat
set default_customPostImagingScript=invalid
::set default_customPostImagingScript=installDriversManually.bat
::set default_customPostImagingScript=createRecoveryOptions.bat

::While the post oobe script gets copied automatically to targetTempFilesLocation it must be specified
::to execute at first logon in unattend.xml
set default_customPostOobeScript=invalid
::set default_customPostOobeScript=cleanupSysprep.bat
::set default_customPostOobeScript=joinDomain.bat
::end Default settings::

::names of config files::
set default_deployClientPath=..\client
set default_deployClientNameNoExtension=%~n0Client
set default_clientConfigFile=%~n0Client.ini
set default_serverConfigFile=%~n0.ini


::do not change anything below this line unless you know what you're doing::


::Procedure:
::1) gather enviornment data (autodeploy path and configuration settings)
::a-set defaults
::b-set some inital values based upon defaults
::c-if available read from deploy.ini, otherwise skip
::d-read runtime information
::e-validate all information (error check, if not valid set back to default values)
::f-check for dependencies -python and the two support files (set create torrent false if not found) and -7za- (set hash and create driver archive to false if not found)
::2) Unattend.xml (unattendfileType): always rename any existing unattend.xml file
::parse unattend file settings (RTM,advanced,specified one), find if necessary and then copy to temp folder
::3) CreateTorrent
::4) Hash: (hashType) calculate hash of .wimfile if asked too 
::5) Drivers: (repackageDrivers) always delete any previous autodeploy\client\drivers.zip file
::compress path into an archive for transmission to clients
::6) create deployClient.ini settings file
::7) move files from temp folder to client folder
::if  a module marked itself as successful, copy it's file from the temporary directory to autodeploy\client
::autodeploy\client\unattend.xml
::autodeploy\client\mywim.wim.torrent
::autodeploy\client\drivers.zip
::autodeploy\client\deployClient.ini
::8) Seeding: (startSeeding)

set arch=%processor_architecture%
if /i "%arch%" equ "amd64" set arch=x64

::1) gather enviornment data (autodeploy path and configuration settings)
::default settings (createTorrentExe, related syntax)
::then second are the deploy.ini settings (checkPython, skipHash, hashType, skipTorrent)
::highest priority are any  command line settings (highest precedence) (.wim file, index, hashType, .xml file)
::some instance specific settings can't be initalized until after wimfile gets parsed (at runtime)

set pePathToClient=%default_pePathToClient%
set pePathToImages=%default_pePathToImages%
set pePathToDrivers=%default_pePathToDrivers%

::server side configuration::
set seederClientPath=%default_seederClientPath%\%arch%
set seederClientexe=%default_seederClientexe%
set trackerPort=%default_trackerPort%
set unattendfileSource=%default_unattendfileSource%

::server-side control flow::
set checkIfPythonIsInstalled=%default_checkIfPythonIsInstalled%
set startSeeding=%default_startSeeding%

::settings for both server and clients::
set createTorrent=%default_createTorrent%
set unattendfileType=%default_unattendfileType%
set hashType=%default_hashType%
set repackageDrivers=%default_repackageDrivers%
set archiveType=%default_archiveType%

::client-side settings configuration::
set clientTargetDisk=%default_clientTargetDisk%
set clientPartitionLayout=%default_clientPartitionLayout%
set enableUnicastFallbackForImage=%default_enableUnicastFallbackForImage%
set enableUnicastFallbackForDrivers=%default_enableUnicastFallbackForDrivers%
set targetTempFilesLocation=%default_targetTempFilesLocation%
set cmdcolor=%default_cmdcolor%
set torrentclientexe=%default_torrentclientexe%
set hashGenExe=%default_hashGenExe%

::client-side control flow::
set requirePrompt=%default_requirePrompt%
set postDownloadSeedTime=%default_postDownloadSeedTime%
set deleteImageFileAfterDeploymentCompletes=%default_deleteImageFileAfterDeploymentCompletes%
set deleteDriverArchiveAfterApplying=%default_deleteDriverArchiveAfterApplying%
set restartAutomatically=%default_restartAutomatically%

::custom client-side scripts::
set customPreImagingScript=%default_customPreImagingScript%
::set customPreImagingScript=%default_customPreImagingScript%
set customPostImagingScript=%default_customPostImagingScript%
::customPostImagingScript=%default_customPostImagingScript%
::customPostImagingScript=%default_customPostImagingScript%

set customPostOobeScript=%default_customPostOobeScript%
::customPostOobeScript=%default_customPostOobeScript%

::names of config files::
set deployClientPath=%default_deployClientPath%
set deployClientNameNoExtension=%default_deployClientNameNoExtension%
set clientConfigFile=%default_clientConfigFile%
set serverConfigFile=%default_serverConfigFile%

if not exist "%serverConfigFile%" goto skipReadingServerConfigFile
::All default settings have been set, begin .ini override
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "pePathToClient=" %serverConfigFile%') do if /i "%%j" neq "" set pePathToClient=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "pePathToImages=" %serverConfigFile%') do if /i "%%j" neq "" set pePathToImages=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "pePathToDrivers=" %serverConfigFile%') do if /i "%%j" neq "" set pePathToDrivers=%%j

for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "seederClientPath=" %serverConfigFile%') do if /i "%%j" neq "" set seederClientPath=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "seederClientexe=" %serverConfigFile%') do if /i "%%j" neq "" set seederClientexe=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "trackerPort=" %serverConfigFile%') do if /i "%%j" neq "" set trackerPort=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "unattendfileSource=" %serverConfigFile%') do if /i "%%j" neq "" set unattendfileSource=%%j

for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "checkIfPythonIsInstalled=" %serverConfigFile%') do if /i "%%j" neq "" set checkIfPythonIsInstalled=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "startSeeding=" %serverConfigFile%') do if /i "%%j" neq "" set startSeeding=%%j

for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "createTorrent=" %serverConfigFile%') do if /i "%%j" neq "" set createTorrent=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "unattendfileType=" %serverConfigFile%') do if /i "%%j" neq "" set unattendfileType=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "hashType=" %serverConfigFile%') do if /i "%%j" neq "" set hashType=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "repackageDrivers=" %serverConfigFile%') do if /i "%%j" neq "" set repackageDrivers=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "archiveType=" %serverConfigFile%') do if /i "%%j" neq "" set archiveType=%%j

for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "clientTargetDisk=" %serverConfigFile%') do if /i "%%j" neq "" set clientTargetDisk=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "clientPartitionLayout=" %serverConfigFile%') do if /i "%%j" neq "" set clientPartitionLayout=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "enableUnicastFallbackForImage=" %serverConfigFile%') do if /i "%%j" neq "" set enableUnicastFallbackForImage=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "enableUnicastFallbackForDrivers=" %serverConfigFile%') do if /i "%%j" neq "" set enableUnicastFallbackForDrivers=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "targetTempFilesLocation=" %serverConfigFile%') do if /i "%%j" neq "" set targetTempFilesLocation=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "cmdcolor=" %serverConfigFile%') do if /i "%%j" neq "" set cmdcolor=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "torrentclientexe=" %serverConfigFile%') do if /i "%%j" neq "" set torrentclientexe=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "hashGenExe=" %serverConfigFile%') do if /i "%%j" neq "" set hashGenExe=%%j

for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "requirePrompt=" %serverConfigFile%') do if /i "%%j" neq "" set requirePrompt=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "postDownloadSeedTime=" %serverConfigFile%') do if /i "%%j" neq "" set postDownloadSeedTime=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "deleteImageFileAfterDeploymentCompletes=" %serverConfigFile%') do if /i "%%j" neq "" set deleteImageFileAfterDeploymentCompletes=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "deleteDriverArchiveAfterApplying=" %serverConfigFile%') do if /i "%%j" neq "" set deleteDriverArchiveAfterApplying=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "restartAutomatically=" %serverConfigFile%') do if /i "%%j" neq "" set restartAutomatically=%%j

for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "customPreImagingScript=" %serverConfigFile%') do if /i "%%j" neq "" set customPreImagingScript=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "customPostImagingScript=" %serverConfigFile%') do if /i "%%j" neq "" set customPostImagingScript=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "customPostOobeScript=" %serverConfigFile%') do if /i "%%j" neq "" set customPostOobeScript=%%j
:skipReadingServerConfigFile


::read from command line
if not exist "%~1" (echo   error please specify the full path of valid image file. Does not exist:&echo         "%~1"&goto end) else (set rawWimfilePath=%~1)
if /i "%~2" equ "" (set wimIndex=1) else (set wimIndex=%~2)
if /i "%~3" equ "" (set driversPath=invalid) else (set driversPath=%~3)
if /i "%~4" equ "" (set hashType=%hashType%) else (set hashType=%~4)
if /i "%~5" equ "" (set unattendfileType=%unattendfileType%) else (set unattendfileType=%~5)

::need to parse and validate wimfile right away to set the rest of the config options
call :parsePath "%rawWimfilePath%"
set dismPathAndExe=resources\dism\dism.exe

set wimfilePath=%fullfolderpath%
if "%folderpath%" neq "nul" set wimfilePathNoDriveLetter=%folderpath%
if "%folderpath%" equ "nul" set wimfilePathNoDriveLetter=nul
set wimfileName=%filename%.%extension%
set wimfileExtension=%extension%

if not exist "%wimfilePath%\%wimfileName%" (echo    error please specify a valid image file. The following file does not exist:
echo       "%wimfilePath%\%wimfileName%"
goto end)

::check to make sure extension is a .wim/esd/swm (adding support for .swms is complicated and kinda pointless, so not supported)
::although can add it later by using dism to export the swm image to autodeploy\myimage.wim, resetting the wimfilePathName variable and then continuing normally
if /i "%wimfileExtension%" neq "wim" if /i "%wimfileExtension%" neq "esd" if /i "%wimfileExtension%" neq "swm" (echo   error extension not valid:"%wimfileExtension%"
goto end)

call :cleanInput "%wimIndex%" wimIndex
if /i "%wimIndex%" neq "1" if /i "%wimIndex%" neq "2" if /i "%wimIndex%" neq "3" if /i "%wimIndex%" neq "4" if /i "%wimIndex%" neq "5" if /i "%wimIndex%" neq "6" if /i "%wimIndex%" neq "7" if /i "%wimIndex%" neq "8" if /i "%wimIndex%" neq "9" (echo   Valid image index not specified:"%wimindex%"
goto end)

::set errorlevel=1
::errorlevel is not a robust way of detecting errors, need to find a better way
set dismErrorLevelSyntax=/get-wiminfo /wimfile:"%wimfilePath%\%wimfileName%" /index:"%wimIndex%"
if exist "%dismPathAndExe%" "%dismPathAndExe%" %dismErrorLevelSyntax% >nul 2>nul
if not exist "%dismPathAndExe%" dism %dismErrorLevelSyntax% >nul 2>nul
if "%errorlevel%" neq "0" (echo.
echo   Unable to open %wimfilePath%\%wimfileName% /index:%wimIndex%
echo   Please verify as valid wimfile and index before proceeding further
goto end)

::getWimInfo expects a wimfile and index
call :getWimInfo "%wimfilePath%\%wimfileName%" "%wimIndex%"


:setFinalConfigSettings
call :cleanInput "%deployClientPath%" deployClientPath
::deployclient path is a relative path, change it to absolute here for seederClient syntax, cd works since pushd was used earlier for %~dp0
:: D:\autodeploy\server \  ..\client  \  %torrentfilename%
set deployClientPathAbsPath=%cd%\%deployClientPath%

::initalize script specific variables::
set tempdir=%temp%\temp%random%
if not exist "%tempdir%" mkdir "%tempdir%"
set torrentfileName=%wimfileName%.torrent
set createTorrentExePath=resources
set createTorrentExe=py3createtorrent.exe
::set createTorrentExeDependency=py3bencode.py
::creating a private torrent explicitly disables 1) peer exchange 2) DHT 3) local peer discovery, dht/lpd need disabling (they are too noisy)
::but specifying that at the client level, instead of in the torrent file itself, leaves peer exchange enabled for the torrent (px is helpful and not noisy)
::set createTorrentSyntax=--piece-length=16384 --force --md5 --private --output="%tempdir%\%torrentfileName%" "%wimfilePath%\%wimfileName%"
set createTorrentSyntax=--piece-length=16384 --force --md5 --output="%tempdir%\%torrentfileName%" "%wimfilePath%\%wimfileName%"
::set seeder syntax to start seeding after moving the torrent to the deployClientdirectory
::set seederClientSyntax=/directory "%wimfilePath%"
::To limit seeding time, add the --seed-time option as "--seed-time=60" for 60 minutes of seeding, don't use quotes
::or to limit upload speed to 10 MB/s or w/e in order to reserve bandwidth for pxe, "--max-overall-upload-limit=10M"
set seederClientSyntax=--check-integrity=true --seed-ratio=0.0 --dir="%wimfilePath%" --enable-dht=false --bt-enable-lpd=false --enable-peer-exchange=true --bt-force-encryption=true
set driverArchiveName=Win%wimOSVersion%_%wimArchitecture%_drivers
set findHashStatus=invalid
set unattendfileStatus=invalid
set unattendFileName=invalid
set hashData=invalid

::start validating non-wim input and configuration settings::
::should prolly like, check for spaces at the end of the paths, those can be tricky to debug at run time
::call remove end spaces, cleanupInput expects %1 the raw input to clean up and %2, the variable to put the result in
::call :cleanupInput "d:\mypath\withtrailing\spaces\  " cleaned
call :cleanInput "%pePathToClient%" pePathToClient
call :cleanInput "%pePathToImages%" pePathToImages
call :cleanInput "%pePathToDrivers%" pePathToDrivers

call :cleanInput "%seederClientPath%" seederClientPath
call :cleanInput "%seederClientexe%" seederClientexe
call :cleanInput "%trackerPort%" trackerPort
call :cleanInput "%unattendfileSource%" unattendfileSource

call :cleanInput "%checkIfPythonIsInstalled%" checkIfPythonIsInstalled
call :cleanInput "%startSeeding%" startSeeding

call :cleanInput "%createTorrent%" createTorrent
call :cleanInput "%unattendfileType%" unattendfileType
call :cleanInput "%hashType%" hashType
call :cleanInput "%repackageDrivers%" repackageDrivers
call :cleanInput "%archiveType%" archiveType

call :cleanInput "%clientTargetDisk%" clientTargetDisk
call :cleanInput "%clientPartitionLayout%" clientPartitionLayout
call :cleanInput "%enableUnicastFallbackForImage%" enableUnicastFallbackForImage
call :cleanInput "%enableUnicastFallbackForDrivers%" enableUnicastFallbackForDrivers
call :cleanInput "%targetTempFilesLocation%" targetTempFilesLocation
call :cleanInput "%cmdcolor%" cmdcolor
call :cleanInput "%torrentclientexe%" torrentclientexe
call :cleanInput "%hashGenExe%" hashGenExe

call :cleanInput "%requirePrompt%" requirePrompt
call :cleanInput "%postDownloadSeedTime%" postDownloadSeedTime
call :cleanInput "%deleteImageFileAfterDeploymentCompletes%" deleteImageFileAfterDeploymentCompletes
call :cleanInput "%deleteDriverArchiveAfterApplying%" deleteDriverArchiveAfterApplying
call :cleanInput "%restartAutomatically%" restartAutomatically

call :cleanInput "%customPreImagingScript%" customPreImagingScript
call :cleanInput "%customPostImagingScript%" customPostImagingScript
call :cleanInput "%customPostOobeScript%" customPostOobeScript

::check deployClientPath, if not valid tell user about it and error out
if not exist "%deployClientPath%" (echo.
echo   Serious error: The %deployClientNameNoExtension% path does not exist.
echo   From %serverConfigFile%: "%deployClientPath%"
echo   Please make sure this path is valid and specified in %serverConfigFile%
echo   by using deployClientPath before proceeding further.
goto end)
if not exist "%fullpath%" (echo   Error parsing deployClientPath path
goto end)

::if driver path not specified set repackage status to false and move on
if /i "%driversPath%" equ "invalid" (set repackageDrivers=false
goto postDriverCheck)

::if driver path specified, but invalid, set repackageDrivers=false and check with user
if not exist "%driversPath%" (goto driversInvalidPrompt1)

::if driver path specified and valid, set repackageDrivers=false and parse driversPath
set repackageDrivers=true
call :parsePath "%driversPath%"

if not exist "%fullpath%" (echo   Error parsing valid driver path
goto driversInvalidPrompt1)

set driversPath=%fullpath%
if not exist "%driversPath%" goto driversInvalidPrompt1
set driversFolderName=%foldername%

if /i "%folderpath%" neq "nul" set driversPathNoDriveLetter=%folderpath%\%foldername%
if /i "%folderpath%" equ "nul" set driversPathNoDriveLetter=%foldername%
if /i "%folderpath%" neq "nul" set driversPathPartialWithDrive=%drive%\%folderpath%
if /i "%folderpath%" equ "nul" set driversPartialPathWithDrive=%drive%

goto postDriverCheck

:driversInvalidPrompt1
set callback=postDriverCheck
echo    Error setting driver path settings
echo          driversPath:"%driversPath%"
echo   Do you want to continue the deployment without installing endpoint drivers?
set driversPath=invalid
set repackageDrivers=false
goto booleanPrompt
:postDriverCheck

::if find hash isn not defined set findHashStatus to invalid, data to invalid and move on
if not defined hashType (set findHashStatus=invalid
set hashData=invalid
goto postHashCheck)

::check hashType specified
:parseHashSettings
::if find hash is set to skip invalid, set findHashStatus to false, data to invalid and move on
if /i "%hashType%" equ "invalid" (set findHashStatus=invalid
set hashData=invalid
goto postHashCheck)

::hashType check, if invalid set to back to default_hashType (crc32)
if /i "%hashType%" equ "crc32" set findHashStatus=valid
if /i "%hashType%" equ "crc64" set findHashStatus=valid
if /i "%hashType%" equ "sha1" set findHashStatus=valid
if /i "%hashType%" equ "sha256" set findHashStatus=valid

::hashType check, if invalid set to back to default_hashType (crc32)
if /i "%hashType%" neq "crc32" if /i "%hashType%" neq "crc64" if /i "%hashType%" neq "sha1" if /i "%hashType%" neq "sha256" (echo   hash type invalid: "%hashType%" setting to %default_hashType%
set hashType=%default_hashType%)
:postHashCheck

:parseUnattendFileSettings
::check type for for rtm/advanced, if unattendfileType is RTM/advanced search various places to select as copy source
::unattendfileType can be invalid, rtm, advanced or an actual path to an xml file
if /i "%unattendfileType%" equ "invalid" (set unattendfileStatus=invalid
set unattendFileName=invalid
goto postUnattendfileCheck)

if /i "%unattendfileType%" equ "RTM" (set unattendfileStatus=valid
set unattendFileName=unattend_Win%wimOSVersion%_%wimEdition%_%wimArchitecture%_%unattendfileType%.xml
echo   unattendFileName:"!unattendFileName!"
goto postUnattendfileCheck)

if /i "%unattendfileType%" equ "advanced" (set unattendfileStatus=valid
set unattendFileName=unattend_Win%wimOSVersion%_%wimEdition%_%wimArchitecture%_%unattendfileType%.xml
echo   unattendFileName:"!unattendFileName!"
goto postUnattendfileCheck)

::so then assume user entered a fully qualified .xml file path
set unattendfileCustomFullPath=%unattendfileType%
set unattendfileType=custom

if not exist "%unattendfileCustomFullPath%" (goto unattendFileSettingsInvalidPrompt1)

call :parsePath %unattendfileCustomFullPath%
set unattendFileName=%filename%
if /i "%extension%" neq "xml"  (goto unattendFileSettingsInvalidPrompt1)
echo   unattendFileName:"%unattendFileName%"
set unattendfileStatus=valid

goto postUnattendfileCheck

:unattendFileSettingsInvalidPrompt1
set callback=messWithUnattendFiles
echo   Error setting unattend settings
echo      unattendfileType:"%unattendfileType%"
echo   Do you want to continue the deployment without an unattend.xml file?
set unattendfileStatus=invalid
set unattendType=invalid
goto booleanPrompt
:postUnattendfileCheck

::local seeder client check, if not valid disable seeding
if not exist "%seederClientPath%\%seederClientexe%" (echo   Error finding seeder client at 
echo   "%seederClientPath%\%seederClientexe%"
echo   please manually start "%deployClientPath%\%torrentfileName%"
set startSeeding=false)

::trackerPort check, greater than 0  but less than 65534, set to 3200 by default
if %trackerPort% equ "" (echo   error tracker Port wasn't specified, setting it to %default_trackerPort% &set trackerPort=%default_trackerPort%)
if %trackerPort% leq 0 (echo   tracker port is invalid:"%trackerPort%" changing to port %default_trackerPort%&set trackerPort=%default_trackerPort%)
if %trackerPort% geq 65534 (echo   error specified port for local tracker is invalid:"%trackerPort%" changing to port %default_trackerPort%&set trackerPort=%default_trackerPort%)

::check if unattendfileSource is valid, if not just tell user about it and move on
if not exist "%unattendfileSource%" (echo   source path for unattend.xml files does not exist. If unattend.xml rtm/advanced options are selected 
echo   the relevant files may not be found to automate oobe
if exist "%default_unattendfileSource%" (set unattendFileSource=%default_unattendfileSource%) else (set unattendfileSource=invalid)
)
call :cleanInput "%unattendfileSource%" unattendfileSource

::python check, if not valid hope it's been installed
if /i "%checkIfPythonIsInstalled%" neq "true" if /i "%checkIfPythonIsInstalled%" neq "false" (echo   Python check settings invalid: "%checkIfPythonIsInstalled%" setting python check to "default_checkIfPythonIsInstalled"
set checkIfPythonIsInstalled=%default_checkIfPythonIsInstalled%)

if /i "%startSeeding%" neq "true" if /i "%startSeeding%" neq "false" (echo   start seeding setting is invalid:"%startSeeding%" setting to %default_startSeeding%
set startSeeding=%default_startSeeding%)

if /i "%createTorrent%" neq "true" if /i "%createTorrent%" neq "false" (echo   create torrent settings is invalid:"%createTorrent%" setting to %default_createTorrent%
set createTorrent=%default_createTorrent%)

if /i "%archiveType%" neq "7z" if /i "%archiveType%" neq "zip" (echo  archive type is invalid:"%archiveType%" setting to %default_archiveType%
set archiveType=%default_archiveType%)

if /i "%clientTargetDisk%" neq "0" if /i "%clientTargetDisk%" neq "1" if /i "%clientTargetDisk%" neq "2" if /i "%clientTargetDisk%" neq "3" if /i "%clientTargetDisk%" neq "4" if /i "%clientTargetDisk%" neq "5" if /i "%clientTargetDisk%" neq "6" (echo   Valid client disk number not specified:"%clientTargetDisk%", setting back to default: %default_clientTargetDisk%
set clientTargetDisk=%default_clientTargetDisk%
goto end)

::clientPartitionLayout, set to minimal if invalid
if /i "%clientPartitionLayout%" neq "minimal" if /i "%clientPartitionLayout%" neq "normal" (echo   Clients partition layout setting is invalid:"%clientPartitionLayout%"
echo   Setting back to default setting of: "default_clientPartitionLayout"
set clientPartitionLayout=%default_clientPartitionLayout%)

::enableUnicastFallbackForImage, set to true if invalid
if /i "%enableUnicastFallbackForImage%" neq "true" if /i "%enableUnicastFallbackForImage%" neq "false" (echo   Image unicast setting is invalid:"%enableUnicastFallbackForImage%"
echo   Setting back to default setting of: %default_enableUnicastFallbackForImage%
set enableUnicastFallbackForImage=%default_enableUnicastFallbackForImage%)

::enableUnicastFallbackForDrivers, set to true if invalid
if /i "%enableUnicastFallbackForDrivers%" neq "true" if /i "%enableUnicastFallbackForDrivers%" neq "false" (echo   Image unicast setting is invalid:"%enableUnicastFallbackForDrivers%"
echo   Setting back to default setting of: %default_enableUnicastFallbackForDrivers%
set enableUnicastFallbackForDrivers=%default_enableUnicastFallbackForDrivers%)

::there really isn't a good way to test the targetTemp destination, and as long as it's specified, isn't a big deal

::cmdcolor normal,red,yellow, green,miku,purple,gray
if /i "%cmdcolor%" neq "normal" if /i "%cmdcolor%" neq "red" if /i "%cmdcolor%" neq "yellow" if /i "%cmdcolor%" neq "green" if /i "%cmdcolor%" neq "miku" if /i "%cmdcolor%" neq "purple" if /i "%cmdcolor%" neq "gray" (echo   Cmd color setting is invalid:"%cmdcolor%" changing to %default_cmdcolor%
set cmdcolor=%default_cmdcolor%)

if /i "%torrentclientexe%" neq "invalid" call :verifyExtension "%torrentclientexe%" torrentclientexe
if /i "%hashGenExe%" neq "invalid" call :verifyExtension "%hashGenExe%" hashGenExe

::if prompt settings are invalid, set to true (cautious approach)
if /i "%requirePrompt%" neq "true" if /i "%requirePrompt%" neq "false" (echo   Require clients to prompt setting is invalid:"%requirePrompt%" changing to %default_requirePrompt%
set requirePrompt=%default_requirePrompt%)

::postDownloadSeedTime check, greater than 0 (or clients won't seed at all) but less than an hour (or deployment will never actually finish), set to 5 min by default
if %postDownloadSeedTime% equ "" (echo   seeding time wasn't specified: setting it to %default_postDownloadSeedTime%
set postDownloadSeedTime=%default_postDownloadSeedTime%)
if %postDownloadSeedTime% lss 1 (echo   seeding time must be positive: %postDownloadSeedTime% setting to %default_postDownloadSeedTime%
set postDownloadSeedTime=%default_postDownloadSeedTime%)
if %postDownloadSeedTime% geq 61 (echo   seeding time is too high: %postDownloadSeedTime% changing to port %postDownloadSeedTime%
set postDownloadSeedTime=%default_postDownloadSeedTime%)

::if delete image settings are invalid, set to true
if /i "%deleteImageFileAfterDeploymentCompletes%" neq "true" if /i "%deleteImageFileAfterDeploymentCompletes%" neq "false" (echo   post deployment Image instructions invalid:"%deleteImageFileAfterDeploymentCompletes%" changing to remove after deployment to %default_deleteImageFileAfterDeploymentCompletes%
set deleteImageFileAfterDeploymentCompletes=%default_deleteImageFileAfterDeploymentCompletes%)

::if driver archive remove settings are invalid, set to true
if /i "%deleteDriverArchiveAfterApplying%" neq "true" if /i "%deleteDriverArchiveAfterApplying%" neq "false" (echo   remove driver archive instructions invalid:"%deleteDriverArchiveAfterApplying%" changing to remove after deployment to %default_deleteDriverArchiveAfterApplying%
set deleteDriverArchiveAfterApplying=%default_deleteDriverArchiveAfterApplying%)

::if restart settings are invalid, set to true
if /i "%restartAutomatically%" neq "true" if /i "%restartAutomatically%" neq "false" (echo   post deployment restart instructions invalid:"%restartAutomatically%" changing to restart after deployment to %default_restartAutomatically%
set restartAutomatically=%default_restartAutomatically%)

if /i "%customPreImagingScript%" neq "invalid" call :verifyExtension "%customPreImagingScript%" customPreImagingScript
if /i "%customPostImagingScript%" neq "invalid" call :verifyExtension "%customPostImagingScript%" customPostImagingScript
if /i "%customPostOobeScript%" neq "invalid" call :verifyExtension "%customPostOobeScript%" customPostOobeScript

::so if the defaults were icky, and a setting was reset to default, then the new setting will be icky, so need to clean it, again
call :cleanInput "%pePathToClient%" pePathToClient
call :cleanInput "%pePathToImages%" pePathToImages
call :cleanInput "%pePathToDrivers%" pePathToDrivers

call :cleanInput "%seederClientPath%" seederClientPath
call :cleanInput "%seederClientexe%" seederClientexe
call :cleanInput "%trackerPort%" trackerPort
call :cleanInput "%unattendfileSource%" unattendfileSource

call :cleanInput "%checkIfPythonIsInstalled%" checkIfPythonIsInstalled
call :cleanInput "%startSeeding%" startSeeding

call :cleanInput "%createTorrent%" createTorrent
call :cleanInput "%unattendfileType%" unattendfileType
call :cleanInput "%hashType%" hashType
call :cleanInput "%repackageDrivers%" repackageDrivers
call :cleanInput "%archiveType%" archiveType

call :cleanInput "%clientTargetDisk%" clientTargetDisk
call :cleanInput "%clientPartitionLayout%" clientPartitionLayout
call :cleanInput "%enableUnicastFallbackForImage%" enableUnicastFallbackForImage
call :cleanInput "%enableUnicastFallbackForDrivers%" enableUnicastFallbackForDrivers
call :cleanInput "%targetTempFilesLocation%" targetTempFilesLocation
call :cleanInput "%cmdcolor%" cmdcolor
call :cleanInput "%torrentclientexe%" torrentclientexe
call :cleanInput "%hashGenExe%" hashGenExe

call :cleanInput "%requirePrompt%" requirePrompt
call :cleanInput "%postDownloadSeedTime%" postDownloadSeedTime
call :cleanInput "%deleteImageFileAfterDeploymentCompletes%" deleteImageFileAfterDeploymentCompletes
call :cleanInput "%deleteDriverArchiveAfterApplying%" deleteDriverArchiveAfterApplying
call :cleanInput "%restartAutomatically%" restartAutomatically

call :cleanInput "%customPreImagingScript%" customPreImagingScript
call :cleanInput "%customPostImagingScript%" customPostImagingScript
call :cleanInput "%customPostOobeScript%" customPostOobeScript

::validate system (dependencies)::

::if creating a torrent file, then need to check dependencies for it, and disable creating torrent if python/pycreatetorrent/benny are not found
if /i "createTorrent" neq "true" goto postTorrentDependenciesCheck
if defined createTorrentExeDependency if not exist "%createTorrentExePath%\%createTorrentExeDependency%" (echo   could not verify create torrent create dependency "%createTorrentExeDependency%" exists
echo   will not create a .torrent file, please create one manually and place at "%deployClientPath%"
set createTorrent=false
goto postTorrentDependenciesCheck)
if not exist "%createTorrentExePath%\%createTorrentExe%" (echo   could not verify create torrent create dependency "%createTorrentExe%" exists
echo   will not create a .torrent file, please create one manually and place at "%deployClientPath%"
set createTorrent=false
goto postTorrentDependenciesCheck)

::check to see if python is installed unless told not to or dependency doesn't exist
if /i "%checkIfPythonIsInstalled%" neq "true" goto postTorrentDependenciesCheck
if not defined createTorrentExeDependency goto postTorrentDependenciesCheck
for /f "tokens=1-10 delims=. " %%a in ('python --version') do set pythonVersion=%%b
if /i "%pythonVersion%" neq "3" (
echo   error Python 3.1+ not detected, can not create %wimfileName%.torrent
echo   if installed, add to path,reboot or disable Python check
echo   please create it manually and place at "%deployClientPath%"
set createTorrent=false
set startSeeding=false)
:postTorrentDependenciesCheck

::if creating a hash or archiving drivers, need to find 7zip somewhere and set it to sevenz variable name
::if not found, then disable both hashing and archiving drivers
::skip if not finding hash and not archiving drivers
if /i "%findHashStatus%" neq "valid" if "%repackageDrivers%" neq "true" goto skipSevenZCheck
if /i "%processor_architecture%" equ "AMD64" (set path0=resources\x64\7z.exe) else (set path0=resources\x86\7z.exe)
set path1=x:\windows\system32\tools\7z\7z.exe
set path2=x:\windows\system32\tools\7z\7za.exe
set path3=x:\windows\system32\tools\temp\7z.exe
set path4=x:\windows\system32\tools\temp\7za.exe
set path5=tools\7z\7z.exe
set path6=tools\7z\7za.exe
set path7=c:\program files (x86)\7-Zip\7z.exe
set path8=c:\program files\7-Zip\7z.exe
set path9=tools\temp\7z.exe
set path10=tools\temp\7za.exe
set path11=resources\7z.exe
set path12=resources\7za.exe

if exist "%path0%" set sevenz=%path0%
if exist "%path1%" set sevenz=%path1%
if exist "%path2%" set sevenz=%path2%
if exist "%path3%" set sevenz=%path3%
if exist "%path4%" set sevenz=%path4%
if exist "%path5%" set sevenz=%path5%
if exist "%path6%" set sevenz=%path6%
if exist "%path7%" set sevenz=%path7%
if exist "%path8%" set sevenz=%path8%
if exist "%path9%" set sevenz=%path9%
if exist "%path10%" set sevenz=%path10%
if exist "%path11%" set sevenz=%path11%
if exist "%path12%" set sevenz=%path12%

if not exist "%sevenz%" set archiveDrivers=false
if not exist "%sevenz%" set findHashStatus=false
:skipSevenZCheck


::2)  parse unattend file settings (RTM,advanced,custom) and, if available, copy to autodeploy\client\unattend.xml (rename any existine one)
:messWithUnattendFiles
::if not specified, status not valid, just skip
if /i "%unattendfileStatus%" neq "valid" goto createTorrentFile

::check type, if unattendfileType=custom, then set path and go copy it
if /i "%unattendfileType%" equ "custom" (set unattendfileFullPath=%unattendfileCustomFullPath%
goto finalUnattendfileCheck)

::can assume status is valid, and that rtm or advanced was selected

::when searching, it's not a good idea to search in optical drives (for physical machines), unless valid, check if exists and build list dynamicly instead
::set searchDrives=Z,Y,X,T,M,E,B,C,D
set searchDrives=C
if exist B: set searchDrives=%searchDrives%,B
if exist D: set searchDrives=%searchDrives%,D
if exist E: set searchDrives=%searchDrives%,E
if exist F: set searchDrives=%searchDrives%,F
if exist M: set searchDrives=%searchDrives%,M
if exist N: set searchDrives=%searchDrives%,N
if exist T: set searchDrives=%searchDrives%,T
if exist X: set searchDrives=%searchDrives%,X
if exist Y: set searchDrives=%searchDrives%,Y
if exist Z: set searchDrives=%searchDrives%,Z

set unattendTreeAndName=Win%wimOSVersion%\%unattendfileName%

set searchPath11=\%unattendTreeAndName%
set searchPath10=\%unattendfileName%
set searchPath9=\scripts\unattendXml\%unattendTreeAndName%
set searchPath8=\scripts\unattendXml\%unattendfileName%
set searchPath7=\workspace\scripts\unattendXml\%unattendTreeAndName%
set searchPath6=\workspace\scripts\unattendXml\%unattendfileName%
set searchPath5=..\..\scripts\unattendXml\%unattendTreeAndName%
set searchPath4=..\..\scripts\unattendXml\%unattendfileName%
set searchPath3=resources\unattendXml\%unattendTreeAndName%
set searchPath2=resources\unattendXml\%unattendfileName%
set searchPath1=%unattendFileSource%\%unattendTreeAndName%
set searchPath0=%unattendFileSource%\%unattendfileName%

for %%i in (%searchDrives%) do (if exist "%%i:%searchPath11%" (set unattendfileFullPath=%%i:%searchPath11%))
for %%i in (%searchDrives%) do (if exist "%%i:%searchPath10%" (set unattendfileFullPath=%%i:%searchPath10%))
for %%i in (%searchDrives%) do (if exist "%%i:%searchPath9%" (set unattendfileFullPath=%%i:%searchPath9%))
for %%i in (%searchDrives%) do (if exist "%%i:%searchPath8%" (set unattendfileFullPath=%%i:%searchPath8%))
for %%i in (%searchDrives%) do (if exist "%%i:%searchPath7%" (set unattendfileFullPath=%%i:%searchPath7%))
for %%i in (%searchDrives%) do (if exist "%%i:%searchPath6%" (set unattendfileFullPath=%%i:%searchPath6%))
if exist "%searchPath5%" (set unattendfileFullPath=%searchPath5%)
if exist "%searchPath4%" (set unattendfileFullPath=%searchPath4%)
if exist "%searchPath3%" (set unattendfileFullPath=%searchPath3%)
if exist "%searchPath2%" (set unattendfileFullPath=%searchPath2%)
if /i "%unattendFileSource%" neq "invalid" if exist "%searchPath1%" (set unattendfileFullPath=%searchPath1%)
if /i "%unattendFileSource%" neq "invalid" if exist "%searchPath0%" (set unattendfileFullPath=%searchPath0%)

if not exist "%unattendfileFullPath%" (echo.
echo   error unattendType "%unattendfileType%" specified for %wimfileName%
echo   but could not find "%unattendFileName%"
echo   please specify it manually or in %serverConfigFile% under unattendFileSource 
echo   Alternatively, copy it %deployClientPath% before booting clients
echo.
goto unattendFileSettingsInvalidPrompt2)
if exist "%unattendfileFullPath%" (echo   found unattend.xml at 
echo   %unattendfileFullPath%)

::if not able to find one and an attempt was made to, then prompt user about it
if not exist "%unattendfileFullPath%" (set callback=createTorrentFile
goto :unattendFileSettingsInvalidPrompt2)

:finalUnattendfileCheck
::check to make sure it actually exists before copying
if not exist "%unattendfileFullPath%" goto unattendFileSettingsInvalidPrompt2

goto createTorrentFile

:unattendFileSettingsInvalidPrompt2
set callback=createTorrentFile
echo   Debug info:
echo   Error setting unattend.xml settings
echo              rawInput:"%~5"
echo    unattendfileStatus:%unattendfileStatus%
echo       wimArchitecture:%wimArchitecture%
echo          wimOSVersion:%wimOSVersion%
echo.
echo   Do you want to continue the deployment without an unattend.xml file?
set unattendfileFullPath=invalid
goto booleanPrompt


::3) createTorrentFile
:createTorrentFile
if /i "%createTorrent%" neq "true" goto calculateHash
::find local IPs (to add them as trackers)
set ip1=invalid
set ip2=invalid
set ip3=invalid
set ip4=invalid
ipconfig > ipinfo.txt
if exist ipaddresses.txt del ipaddresses.txt
for /f "tokens=1-20" %%a in ('find "IPv4 Address" ipinfo.txt') do if "%%n" neq "" echo %%n>> ipaddresses.txt
if exist ipinfo.txt del ipinfo.txt
set counter=1
for /f %%i in (ipaddresses.txt) do (set ip!counter!=%%i
set /a counter=!counter!+1)
if exist ipaddresses.txt del ipaddresses.txt
set /a counter-=1
set trackerNumber=%counter%

::create torrent of file
::http:192.168.0.108:%trackerPort%/announce
echo   Creating .torrent file please wait...
if /i "%ip1%" neq "invalid" set tracker1=http://%ip1%:%trackerPort%/announce
if /i "%ip2%" neq "invalid" set tracker2=http://%ip2%:%trackerPort%/announce
if /i "%ip3%" neq "invalid" set tracker3=http://%ip3%:%trackerPort%/announce
if /i "%ip4%" neq "invalid" set tracker4=http://%ip4%:%trackerPort%/announce

if %trackerNumber% equ 1 "%createTorrentExePath%\%createTorrentexe%" %createTorrentSyntax% %tracker1%
if %trackerNumber% equ 2 "%createTorrentExePath%\%createTorrentexe%" %createTorrentSyntax% %tracker1% %tracker2%
if %trackerNumber% equ 3 "%createTorrentExePath%\%createTorrentexe%" %createTorrentSyntax% %tracker1% %tracker2% %tracker3%
if %trackerNumber% geq 4 "%createTorrentExePath%\%createTorrentexe%" %createTorrentSyntax% %tracker1% %tracker2% %tracker3% %tracker4%


::4) calculate hash of .wimfile if asked too
:calculateHash
if /i "%findHashStatus%" neq "valid" goto messWithDriverSettings

::calculate hash of torrent file
::hash x:\myfile.wim sha1
echo    Calculating %hashType% hash of %wimfileName% please wait...
set errorlevel=0
call :hashCheck "%wimfilePath%\%wimfileName%" %hashType%> hash.txt
for /f "tokens=1-10" %%a in (hash.txt) do set hashData=%%a
if exist hash.txt del hash.txt


::5) if specified: parse driver settings but always delete any previous autodeploy\client\drivers.7z file regardless
::if specified, compress path into a .7z file for clients and move to autodeploy\client\drivers.7z (no fancy names, this is a disposable file)
:messWithDriverSettings

if /i "%repackageDrivers%" neq "true" goto createClientConfigurationFile

if not exist "%driversPath%" (echo   unspecified driver error
set driversPath=invalid
goto driversInvalidPrompt2)

echo   Compressing drivers into archive please wait...

if /i "%archiveType%" neq "7z" if /i "%archiveType%" neq "zip" (echo unspecified error creating drivers archive
goto driversInvalidPrompt2)

if /i "%archiveType%" equ "7z" ("%sevenz%" a -t%archiveType% "%tempdir%\%driverArchiveName%.%archiveType%" "%driversPath%\*" -ms=off -mx1 -mmt)
if /i "%archiveType%" equ "zip" ("%sevenz%" a -t%archiveType% "%tempdir%\%driverArchiveName%.%archiveType%" "%driversPath%\*" -mx1 -mmt)

if not exist "%tempdir%\%driverArchiveName%.%archiveType%" (echo error creating archive
echo "%tempdir%\%driverArchiveName%.%archiveType%" not found
goto driversInvalidPrompt2)

goto createClientConfigurationFile

:driversInvalidPrompt2
set callback=createClientConfigurationFile
echo    Error setting driver path settings
echo            rawinput:"%~3"
echo   Do you want to continue the deployment without installing endpoint drivers?
set repackageDrivers=false
goto booleanPrompt


::6) create client settings file (ini), settings are from the perspective of peclients
:createClientConfigurationFile
set outputConfig=%tempdir%\%clientConfigFile%

echo configFilesLocation=%pePathToClient%>>"%outputConfig%"

echo. >>"%outputConfig%"

echo ::instance specific information::>>"%outputConfig%"
echo imagefileName=^%wimfileName%>>"%outputConfig%"
echo imageIndex=^%wimIndex%>>"%outputConfig%"
echo unattendfileName=%unattendfileName%>>"%outputConfig%"
echo driversArchiveName=%driverArchiveName%.%archiveType%>>"%outputConfig%"
echo torrentfileName=%torrentfileName%>>"%outputConfig%"
echo hashType=%hashType%>>"%outputConfig%"
echo hashData=^%hashData%>>"%outputConfig%"

echo. >>"%outputConfig%"

echo ::client-side settings configuration::>>"%outputConfig%"
echo clientTargetDisk=^%clientTargetDisk%>>"%outputConfig%"
echo clientPartitionLayout=%clientPartitionLayout%>>"%outputConfig%"
echo enableUnicastFallbackForImage=%enableUnicastFallbackForImage%>>"%outputConfig%"
echo enableUnicastFallbackForDrivers=%enableUnicastFallbackForDrivers%>>"%outputConfig%"
echo pePathToImages=%pePathToImages%>>"%outputConfig%"
echo pePathToDrivers=%pePathToDrivers%>>"%outputConfig%"
echo targetTempFilesLocation=%targetTempFilesLocation%>>"%outputConfig%"
echo cmdcolor=%cmdcolor%>>"%outputConfig%"
echo torrentclientexe=%torrentclientexe%>>"%outputConfig%"
echo hashGenExe=%hashGenExe%>>"%outputConfig%"

echo. >>"%outputConfig%"

echo ::client-side control flow::>>"%outputConfig%"
echo requirePrompt=%requirePrompt%>>"%outputConfig%"
echo postDownloadSeedTime=^%postDownloadSeedTime%>>"%outputConfig%"
echo deleteImageFileAfterDeploymentCompletes=%deleteImageFileAfterDeploymentCompletes%>>"%outputConfig%"
echo deleteDriverArchiveAfterApplying=%deleteDriverArchiveAfterApplying%>>"%outputConfig%"
echo restartAutomatically=%restartAutomatically%>>"%outputConfig%"

echo. >>"%outputConfig%"

echo ::custom client-side scripts::>>"%outputConfig%"
echo customPreImagingScript=%customPreImagingScript%>>"%outputConfig%"
echo customPostImagingScript=%customPostImagingScript%>>"%outputConfig%"
echo customPostOobeScript=%customPostOobeScript%>>"%outputConfig%"

echo. >>"%outputConfig%"


::7) copy files from temp to autodeploy\client
::update Final Settings

if exist "%deployClientPath%\%clientConfigFile%" del "%deployClientPath%\%clientConfigFile%"

::rename existing unattend.xml file, The idea is to not let old .xml files ruin the deployment.
if exist "%deployClientPath%\unattend.xml" (
if exist "%deployClientPath%\unattend.old.xml" del "%deployClientPath%\unattend.old.xml"
ren "%deployClientPath%\unattend.xml" "unattend.old.xml")

::remove existing drivers.zip file
if exist "%deployClientPath%\%driverArchiveName%.%archiveType%" del "%deployClientPath%\%driverArchiveName%.%archiveType%"

echo.
echo %outputConfig% settings:
type "%outputConfig%"
echo.
echo  moving: "%outputConfig%"
echo      to: "%deployClientPath%\%clientConfigFile%"
move /y "%outputConfig%" "%deployClientPath%\%clientConfigFile%"

echo copying: "resources\client.template" 
echo     to: "%deployClientPath%\%deployClientNameNoExtension%.bat"
copy /y "resources\client.template" "%deployClientPath%\%deployClientNameNoExtension%.bat"

if /i "%repackageDrivers%" neq "true" goto afterMovingDriversArchive
::move over new file
echo moving "%tempdir%\%driverArchiveName%.%archiveType%" & echo   to: "%deployClientPath%\%driverArchiveName%.%archiveType%"
move /y "%tempdir%\%driverArchiveName%.%archiveType%" "%deployClientPath%\%driverArchiveName%.%archiveType%"
:afterMovingDriversArchive

:moveTorrentFile
if /i "%createTorrent%" neq "true" goto afterMovingTorrent
if not exist "%tempdir%\%torrentfileName%" (echo   error unable to find %torrentfileName% at "%tempdir%\%torrentfileName%"
goto end)
echo  moving: "%tempdir%\%torrentfileName%" 
echo      to: "%deployClientPath%\%torrentfileName%"
move /y "%tempdir%\%torrentfileName%" "%deployClientPath%\%torrentfileName%"
:afterMovingTorrent

if /i "%unattendfileType%" neq "rtm" if /i "%unattendfileType%" neq "advanced" if /i "%unattendfileType%" neq "custom" goto afterUnattendfileCopy
::copy specified unattend file
echo   copying "%unattendfileFullPath%"
echo      to "%deployClientPath%\%unattendFileName%"
copy /y "%unattendfileFullPath%" "%deployClientPath%\%unattendFileName%"
:afterUnattendfileCopy

::8) and finally: startseeding
::if a torrent was never created, then don't move or seed it
:startSeeding
if /i "%createTorrent%" neq "true" goto end
if /i "%startSeeding%" neq "true" goto end

::start "" M:\uTorrent\uTorrent.exe /directory "C:\Users\User\desktop" myfile.torrent
::start "" Aria2c.exe --seed-ratio=0.0 --enable-dht=false --dir="%userprofile%\desktop" myfile.torrent
start "" "%seederClientPath%\%seederClientexe%" %seederClientSyntax% "%deployClientPathAbsPath%\%torrentfileName%"


goto end


::startFunctionList::
::generate configuration .ini from default settings
:genConfig
set scriptName=%~nx0
set outfile=%~n0.ini
if exist %~n0.old.ini del %~n0.old.ini
if exist %~n0.ini ren %~n0.ini %~n0.old.ini

::[9]::start Default settings::
for /f "skip=2 delims=[] tokens=1-10" %%a in ('find /n /i "::start Default settings::" %scriptName%') do (set startLine=%%a
goto continue0)
:continue0

::not being able to parse empty lines messes up the counting (and output file), hence +8
::[69]::end Default settings::
for /f "skip=2 delims=[] tokens=1-10" %%a in ('find /n /i "::end Default settings::" %scriptName%') do (set /a endLine=%%a-%startLine%+8
goto continue1)
:continue1

if exist "%outfile%" del "%outfile%"

echo ::Configuration file for %scriptName%::>>"%outfile%"
echo ::Settings in this file take precedence over default settings>>"%outfile%"
echo ::There are no default settings for the Image file, the unattend.xml path\type or driver path,>>"%outfile%"
echo ::those are .wim specific and must be specified at execution time.>>"%outfile%"
echo. >>"%outfile%"

for /f "skip=2 delims=[] tokens=1-10" %%a in ('find /n /i "::server-side configuration::" %scriptName%') do (set /a lineBreak2=%%a-2
goto continue2)
:continue2

for /f "skip=2 delims=[] tokens=1-10" %%a in ('find /n /i "::server-side control flow::" %scriptName%') do (set /a lineBreak3=%%a-3
goto continue3)
:continue3

for /f "skip=2 delims=[] tokens=1-10" %%a in ('find /n /i "::settings for both server and clients::" %scriptName%') do (set /a lineBreak4=%%a-4
goto continue4)
:continue4

for /f "skip=2 delims=[] tokens=1-10" %%a in ('find /n /i "::client-side settings configuration::" %scriptName%') do (set /a lineBreak5=%%a-5
goto continue5)
:continue5

for /f "skip=2 delims=[] tokens=1-10" %%a in ('find /n /i "::client-side control flow::" %scriptName%') do (set /a lineBreak6=%%a-6
goto continue6)
:continue6

for /f "skip=2 delims=[] tokens=1-10" %%a in ('find /n /i "::custom client-side scripts::" %scriptName%') do (set /a lineBreak7=%%a-7
goto continue7)
:continue7

::3 types of input
::set default_ (normal)
::::set default_ (comment)
::comment (regular comment)
set counter=%startLine%

for /f "skip=%startLine% tokens=1-2 delims=_" %%a in (%scriptName%) do (
if "%%b" neq "" if "%%a" neq "::set default" echo %%b>>"%outfile%"
if "%%a" equ "::set default" echo ::%%b>>"%outfile%"
if "%%a" neq "" if "%%a" neq "::set default" if "%%a" neq "set default" echo %%a>>"%outfile%"
set /a counter=!counter!+1
if !counter! geq %endline% goto continue8
if /i "%lineBreak2%" neq "" if !counter! equ %lineBreak2% echo. >>"%outfile%"
if /i "%lineBreak3%" neq "" if !counter! equ %lineBreak3% echo. >>"%outfile%"
if /i "%lineBreak4%" neq "" if !counter! equ %lineBreak4% echo. >>"%outfile%"
if /i "%lineBreak5%" neq "" if !counter! equ %lineBreak5% echo. >>"%outfile%"
if /i "%lineBreak6%" neq "" if !counter! equ %lineBreak6% echo. >>"%outfile%"
if /i "%lineBreak7%" neq "" if !counter! equ %lineBreak7% echo. >>"%outfile%"
)
:continue8

echo. >>"%outfile%"
goto end


::cleanupInput expects %1 the raw input to clean up and %2, the variable to put the result in
::call :cleanupInput "d:\mypath\withtrailing\spaces\  " cleaner
:cleanInput
if "%~1" equ "" goto :eof
set rawInput=%~1
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ "\" set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
set %~2=%rawInput%
goto :eof


::verifyExtension "%customPostOobeScript%" customPostOobeScript
:verifyExtension
set rawinput=%~1
set rawextension=%~x1
if /i "%rawextension%" neq ".bat" if /i "%rawextension%" neq ".cmd" if /i "%rawextension%" neq ".vbs" if /i "%rawextension%" neq ".exe" (
echo    error %rawinput% does not have a valid extension for execution: "%rawextension%"
set %~2=invalid)
goto :eof


::getWimInfo expects a wimfile and index
::call :getWimInfo d:\mywimfile.wim 4
:getWimInfo
if not exist "%~1" (echo        error please specify a valid image file. The following file does not exist:
echo         "%~1"
goto end)
set dismInfoSyntax=/get-wiminfo /wimfile:"%~1" /index:"%~2"
if exist "%dismPathAndExe%" "%dismPathAndExe%" %dismInfoSyntax% > tempWimInfo.txt 
if not exist "%dismPathAndExe%" dism %dismInfoSyntax% > tempWimInfo.txt
for /f "tokens=1,2,*" %%a in (tempWimInfo.txt) do if "%%a" equ "Name" set wimName=%%c
for /f "tokens=1-5" %%a in (tempWimInfo.txt) do if "%%a" equ "Architecture" set wimArchitecture=%%c
for /f "tokens=1-5" %%a in (tempWimInfo.txt) do if "%%a" equ "Edition" set wimEdition=%%c
for /f "tokens=1-5" %%a in (tempWimInfo.txt) do if "%%a" equ "Version" set rawWimOSVersion=%%c
for /f "tokens=1,2 delims=." %%i in ("%rawWimOSVersion%") do set rawWimOSVersion=%%i.%%j
if exist tempWimInfo.txt del tempWimInfo.txt
::for winVista compatability
if /i "%wimEdition%" equ "<undefined>" set wimEdition=undefined
set wimOSVersion=%rawWimOSVersion%
if /i "%rawWimOSVersion%" equ "6.0" (set wimOSVersion=Vista)
if /i "%rawWimOSVersion%" equ "6.1" (set wimOSVersion=7)
if /i "%rawWimOSVersion%" equ "6.2" (set wimOSVersion=8)
if /i "%rawWimOSVersion%" equ "6.3" (set wimOSVersion=81)
if /i "%rawWimOSVersion%" equ "10.0" (set wimOSVersion=10)
if /i "%wimArchitecture%" neq "x86" if /i "%wimArchitecture%" neq "x64" echo error determining .wim architecture "%wimArchitecture%" is not valid
goto :eof


::Usage: hashCheck expects a file %1 as input, defaults to crc32, outputs the hash + name of the file separated by a space
::hashCheck x:\myfile.wim
::hashCheck x:\myfile.wim crc32
:hashCheck 
@echo off

set tempfile=rawHashOutput.txt
"%sevenz%" h -scrc%hashtype% "%~1" > %tempfile%

for /f "tokens=1-10" %%a in ('find /i /c "Cannot open" %tempfile%') do set errorlevel=%%c
if /i "%errorlevel%" neq "0" (echo   Unable to generate hash, file currently in use
if exist "%tempfile%" del "%tempfile%"
goto :eof)

for /f "skip=2 tokens=1-10" %%a in ('find /i "for data" %tempfile%') do echo %%d %filename%
if exist "%tempfile%" del "%tempfile%"
goto :eof


::parsePath returns drive, extension, lastEntry, filename, foldername, filepath, folderpath (no trailing \ either at the start or end, and not incl the last entry), fullfolderpath (again, no last entry) and fullpath
::if not valid will return nul for a value (check for it, especially folderpath will be nul if asked to parse d:\), maximum depth=26
::a non-serialized version with spaces and comments for debuging and alteration is available at D:\workspace\generalInfo\code snippets\strings\buildPathv2.bat
::Syntax:
::echo drive=%drive%                                       &:: returns nul if driveFlag ":" was not set
::echo extension=%extension%                       &:: just the extension no dot, but returns nul if folderFlag "\" is set
::echo lastEntry=%lastEntry%                          &:: consistently returns folder/filename in rawFormat
::echo filename=%filename%                           &:: filename with no extension but returns nul if folderFlag "\" was set
::echo foldername=%foldername%                 &:: returns 2nd to last name in path, unless folderFlag, then returns lastEntry
::echo filepath=%filepath%                               &:: does not include last entry (same as folderpath)
::echo folderpath=%folderpath%                      &:: does not include last entry (same as filepath)
::echo fullfolderpath=%fullfolderpath%             &:: this is the folderpath with the drive letter but not lastEntry
::echo fullpath=%fullpath%                                &:: this is the folderpath with the drive letter and lastEntry
::Example: call :parsePath  d:\my\lo ng\p ath.txt
::echo drive=%drive%                                       d:
::echo extension=%extension%                       txt
::echo lastEntry=%lastEntry%                          p ath.txt
::echo filename=%filename%                          path
::echo foldername=%foldername%                 p ath.txt
::echo filepath=%filepath%                               my\lo ng
::echo folderpath=%folderpath%                      my\lo ng
::echo fullfolderpath=%fullfolderpath%            d:\my\lo ng
::echo fullpath=%fullpath%                                d:\my\lo ng\p ath.txt
:parsePath
if "%~1" equ "" goto :eof
set folderFlag=false&set rawDriveFlag=false&set oneEntryFlag=false&set twoEntryFlag=false&set rawInput=%~1
if /i "%rawInput:~-1%" equ "\" set folderFlag=true
if /i "%rawInput:~-1%" equ "\" set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
if /i "%rawInput:~-1%" equ " " set rawInput=%rawInput:~,-1%
set windows_extension=%~x1&set windows_filename_noext=%~n1
for /f "tokens=1-26 delims=\" %%a in ("%rawInput%") do (set entry0=%%a&set entry1=%%b&set entry2=%%c&set entry3=%%d&set entry4=%%e&set entry5=%%f&set entry6=%%g&set entry7=%%h&set entry8=%%i&set entry9=%%j&set entry10=%%k&set entry11=%%l&set entry12=%%m&set entry13=%%n&set entry14=%%o&set entry15=%%p&set entry16=%%q&set entry17=%%r&set entry18=%%s&set entry19=%%t&set entry20=%%u&set entry21=%%v&set entry22=%%w&set entry23=%%x&set entry24=%%y&set entry25=%%z)
set counter=0
for /l %%a in (0,1,25) do if /i "!entry%%a%!" neq "" set /a counter+=1
set /a maxPaths=%counter%-1
if "!entry0:~-1!" equ ":" set rawDriveFlag=true
if %maxPaths% equ 0 (set oneEntryFlag=true
goto assignOutput)
if %maxPaths% equ 1 (set twoEntryFlag=true
goto assignOutput)
if exist tempFilePaths.txt del tempFilePaths.txt&set string=invalid
set /a maxPaths=%counter%-2
for /l %%a in (1,1,%maxPaths%) do echo !entry%%a%!>>tempFilePaths.txt
if exist tempFilePaths.txt set /p string=<tempFilePaths.txt
for /f "skip=1 tokens=*" %%a in (tempFilePaths.txt) do set string=!string!\%%a
if exist tempFilePaths.txt del tempFilePaths.txt
set secondToLastEntry=!entry%maxPaths%!
set /a maxPaths=%counter%-1
set lastEntry=!entry%maxPaths%!
:assignOutput
if /i "%rawDriveFlag%" equ "true" (set drive=!entry0!)
if /i "%rawDriveFlag%" neq "true" (set drive=nul)
if "%oneEntryFlag%" equ "true" if /i "%rawDriveFlag%" equ "true" (set lastEntry=!entry0!&set foldername=nul&set filepath=nul&set folderpath=nul&set fullfolderpath=!entry0!&set fullpath=!entry0!&goto finalCleanup)
if "%oneEntryFlag%" equ "true" if /i "%rawDriveFlag%" equ "false" (set lastEntry=!entry0!&set foldername=!entry0!&set filepath=nul&set folderpath=nul&set fullfolderpath=nul&set fullpath=nul&goto finalCleanup)
if "%twoEntryFlag%" equ "true" if /i "%rawDriveFlag%" equ "true" (set lastEntry=!entry1!&set foldername=!entry1!&set filepath=nul&set folderpath=nul&set fullfolderpath=!entry0!&set fullpath=!entry0!&goto finalCleanup)
if "%twoEntryFlag%" equ "true" if /i "%rawDriveFlag%" neq "true" (set lastEntry=!entry1!&set foldername=!entry0!&set filepath=!entry0!&set folderpath=!entry0!&set fullfolderpath=!entry0!&set fullpath=!entry0!&goto finalCleanup)
if /i "%folderFlag%" neq "true" (set lastEntry=%lastEntry%&set foldername=%lastEntry%&set filepath=%string%&set folderpath=%string%&set fullfolderpath=!entry0!\%string%&set fullpath=!entry0!\%string%\%lastEntry%&goto finalCleanup)
if /i "%folderFlag%" equ "true" (set lastEntry=%lastEntry%&set foldername=%lastEntry%&set filepath=%string%&set folderpath=%string%&set fullfolderpath=!entry0!\%string%&set fullpath=!entry0!\%string%\%lastEntry%&goto finalCleanup)
echo unspecified error&goto :eof
:finalCleanup
if /i "%windows_extension%" equ "" (set extension=nul) else (set extension=%windows_extension%)
for /f "delims=." %%a in ("%extension%") do set extension=%%a
if /i "%folderFlag%" neq "true" (set filename=%windows_filename_noext%)
if /i "%folderFlag%" equ "true" (set extension=nul&set filename=nul)
goto :eof


:booleanprompt
echo Are you sure (yes/no)?
set /p userInput=
if /i "%userInput%" equ "y" goto %callback%
if /i "%userInput%" equ "ye" goto %callback%
if /i "%userInput%" equ "yes" goto %callback%
if /i "%userInput%" equ "n" goto end
if /i "%userInput%" equ "no" goto end
goto booleanprompt
::::end Function List::::


:usageNotes
echo.
echo   Usage: %~n0 can prepare a Windows Image file (.wim) for deployment
echo   using the %~n0Client. Feel free to use the icky gooey: %~n0.exe
echo   Use %~n0.ini to configure settings or create one with /createConfig
echo.
echo   Syntax:
echo   deploy D:\wimfile.wim {index} {driversFolder} {crc32^|sha1} {unattendfile}
echo.
echo   Examples:
echo   %~n0  /createConfig
echo   %~n0  D:\mywimfile.wim 
echo   %~n0  D:\mywimfile.wim  1
echo   %~n0  D:\mywimfile.wim  2  B:\drivers\byModel\E6320\win8\x64
echo   %~n0  "D:\my file.wim"  1 "B:\drivers\Lattitude E6320\win7\x64"
echo   %~n0  D:\mywimfile.wim  1  D:\drivers\x86  crc32
echo   %~n0  D:\mywimfile.wim  1  D:\drivers\x64  sha1  RTM
echo   %~n0  D:\mywimfile.wim ""  D:\drivers\x64  ""  D:\unattend.xml
echo.
echo   Notes on Dependencies:
echo   1) %~n0.exe requires %~n0.bat (this file)
echo   2) 7z to hashCheck and serialize drivers (tip: use x64 installer)
echo   3) "resources\py3createtorrent.exe" to create .torrent files
echo   4) %~n0.ini (soft dependency) -recommended but not required
echo   5) "resources\dism\dism.exe" (soft depen) -used for wim files in "esd" format
:end 
if exist "%tempdir%" rmdir /s /q "%tempdir%"
popd
endlocal