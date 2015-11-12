
::set configFilesLocation=Y:\autodeploy\client
::set copiedOnce=true

@echo off
setlocal enabledelayedexpansion

::Pre-Usage instructions (these steps are what AriaDeploy (server) automates on behalf of this client script)
::1) pre-requisite: create .wim to deploy and put it on the server (or select an rtm.wim image)
::2) copy this file to D:\workspace\autodeploy\client and rename to something.bat (suggested: deployClient.bat)
::3) enable the local tracker if not using a dedicated one in server's torrent client (options->preferences->advanced->bt.enable_tracker)
::4) create .torrent from .wim file (use http://172.17.12.20:3200/announce as tracker if using an embedded one)
::5) (optional) calculate the crc32/sha1 hash of the .wim file "hash mywimfile.wim"
::6) update hashType and hashData of .wim file in script under "initialize variables" (leave hash as invalid if not checking it)
::7) copy the .torrent file and unattend.xml files to the autodeploy\client folder
::8) start winPE on intended machines using pxe (advised) or flashdrives/cds (v4+ preferred for reliable boot mode detection)
::9) check transfer progress on server's torrent client

::Note: %configFilesLocation%\deployClient.ini will override any settings set here.

::(optional) it really helps to have a second seed
::1) map the network drive 
::2) copy the image to the local computer (from the server)
::3) double-click on the .torrent file
::4) select the download location to the .wim file (client will take a minute to check it)
::5) should begin seeding automatically, if not right-click -> start to seed

if not defined configFilesLocation if not defined copiedOnce goto copyLocally
if not defined configFilesLocation (echo  unspecified error initalizing %~nx0
goto end)
::hummm
if /i "%configFilesLocation%" equ "x:\windows\system32" (echo   error determing correct location for server files:"%configFilesLocation%"
echo   always start %~n0 from network share, never copy locally
goto end)

call :cleanInput "%configFilesLocation%" configFilesLocation
if not exist "%configFilesLocation%" (echo  error initalizing %~nx0: "%configFilesLocation%" does not exist
goto end)

::need to know where running from, assume running from the server
::assume no files available and copy anything needed from the server's client\resources directory (architecture specific)
pushd "%systemroot%\system32"


::) set default variables
::instance specific information::
set default_imagefile=Win7Sp1Ult_x64_slim_22July15.esd
set default_imageIndex=1 
set default_unattendfileName=unattend_Win7_Ultimate_x64_advanced.xml
set default_driversArchiveName=Win7_x64_drivers.zip
set default_torrentfileName=Win7Sp1Ult_x64_slim_22July15.esd.torrent
set default_transferMode=normal
set default_hashType=crc32
set default_hashData=invalid
 
::client-side settings configuration::
set default_clientTargetDisk=0
set default_clientPartitionLayout=minimal
set default_enableUnicastFallbackForImage=true
set default_enableUnicastFallbackForDrivers=true
set default_pePathToImages=Y:\images
set default_pePathToDrivers=Y:\updates\drivers
set default_targetTempFilesLocation=recovery\oem
set default_cmdcolor=normal
set default_torrentclientexe=aria2c.exe
set default_hashGenexe=7za.exe
 
::client-side control flow::
set default_requirePrompt=false
set default_postDownloadSeedTime=5
set default_deleteImageFileAfterDeploymentCompletes=true
set default_deleteDriverArchiveAfterApplying=true
set default_restartAutomatically=false
 
::custom client-side scripts::
set default_customPreImagingScript=invalid
set default_customPostImagingScript=invalid
set default_customPostOobeScript=invalid

::names of config files::
set default_configfile=%~n0.ini


::do not change anything below this line unless you know what you're doing::


::todoList
::rewrite, deployClient should get it's settings internally 
::default settings have lowest precedence, then override using settings from .ini
::should also assume none if it's dependencies have been met
::responsible for copying any necessary files from server 
::it's either running locally (after being copied) or is running directly from the server.
::maybe have a localoverride for the remote files? if remote not defined and already copied once, then use local?
::-detect windows better (check any of the folders)-have a preferred driver order, skip if usb/optical disk is final selection
::-put cleanup disk into a function (runs chkdsk /f c: and removes folders) intent: use prior to applying image if dirty disk suspected
::Could use unattend.xml to join domains directly. leaving that to user however~

::might need to re-clean input after validation for values that were set back to default (in case default values were changed)
::Procedure:
::) if currently running from server, copy deployclient.bat and deployclient.ini locally (embedding the server path) and run again locally
::) set default variables
::) set inital values
::) update variables using deployClient.ini
::) validate values, set back to default if invalid or error out
::) get info about WinPE (incl ip)
::) set final script/instance specific configuration variables
::) if specified, prompt before going further (requirePrompt)
::) change color to specified color (cmdcolor)
::) if a preImagingScript was specified, call it now (customPreImagingScript)
::) copy required tools from server, or otherwise make sure they exist (torrentclientexe, hashGenexe to tempdir)
::) check to see if the image file already exist with windows detection code
::-if so, check to make sure current boot mode matches reccomended hard disk partition mode
::-if it doesn't, then reformat normally, if it does then don't reformat HD
::-instead update configuration variables dynamically
::-and then chkdsk and clean up the (possibly) dirty disk (experimental)
::) -if doesn't exist, reformat HD according to winPE boot mode
::) start Aria  (download to targetTempFilesLocation)
::) wait (download+seeding time)
::) change color to specified color (Aria likes to change it too, so change it back)  (cmdcolor)
::) check hash if specified (hashtype validly defined and hashdata not invalid or null) (hashgenexe h -crc)
::) if hash check fails, and if enableUnicastFalbackForImage is enabled, and if pePathToImages is not invalid, then try to search for image directly to copy it over
::) apply file to local disk (with dism)
::) make sure image is bootable (bcdboot)
::) update drivers
::-if exist, copy drivers archive file (targetTempFilesLocation)
::-extract to subfolder (targetTempFilesLocation\drivers)
::-apply drivers (dism /add-driver /recurse)
::-if not exist, try for WMI autodetect (detect if wmic.exe is available) 
:: if archive not availabe, if wmi exist (maybe later add funtionality:-try to download from configlocation\drivers\Dell_Lattitude e6220_win7_x64_drivers.torrent)
::-if archive not available, if wmi exist, if unicastfallback is enabled, if pePathtoDrivers is not invalid, try searching it for Dell\Lattitude e6220\win7\x64
::-if that still doesn't work give up 
::) copy scripts (unattend.xml)
::check if predefined script exist, if so, force copy  (unattendfileName)
::if it doesn't exist, try for an RTM local copy and only copy if one is not already embeded in the image (unattend_win7_enterprise_x64_rtm.xml)
::) if a postImagingScript was specified, call it now (customPostImagingScript)
::) if a customPostOobeScript was specified, copy it to the targetTempFilesLocation path  (customPostOobeScript)
::) remove raw driver archive/files (if specified) (deleteDriverArchiveAfterApplying)
::) remove image (if specified)  (deleteImageFileAfterDeploymentCompletes)
::) reboot (if specified) (restartAutomatically)


::) set inital values
::instance specific information::
set imagefileName=%default_imagefile%
set imageIndex=%default_imageIndex%
set unattendfileName=%default_unattendfileName%
set driversArchiveName=%default_driversArchiveName%
set torrentfileName=%default_torrentfileName%
set transferMode=%default_transferMode%
set hashType=%default_hashType%
set hashData=%default_hashData%
 
::client-side settings configuration::
set clientTargetDisk=%default_clientTargetDisk%
set clientPartitionLayout=%default_clientPartitionLayout%
set enableUnicastFallbackForImage=%default_enableUnicastFallbackForImage%
set enableUnicastFallbackForDrivers=%default_enableUnicastFallbackForDrivers%
set pePathToImages=%default_pePathToImages%
set pePathToDrivers=%default_pePathToDrivers%
set targetTempFilesLocation=%default_targetTempFilesLocation%
set cmdcolor=%default_cmdcolor%
set torrentclientexe=%default_torrentclientexe%
set hashGenexe=%default_hashGenexe%
 
::client-side control flow::
set requirePrompt=%default_requirePrompt%
set postDownloadSeedTime=%default_postDownloadSeedTime%
set deleteImageFileAfterDeploymentCompletes=%default_deleteImageFileAfterDeploymentCompletes%
set deleteDriverArchiveAfterApplying=%default_deleteDriverArchiveAfterApplying%
set restartAutomatically=%default_restartAutomatically%
 
::custom client-side scripts::
set customPreImagingScript=%default_customPreImagingScript%
set customPostImagingScript=%default_customPostImagingScript%
set customPostOobeScript=%default_customPostOobeScript%

::names of config files::
set configfile=%default_configfile%

::) update variables using deployClient.ini
if not exist "%configfile%" goto skipSettingsUpdate
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "imagefileName=" %configfile%') do if /i "%%j" neq "" set imagefileName=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "imageIndex=" %configfile%') do if /i "%%j" neq "" set imageIndex=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "unattendfileName=" %configfile%') do if /i "%%j" neq "" set unattendfileName=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "driversArchiveName=" %configfile%') do if /i "%%j" neq "" set driversArchiveName=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "torrentfileName=" %configfile%') do if /i "%%j" neq "" set torrentfileName=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "transferMode=" %configfile%') do if /i "%%j" neq "" set transferMode=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "hashType=" %configfile%') do if /i "%%j" neq "" set hashType=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "hashData=" %configfile%') do if /i "%%j" neq "" set hashData=%%j

for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "clientTargetDisk=" %configfile%') do if /i "%%j" neq "" set clientTargetDisk=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "clientPartitionLayout=" %configfile%') do if /i "%%j" neq "" set clientPartitionLayout=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "enableUnicastFallbackForImage=" %configfile%') do if /i "%%j" neq "" set enableUnicastFallbackForImage=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "enableUnicastFallbackForDrivers=" %configfile%') do if /i "%%j" neq "" set enableUnicastFallbackForDrivers=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "pePathToImages=" %configfile%') do if /i "%%j" neq "" set pePathToImages=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "pePathToDrivers=" %configfile%') do if /i "%%j" neq "" set pePathToDrivers=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "targetTempFilesLocation=" %configfile%') do if /i "%%j" neq "" set targetTempFilesLocation=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "cmdcolor=" %configfile%') do if /i "%%j" neq "" set cmdcolor=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "torrentclientexe=" %configfile%') do if /i "%%j" neq "" set torrentclientexe=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "hashGenexe=" %configfile%') do if /i "%%j" neq "" set hashGenexe=%%j

for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "requirePrompt=" %configfile%') do if /i "%%j" neq "" set requirePrompt=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "postDownloadSeedTime=" %configfile%') do if /i "%%j" neq "" set postDownloadSeedTime=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "deleteImageFileAfterDeploymentCompletes=" %configfile%') do if /i "%%j" neq "" set deleteImageFileAfterDeploymentCompletes=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "deleteDriverArchiveAfterApplying=" %configfile%') do if /i "%%j" neq "" set deleteDriverArchiveAfterApplying=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "restartAutomatically=" %configfile%') do if /i "%%j" neq "" set restartAutomatically=%%j

for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "customPreImagingScript=" %configfile%') do if /i "%%j" neq "" set customPreImagingScript=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "customPostImagingScript=" %configfile%') do if /i "%%j" neq "" set customPostImagingScript=%%j
for /f "skip=2 eol=: delims== tokens=1-10" %%i in ('find /i "customPostOobeScript=" %configfile%') do if /i "%%j" neq "" set customPostOobeScript=%%j
:skipSettingsUpdate


::) get info about WinPE (incl ip)
::sets these variables: %winPEVersion%  %winPEArchitecture%  %bootMode%  %current_ip%
call :winPEInfo

call :cleanInput "%winPEVersion%" winPEVersion
call :cleanInput "%winPEArchitecture%" winPEArchitecture
call :cleanInput "%bootMode%" bootMode
call :cleanInput "%current_ip%" current_ip

call :cleanInput "%imagefileName%" imagefileName
call :cleanInput "%imageIndex%" imageIndex
call :cleanInput "%unattendfileName%" unattendfileName
call :cleanInput "%driversArchiveName%" driversArchiveName
call :cleanInput "%torrentfileName%" torrentfileName
call :cleanInput "%transferMode%" transferMode
call :cleanInput "%hashType%" hashType
call :cleanInput "%hashData%" hashData

call :cleanInput "%clientTargetDisk%" clientTargetDisk
call :cleanInput "%clientPartitionLayout%" clientPartitionLayout
call :cleanInput "%enableUnicastFallbackForImage%" enableUnicastFallbackForImage
call :cleanInput "%enableUnicastFallbackForDrivers%" enableUnicastFallbackForDrivers
call :cleanInput "%pePathToImages%" pePathToImages
call :cleanInput "%pePathToDrivers%" pePathToDrivers
call :cleanInput "%targetTempFilesLocation%" targetTempFilesLocation
call :cleanInput "%cmdcolor%" cmdcolor
call :cleanInput "%torrentclientexe%" torrentclientexe
call :cleanInput "%hashGenexe%" hashGenexe

call :cleanInput "%requirePrompt%" requirePrompt
call :cleanInput "%postDownloadSeedTime%" postDownloadSeedTime
call :cleanInput "%deleteImageFileAfterDeploymentCompletes%" deleteImageFileAfterDeploymentCompletes
call :cleanInput "%deleteDriverArchiveAfterApplying%" deleteDriverArchiveAfterApplying
call :cleanInput "%restartAutomatically%" restartAutomatically

call :cleanInput "%customPreImagingScript%" customPreImagingScript
call :cleanInput "%customPostImagingScript%" customPostImagingScript
call :cleanInput "%customPostOobeScript%" customPostOobeScript


::) validate values, set back to default if invalid or error out
::PE verison should be 2.0,3.x,4.0,5.x,10
if /i "%winPEVersion%" neq "2.0" if /i "%winPEVersion%" neq "3.x" if /i "%winPEVersion%" neq "4.0" if /i "%winPEVersion%" neq "5.x" if /i "%winPEVersion%" neq "10.0" (echo   error determining winPEVersion:"%winPEVersion%"
set winPEVersion=invalid)
 
::internal version should be 2,31,4,51,10
if /i "%winPEInternalVersion%" neq "2"  if /i "%winPEInternalVersion%" neq "31" if /i "%winPEInternalVersion%" neq "4" if /i "%winPEInternalVersion%" neq "51" if /i "%winPEInternalVersion%" neq "10" (echo   winPEInternalVersion error:"%winPEInternalVersion%"
set winPEInternalVersion=invalid)

if /i "%winPEArchitecture%" neq "x86" if /i "%winPEArchitecture%" neq "x64" (echo    winPEArchitecture setting invalid:"%winPEArchitecture%" resetting to: "%processor_architecture%"
set winPEArchitecture=%processor_architecture%)

if /i "%bootMode%" neq "BIOS" if /i "%bootMode%" neq "UEFI"  if /i "%bootMode%" neq "Unknown" (echo    bootmode unrecognized:"%bootMode%"
set bootMode=Unknown)

::verifyExtension "%customPostOobeScript%" customPostOobeScript {exec or wim or xml or archive or torrent}  hummmm

call :verifyExtension "%imagefileName%" imagefileName wim
if /i "%imagefileName%" equ "invalid" (echo   Could not verify "%imagefileName%" Please enter a valid image name
goto end)

if /i "%imageIndex%" neq "1" if /i "%imageIndex%" neq "2" if /i "%imageIndex%" neq "3" if /i "%imageIndex%" neq "4" if /i "%imageIndex%" neq "5" if /i "%imageIndex%" neq "6" if /i "%imageIndex%" neq "7" if /i "%imageIndex%" neq "8" if /i "%imageIndex%" neq "9" (echo   Valid image index not specified:"%imageIndex%"
goto end)

::unattend name can be invalid or an xml file, if not valid then change to invalid
if /i "%unattendfileName%" neq "invalid" call :verifyExtension "%unattendfileName%" unattendfileName xml

if /i "%driversArchiveName%" neq "invalid" call :verifyExtension "%driversArchiveName%" driversArchiveName archive

if /i "%torrentfileName%" neq "invalid" call :verifyExtension "%torrentfileName%" torrentfileName torrent
::if torrent file name is invalid, will need to skip to unicast mode, if enableUnicastfallbackforImage is not true then deployment will fail, check before formatting disk

if /i "%transferMode%" neq "private" if /i "%transferMode%" neq "normal" if /i "%transferMode%" neq "noisy" (echo   network transfer mode settings is invalid:"%transferMode%" setting to %default_transferMode%
set createTorrent=%default_transferMode%)

::if the hashType is invalid, assume the hashData doesn't match
if /i "%hashType%" neq "crc32" if /i "%hashType%" neq "crc64" if /i "%hashType%" neq "sha1" if /i "%hashType%" neq "sha256" (
echo   hashType is invalid:"%hashType%" setting to "%default_hashType%"
set hashType=%default_hashType%
set hashData=invalid)

::if the data is invalid, there's no reason to have a type
if /i "%hashData%" equ "invalid" (set hashType=invalid)

if %clientTargetDisk% neq 0 if %clientTargetDisk% neq 1 if %clientTargetDisk% neq 2 if %clientTargetDisk% neq 3 if %clientTargetDisk% neq 4 (echo   error reading clientTargetDisk from config file "%clientTargetDisk%" setting to %default_clientTargetDisk%
set clientTargetDisk=%default_clientTargetDisk%)

if "%clientPartitionLayout%" neq "minimal" if "%clientPartitionLayout%" neq "normal" (echo   error reading clientPartitionLayout:"%clientPartitionLayout%" setting to %default_clientPartitionLayout%
set clientPartitionLayout=%default_clientPartitionLayout%)

if /i "%enableUnicastFallbackForImage%" neq "true" if /i "%enableUnicastFallbackForImage%" neq "false" (echo    error in Image unicast fallback setting: "%enableUnicastFallbackForImage%" changing to "%default_enableUnicastFallbackForImage%"
set enableUnicastFallbackForImage=%default_enableUnicastFallbackForImage%)

if /i "%enableUnicastFallbackForDrivers%" neq "true" if /i "%enableUnicastFallbackForDrivers%" neq "false" (echo    error in drivers unicast fallback setting: "%enableUnicastFallbackForDrivers%" changing to "%default_enableUnicastFallbackForDrivers%"
set enableUnicastFallbackForDrivers=%default_enableUnicastFallbackForDrivers%)

::if the one specified doesn't exist, but the default one does, set to default, else if the one specified doesn't exist and neither does the default one, set to invalid
if not exist "%pePathToImages%" set pePathToImages=invalid
if /i "%pePathToImages%" equ "invalid" if exist "%default_pePathToImages%" (echo   path to Image repository does not exist set to default
set pePathToImages=%default_pePathToImages%)

if /i "%targetTempFilesLocation%" equ "invalid" set targetTempFilesLocation=%default_targetTempFilesLocation%

::normal,red,yellow,green,miku,purple,white
if /i "%cmdcolor%" neq "normal" if /i "%cmdcolor%" neq "red" if /i "%cmdcolor%" neq "yellow" if /i "%cmdcolor%" neq "green" if /i "%cmdcolor%" neq "Miku" if /i "%cmdcolor%" neq "purple" if /i "%cmdcolor%" neq "white" (echo    cmd color not supported:"%cmdcolor%" resetting to "%default_cmdcolor%"
set cmdcolor=%default_cmdcolor%)

::make sure torrentClient is actually an executable
if /i "%torrentclientexe%" neq "invalid" call :verifyExtension "%torrentclientexe%" torrentclientexe executable

::make sure hashCheck exe is actually an executable
if /i "%hashGenExe%" neq "invalid" call :verifyExtension "%hashGenExe%" hashGenExe executable

if /i "%requirePrompt%" neq "true" if /i "%requirePrompt%" neq "false" (echo  prompt setting invalid, setting to %default_requirePrompt%
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
call :cleanInput "%winPEVersion%" winPEVersion
call :cleanInput "%winPEArchitecture%" winPEArchitecture
call :cleanInput "%bootMode%" bootMode
call :cleanInput "%current_ip%" current_ip

call :cleanInput "%configFilesLocation%" configFilesLocation

call :cleanInput "%imagefileName%" imagefileName
call :cleanInput "%imageIndex%" imageIndex
call :cleanInput "%unattendfileName%" unattendfileName
call :cleanInput "%driversArchiveName%" driversArchiveName
call :cleanInput "%torrentfileName%" torrentfileName
call :cleanInput "%transferMode%" transferMode
call :cleanInput "%hashType%" hashType
call :cleanInput "%hashData%" hashData

call :cleanInput "%clientTargetDisk%" clientTargetDisk
call :cleanInput "%clientPartitionLayout%" clientPartitionLayout
call :cleanInput "%enableUnicastFallbackForImage%" enableUnicastFallbackForImage
call :cleanInput "%enableUnicastFallbackForDrivers%" enableUnicastFallbackForDrivers
call :cleanInput "%pePathToImages%" pePathToImages
call :cleanInput "%pePathToDrivers%" pePathToDrivers
call :cleanInput "%targetTempFilesLocation%" targetTempFilesLocation
call :cleanInput "%cmdcolor%" cmdcolor
call :cleanInput "%torrentclientexe%" torrentclientexe
call :cleanInput "%hashGenexe%" hashGenexe

call :cleanInput "%requirePrompt%" requirePrompt
call :cleanInput "%postDownloadSeedTime%" postDownloadSeedTime
call :cleanInput "%deleteImageFileAfterDeploymentCompletes%" deleteImageFileAfterDeploymentCompletes
call :cleanInput "%deleteDriverArchiveAfterApplying%" deleteDriverArchiveAfterApplying
call :cleanInput "%restartAutomatically%" restartAutomatically

call :cleanInput "%customPreImagingScript%" customPreImagingScript
call :cleanInput "%customPostImagingScript%" customPostImagingScript
call :cleanInput "%customPostOobeScript%" customPostOobeScript



::) set final script/instance specific configuration variables
:setFinalConfigSettings
wpeutil disablefirewall
set resourcesPath=%configFilesLocation%\resources\%winPEArchitecture%
set driversTorrentfilesPath=%configFilesLocation%\resources\drivers
set tempWinPEdir=tools\temp
if not exist %tempWinPEdir% mkdir %tempWinPEdir%
set hashCheckSyntax=invalid
set installDriversFromArchive=false
set findHashStatus=false
set wmiAvailable=false
set restartedFlag=false

::) if specified, prompt before going further (requirePrompt)
if /i "%requirePrompt%" equ "true" (set callback=afterRequirePrompt
echo.
echo      Will now attempt to download and install %imagefileName%
echo      Disk %clientTargetDisk% will be  formatted 
echo      ALL local DATA WILL BE LOST UPON CONTINUE
goto booleanprompt
)
:afterRequirePrompt


::) change color to use specified one (cmdcolor)
if /i "%cmdcolor%" equ "normal" set newcolor=07
if /i "%cmdcolor%" equ "red" set newcolor=0c
if /i "%cmdcolor%" equ "yellow" set newcolor=0e
if /i "%cmdcolor%" equ "green" set newcolor=0a
if /i "%cmdcolor%" equ "miku" set newcolor=0b
if /i "%cmdcolor%" equ "purple" set newcolor=0d
if /i "%cmdcolor%" equ "white" set newcolor=0f
if defined newcolor color %newcolor%


::) if a preImagingScript was specified, call it now (customPreImagingScript)
if /i "%customPreImagingScript%" neq "invalid" if exist "%configFilesLocation%\%customPreImagingScript%" (
copy /y "%configFilesLocation%\%customPreImagingScript%" ".\%customPreImagingScript%")
if exist "%customPreImagingScript%" call "%customPreImagingScript%"


::) copy required tools from server, or otherwise make sure they exist (torrentclientexe, hashGenexe, sevenz to tempWinPEdir)
::resourcesPath\torrentclientexe
::resourcesPath\hashGenExe
::configFilesLocation\torrentfileName
::configFilesLocation\customPostImagingScript
::configFilesLocation\customPostOobeScript
::configFilesLocation\driversArchiveName  (?) (wait until after imaging completes)

if exist "%resourcesPath%\%torrentClientExe%" (
copy /y "%resourcesPath%\%torrentClientExe%" "%tempWinPEdir%\%torrentClientExe%")

if exist "%resourcesPath%\%hashGenExe%" (
copy /y "%resourcesPath%\%hashGenExe%" "%tempWinPEdir%\%hashGenExe%")

if exist "%configFilesLocation%\%torrentfileName%" (
copy /y "%configFilesLocation%\%torrentfileName%" "%tempWinPEdir%\%torrentfileName%")

if /i "%unattendfileName%" neq "invalid" if exist "%configFilesLocation%\%unattendfileName%" (
copy /y "%configFilesLocation%\%unattendfileName%" "%tempWinPEdir%\%unattendfileName%")

if /i "%customPostImagingScript%" neq "invalid" if exist "%configFilesLocation%\%customPostImagingScript%" (
copy /y "%configFilesLocation%\%customPostImagingScript%" ".\%customPostImagingScript%")

if /i "%customPostOobeScript%" neq "invalid" if exist "%configFilesLocation%\%customPostOobeScript%" (
copy /y "%configFilesLocation%\%customPostOobeScript%" ".\%customPostOobeScript%")

::find 7z
call :findsevenz


::some extra sanity checks and control flow checks (make sure some incompatible configuration setting combinations don't occur)
:doFinalControlFlowChecks
::validate the fallback- if not exist the fallback paths, then disable the fallback mechanisms
if not exist "%pePathToImages%" set enableUnicastFallbackForImage=false
if not exist "%pePathToDrivers%" set enableUnicastFallbackForDrivers=false

::need to make sure torrentclientexe is actually valid, if invalid, then disable downloading over torrent
if not exist "%tempWinPEdir%\%torrentClientExe%" set torrentClientExe=invalid
if not exist "%tempWinPEdir%\%torrentfileName%" set torrentClientExe=invalid

::if neither it's not possible to torrent the image file or to unicast it, then error out
if not exist "%tempWinPEdir%\%torrentClientExe%" if not exist "%pePathToImages%" (echo    error could not download the required files for deploying %imagefileName%
goto end)

::if the archive exist on the server, set install from archive to true, but only if sevenz also exist
if exist "%configFilesLocation%\%driversArchiveName%" set installDriversFromArchive=true
if not exist "%sevenz%" set installDriversFromArchive=false

::if hashGenExe is valid, and if neither hashType nor hashData have been set to invalid, then enable hash checking
if exist "%tempWinPEdir%\%hashGenExe%" if /i "%hashType%" neq "invalid" if /i "%hashData%" neq "invalid" set findHashStatus=true

::if WMI is available, enable wmiAvailable flag
if exist "wbem\wmic.exe" set wmiAvailable=true

::if WMI is not available, leave wmiAvailable to false and disable unicastFallBack
if not exist wbem\wmic.exe set enableUnicastFallbackForDrivers=false
 
::need a valid targetTempFilesLocation in case the image redeployment fails but is started again 
::(since it needs to be updated dynamically, needs to be reset as well)
set original_targetTempFilesLocation=%targetTempFilesLocation%

::A note about how drivers are currently handled: 1) from archive, 2) wmi torrent 3) wmi path, 4) dism /add-driver "blind path"  (#4 not implemented)
::only one of the unicast fallback mechanisms (wmi path) requires WMI, the other could potentially be a path to blindly install drivers from but
::that would need to be a seperate path or have a blindlyInstall from flag, maybe implement later, for now just disable unicast fallback completely


::) check to see if the image file already exist with windows detection code, if it does, then try to resume instead of starting over
::-check to make sure current boot mode matches reccomended hard disk partition mode
::-if it doesn't, then reformat normally, if it does then don't reformat HD
::-instead update configuration variables dynamically
::-and then chkdsk and clean up the (possibly) dirty disk (experimental)

::if the file already exist, assume that the client had to be restarted
::and just pick up where the download left off instead of starting over (experimental)
if exist "B:\%targetTempFilesLocation%\%imagefileName%" call :resumeInterupted B:
if exist "C:\%targetTempFilesLocation%\%imagefileName%" call :resumeInterupted C:
if exist "D:\%targetTempFilesLocation%\%imagefileName%" call :resumeInterupted D:
if exist "E:\%targetTempFilesLocation%\%imagefileName%" call :resumeInterupted E:
if exist "W:\%targetTempFilesLocation%\%imagefileName%" call :resumeInterupted W:
if /i "%restartedFlag%" equ "true" goto startTorrentClientForImage

:formatHD
::If existing image wasn't found, then set default drive to B:
set winDrive=B:
::if bootmode is BIOS or unknown, then partition as MBR, if UEFI then partition as GPT. Make sure S:\ is valid for bcdboot later
if /i "%bootmode%" equ "UEFI" goto formatGPTminimal

:formatBIOSminimal
if "%clientPartitionLayout%" equ "normal" goto formatBIOSnormal
set diskLayoutConfig=formatMBRminimal.bat
echo sel disk %clientTargetDisk% >%diskLayoutConfig%
echo clean >>%diskLayoutConfig%
echo create partition primary >>%diskLayoutConfig%
echo active >>%diskLayoutConfig%
echo format fs=ntfs quick label="Windows" >>%diskLayoutConfig%
echo assign letter=B: noerr >>%diskLayoutConfig%
diskpart /s %diskLayoutConfig%
subst s: b:\
subst r: b:\
goto startTorrentClientForImage

:formatBIOSnormal
set diskLayoutConfig=formatMBRnormal.bat
echo sel disk %clientTargetDisk% >%diskLayoutConfig%
echo clean >>%diskLayoutConfig%
echo create part pri size=1024 >>%diskLayoutConfig%
echo set id=27 >>%diskLayoutConfig%
echo active >>%diskLayoutConfig%
echo format fs=ntfs quick label="System" >>%diskLayoutConfig%
echo assign letter=S: noerr >>%diskLayoutConfig%
echo create partition primary >>%diskLayoutConfig%
echo format fs=ntfs quick label="Windows" >>%diskLayoutConfig%
echo assign letter=B: noerr >>%diskLayoutConfig%
diskpart /s %diskLayoutconfig%
subst r: b:\
goto startTorrentClientForImage

:formatGPTminimal
if "%clientPartitionLayout%" equ "normal" goto formatUEFInormal
set diskLayoutConfig=formatGPTminimal.bat
echo sel disk %clientTargetDisk% >%diskLayoutConfig%
echo clean >>%diskLayoutConfig%
echo convert gpt >>%diskLayoutConfig%
echo create partition efi size=300 >>%diskLayoutConfig%
echo format fs=fat32 quick label="System" >>%diskLayoutConfig%
echo assign letter=S: noerr >>%diskLayoutConfig%
echo create partition msr size=128 >>%diskLayoutConfig%
echo create part pri >>%diskLayoutConfig%
echo format fs=ntfs quick label="Windows" >>%diskLayoutConfig%
echo assign letter=B: noerr >>%diskLayoutConfig%
diskpart /s %diskLayoutConfig%
subst r: b:\
goto startTorrentClientForImage

:formatUEFInormal
set diskLayoutConfig=formatGPTnormal.bat
echo sel disk %clientTargetDisk% >%diskLayoutConfig%
echo clean >>%diskLayoutConfig%
echo convert gpt >>%diskLayoutConfig%
echo create partition efi size=300 >>%diskLayoutConfig%
echo format fs=fat32 quick label="System" >>%diskLayoutConfig%
echo assign letter=S: noerr >>%diskLayoutConfig%
echo create partition msr size=128 >>%diskLayoutConfig%
echo create partition pri size=1024 >>%diskLayoutConfig%
echo set id=de94bba4-06d1-4d40-a16a-bfd50179d6ac >>%diskLayoutConfig%
echo gpt attributes=0x8000000000000001 >>%diskLayoutConfig%
echo format fs=ntfs quick label="Recovery" >>%diskLayoutConfig%
echo assign letter=R: noerr >>%diskLayoutConfig%
echo create part pri >>%diskLayoutConfig%
format fs=ntfs quick label="Windows" >>%diskLayoutConfig%
assign letter=B: noerr >>%diskLayoutConfig%
diskpart /s %diskLayoutConfig%


::5) set client options and start client
::do not know the drive letter for targetTempFilesLocation until after formatted, so must be here (not further up)
:startTorrentClientForImage

if not exist %winDrive%  echo   unspecified error could not detect destination drive for image&goto end
if /i "%torrentclientexe%" equ "invalid" goto unicastImage
set targetTempFilesLocation=%winDrive%\%targetTempFilesLocation%
if not exist "%targetTempFilesLocation%" mkdir "%targetTempFilesLocation%"

if /i "%transferMode%" neq "noisy" (
set torrentclientSyntax=--check-integrity=true --seed-time=%postDownloadSeedTime% --dir="%targetTempFilesLocation%" --bt-seed-unverified=true --bt-external-ip=%current_ip% --enable-dht=false --bt-enable-lpd=false --enable-peer-exchange=true --bt-force-encryption=true
)
if /i "%transferMode%" equ "noisy" (
set torrentclientSyntax=--check-integrity=true --seed-time=%postDownloadSeedTime% --dir="%targetTempFilesLocation%" --bt-seed-unverified=true --bt-external-ip=%current_ip% --enable-dht=true --bt-enable-lpd=true --enable-peer-exchange=true --bt-force-encryption=true
)

::start cmd /k
::could prolly make it display PE info somehow, but would need to be standalone, so...create script dynamically?
::or could write information to a text file and display it, then delete it
start cmd

::start torrent client and wait for download+seeding time
call "%tempWinPEdir%\%torrentClientExe%" %torrentclientSyntax% "%tempWinPEdir%\%torrentfileName%"

::6) wait (download+seeding time)

::) change color as specified (Aria likes to change it too, so change it back)  (cmdcolor)
if defined newcolor color %newcolor%


::Okay so
::if torrent didn't download at all then check if unicast fallback enabled, if so unicast then hashcheck then deploy
::if image not present after torrenting, then try to unicast, no hash check
::if torrented wim didn't pass hashcheck, then delete file, check if unicast enabled, if so unicast, check the hash again and then deploy
::if torrentexe disabled try to unicast then hash check then deploy
::if image not present after unicasting, then something seriously wrong, don't hash check and ask to reformat again
::if first hashcheck fails, try unicast if enabled, if second hashcheck fails, ask to reformat and try again


:findHashPostTorrent
if not exist "%targetTempFilesLocation%\%imagefileName%" goto unicastImage
::okay so if the image exist, but hash checking is disabled, then assume the image is fine and goto deploy
if /i "%findHashStatus%" neq "true" goto deploy
echo    Calculating hash of downloaded file please wait...
set errorlevel=0
if exist "%targetTempFilesLocation%\%imagefileName%" call :hashCheck "%targetTempFilesLocation%\%imagefileName%" > hash.txt
for /f "tokens=1-10" %%a in (hash.txt) do (set calculatedHash=%%a
if exist hash.txt del hash.txt
goto compareHashes1)
:compareHashes1
echo.
echo  comparing: hash:"%hashData%"  %imagefileName%
echo  with       hash:"%calculatedHash%"  %targetTempFilesLocation%\%imagefileName%
if "%calculatedHash%" equ "%hashData%" (
echo   %imagefileName% successfully downloaded without errors
goto deploy
) else (
echo "%calculatedHash%" is NOT equal to 
echo "%hashData%" 
echo   File transfered with errors. Will try unicast fallback if available
del "%targetTempFilesLocation%\%imagefileName%"
goto unicastImage
)


echo  unspecified error


:unicastImage
if /i "%enableUnicastFallbackForImage%" neq "true" (echo    Unicast fallback for image deployment not enabled: "%enableUnicastFallbackForImage%"
goto afterUnicastImage)
set unicastPath=invalid
set unicastPath1=%pePathToImages%\%imagefileName%
set unicastPath2=%pePathToImages%\WinVista\%imagefileName%
set unicastPath3=%pePathToImages%\Win7\%imagefileName%
set unicastPath4=%pePathToImages%\Win8\%imagefileName%
set unicastPath5=%pePathToImages%\Win81\%imagefileName%
set unicastPath6=%pePathToImages%\Win10\%imagefileName%

if exist "%unicastPath1%" set unicastPath=%unicastPath1%
if exist "%unicastPath2%" set unicastPath=%unicastPath2%
if exist "%unicastPath3%" set unicastPath=%unicastPath3%
if exist "%unicastPath4%" set unicastPath=%unicastPath4%
if exist "%unicastPath5%" set unicastPath=%unicastPath5%
if exist "%unicastPath6%" set unicastPath=%unicastPath6%

::if unicastpath not found and torrenting disabled, then completely error out
::if unicast path not found and torrenting enabled, could try to reformat and try torrenting again
if not exist "%unicastPath%"  if /i "%torrentclientexe%" equ "invalid" (echo   error could not find valid unicast source at:
echo   "%pePathToImages%\%imagefileName%"
echo    and Image deployment using torrent client not available:"%torrentclientexe%"
goto end)
if not exist "%unicastPath%" (echo   error could not find valid unicast source at:
echo   "%pePathToImages%\%imagefileName%"
goto restartDeploymentPrompt)
::else assume that the path exist and it's a valid copy from source
echo.
echo   Now attempting to unicast %imagefileName%
echo   copying from %unicastPath%
echo     to: %targetTempFilesLocation%\%imagefileName%
copy /y "%unicastPath%" "%targetTempFilesLocation%\%imagefileName%" 
if exist "%targetTempFilesLocation%\%imagefileName%" goto findHashPostUnicastImage
if not exist "%targetTempFilesLocation%\%imagefileName%" echo   unicastImage failed
if /i "%torrentclientexe%" equ "invalid" goto end
goto restartDeploymentPrompt
:afterUnicastImage


::7) check hash if specified (hashtype validly defined and hashdata not invalid or null) (hashgenexe h -crc)
:findHashPostUnicastImage
::if the image doesn't exist and made it all the way past two attempts to download it and now trying to hash it, then just give up
if not exist "%targetTempFilesLocation%\%imagefileName%" (echo   deployment failed 
goto end)
::okay so if the image exist, but hash checking is disabled, then assume the image is fine and goto deploy
if /i "%findHashStatus%" neq "true" goto deploy
echo    Calculating hash of downloaded file please wait...
set errorlevel=0
if exist "%targetTempFilesLocation%\%imagefileName%" call :hashCheck "%targetTempFilesLocation%\%imagefileName%" > hash.txt
for /f "tokens=1-10" %%a in (hash.txt) do (set calculatedHash=%%a
if exist hash.txt del hash.txt
goto compareHashes2)
:compareHashes2
echo.
echo  comparing: hash:"%hashData%"  %imagefileName%
echo  with       hash:"%calculatedHash%"  %targetTempFilesLocation%\%imagefileName%
if "%calculatedHash%" equ "%hashData%" (
echo   %imagefileName% successfully downloaded without errors
goto deploy
) else (
echo "%calculatedHash%" is NOT equal to 
echo "%hashData%" 
echo   File transfered with errors
)
::okay so the file, somehow transfered, and hashing was enabled, but didn't hashCheck properly
::at this point can ask to reformat or just ignore the error
goto restartDeploymentPrompt


::8) apply file to local disk
:deploy
::if somehow here without an image present, just give up
if not exist "%targetTempFilesLocation%\%imagefileName%" goto end

::get information about the image prior to deploying/deleting it for unattend.xml later
echo   Retrieving information about: %imagefileName%
call :getWimInfo "%targetTempFilesLocation%\%imagefileName%" %imageIndex%

::call image /deploy "%targetTempFilesLocation%\%imagefileName%" "%imageIndex%" /noformat %winDrive%
dism /Apply-Image /imagefile:"%targetTempFilesLocation%\%imagefileName%" /Index:"%imageIndex%" /ApplyDir:"%winDrive%"


::huristic check to make sure image deployed successfully
if not exist "%winDrive%\Windows" echo   Image deployment failed&goto end
if not exist "%winDrive%\Program Files" echo   Image deployment failed&goto end
if not exist "%winDrive%\Users" echo   Image deployment failed&goto end


::9) make sure image is bootable (bcdboot)
set bootFilesDrive=S:
set bcdStoreBIOS=%bootFilesDrive%\boot\bcd
set bcdStoreUEFI=%bootFilesDrive%\EFI\microsoft\boot\bcd
if exist "%bcdStoreBIOS%" (attrib -a -h -s "%bcdStoreBIOS%"
del "%bcdStoreBIOS%")
if exist "%bcdStoreUEFI%" (attrib -a -h -s "%bcdStoreUEFI%"
del "%bcdStoreUEFI%")
::don't copy all boot files since bcdboot is picky about invalid configurations (win7 x86 doesn't have uefi boot files for example)
if /i "%bootmode%" equ "UEFI" (bcdboot %winDrive%\Windows /s %bootFilesDrive% /f UEFI) else (bcdboot %winDrive%\Windows /s %bootFilesDrive% /f BIOS)


::10) update drivers
::A note about how drivers are currently handled: 1) from archive, 2) wmi torrent 3) wmi path, 4) dism /add-driver "blind path" (#4 not implemented, working on 2 and 3 atm)
::The better updated control flow would work something like:
::if archive not exist, install via wmi, if wmi not available, goto blind path, check blind path flag or existence of install from blindly seperate variable (containing a path)
::if archive exist, copy drivers, if copy failed goto wmi
::extract drivers, if extract fails, go to wmi
::add drivers- end
::if wmi not available goto blind path
::if not exist serverlocation\resources\drivers\wmi.torrent goto wmi path
::call aria to handle downloading via wmi torrent
::add-drivers - end
::if wmi path not exist goto blind path
::if exist then add-drivers end
::for blind path, check if path exist
::if path doesnt exist end
::if flag not set end
::install blindly from path via add-drivers then end

if not exist "%targetTempFilesLocation%\drivers" mkdir "%targetTempFilesLocation%\drivers"

::if drivers archive file exist, use that (preferred)
::change this to goto WMI fallback for driver torrents and paths once implemented
if /i "%installDriversFromArchive%" neq "true" goto postInstallingDrivers
set driversArchiveSource=%configFilesLocation%\%driversArchiveName%
set driversArchiveDestination=%targetTempFilesLocation%\%driversArchiveName%
::change this to goto WMI fallback for driver torrents and paths once implemented
if not exist "%driversArchiveSource%" goto postInstallingDrivers

::copy drivers archive to deploy path
copy /y "%driversArchiveSource%" "%driversArchiveDestination%"
if not exist "%driversArchiveDestination%" goto postInstallingDrivers

::7za.exe x "C:\Users\Administrator\desktop\lattitude_drivers_x64.zip" -o"C:\Users\Administrator\desktop\latitude drivers x64\" -y 
::extract to subdirectory
"%sevenz%" x "%driversArchiveDestination%" -o"%targetTempFilesLocation%\drivers\" -y
if %errorlevel% neq 0 (echo error extracting drivers
goto postInstallingDrivers)

::apply drivers using subdirectory
dism /image:%winDrive% /add-driver /driver:"%targetTempFilesLocation%\drivers" /recurse
goto postInstallingDrivers

::try finding path via wmi
:wmic computersystem baseboard get model,name,manufacturer,systemtype /format:list
::but need to install WMI package into PE images first and then detect if the wmi package is installed

::wmi torrents code goes here

::wmi path code goes here

::if neither the manual WMI torrents nor the wmi path work then try
::the unicast path (this is equavalent to a blind apply, very dangerous)
:unicastDrivers
::if exist "%driversFallbackUnicastPath%" (dism /image:%winDrive%\ /add-driver /driver:"%driversFallbackUnicastPath%" /recurse
::goto postInstallingDrivers)
:postInstallingDrivers


::11) copy scripts (unattend.xml/joindomain)
:updateUnattendfile
::check if predefined script exist, if so, force copy  (unattendfileName)
if exist "%tempWinPEdir%\%unattendfileName%" (
echo    copying: "%tempWinPEdir%\%unattendfileName%"
echo    to:      "%winDrive%\Windows\System32\sysprep\unattend.xml"
copy /y "%tempWinPEdir%\%unattendfileName%" "%winDrive%\Windows\System32\sysprep\unattend.xml"
)

::if it doesn't exist, then try to see if an RTM one exists in the local store
if not exist "%tempWinPEdir%\%unattendfileName%" (set callback=midScriptUpdate
goto copyunattendxml)
:midScriptUpdate
::maybe copy a post-setup script to the image, starting it can be specified in the unattend file (SIM)
::such a script could cleanup after deployment (activate windows, join domain, add/delete users, delete the unattend.xml file)


::) if a customPostOobeScript was specified, copy it to the targetTempFilesLocation path  (customPostOobeScript)
if /i "%customPostOobeScript%" neq "invalid" if exist "%customPostOobeScript%" (
echo   copying: "%customPostOobeScript%"
echo   to:         "%targetTempFilesLocation%\%customPostOobeScript%"
copy /y "%customPostOobeScript%" "%targetTempFilesLocation%\%customPostOobeScript%"
)

::) if a customPostImagingScript was specified, call it now (customPostImagingScript)
if /i "%customPostImagingScript%" neq "invalid" if exist "%customPostImagingScript%" (echo    call "%customPostImagingScript%"
call "%customPostImagingScript%")


if /i "%deleteDriverArchiveAfterApplying%" equ "true" (
if exist "%targetTempFilesLocation%\drivers" rmdir /s /q "%targetTempFilesLocation%\drivers"
if exist "%targetTempFilesLocation%\%driversArchiveName%" del "%targetTempFilesLocation%\%driversArchiveName%"
)


::12) remove image if if specified to do so and if applied successfully, again with the heuristic check to see if image applied successfully, could use DISM for a better account, maybe
if /i "%deleteImageFileAfterDeploymentCompletes%" equ "true" (
if exist "%winDrive%\Windows" if exist "%winDrive%\Users" if exist "%winDrive%\Program Files" if exist "%targetTempFilesLocation%\%imagefileName%" del "%targetTempFilesLocation%\%imagefileName%"
)


goto end


::::start Function List::::
::) if currently running from server, copy deployclient.bat and deployclient.ini locally (embedding the server path) and run again locally
::todo: instead of blindly copying once, could also compare the source and destination paths, if the same, then already running locally, so instead: don't copy, let default (local config) and any local .ini take over 
:copyLocally
::if already running locally, then copying from itself to itself, might not be a good idea, 
::so generate a new unique name at execution time
set randomNumber=%random%
set deployClientName=%~n0-%randomNumber%-%~x0
set deployClientConfigName=%~n0-%randomNumber%-.ini
set configFilesLocation=%~dp0
if /i "%configFilesLocation:~-1%" equ "\" set configFilesLocation=%configFilesLocation:~,-1%

copy /y "%configFilesLocation%\%~n0.ini" "%deployClientConfigName%"
echo set configFilesLocation=%configFilesLocation%>%deployClientName%
echo set copiedOnce=true>>%deployClientName%
echo. >>%deployClientName%
type "%~0" >>%deployClientName%
::transfer control over to the new script
%deployClientName%


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


::verifyExtension "%customPostOobeScript%" customPostOobeScript {exec or wim or xml}
:verifyExtension
set rawinput=%~1
set rawextension=%~x1
if /i "%~3" equ "wim" goto checkWimExtension
if /i "%~3" equ "xml" goto checkxmlExtension
if /i "%~3" equ "archive" goto checkarchiveExtension
if /i "%~3" equ "torrent" goto checktorrentExtension
if /i "%rawextension%" neq ".bat" if /i "%rawextension%" neq ".cmd" if /i "%rawextension%" neq ".vbs" if /i "%rawextension%" neq ".exe" (
echo    error %rawinput% does not have a valid extension for execution: "%rawextension%"
set %~2=invalid)
goto :eof
:checkWimExtension
if /i "%rawextension%" neq ".wim" if /i "%rawextension%" neq ".esd" if /i "%rawextension%" neq ".swm" (
echo    error %rawinput% does not have a valid image file execution: "%rawextension%"
set %~2=invalid)
goto :eof
:checkxmlExtension
if /i "%rawextension%" neq ".xml" (echo    error %rawinput% extension is invalid for xml files: "%rawextension%"
set %~2=invalid)
goto :eof
:checkarchiveExtension
if /i "%rawextension%" neq ".7z" if /i "%rawextension%" neq ".zip" if /i "%rawextension%" neq ".rar" if /i "%rawextension%" neq ".cab" if /i "%rawextension%" neq ".exe" (
echo    error %rawinput% extension is invalid for achives: "%rawextension%"
set %~2=invalid)
goto :eof
:checktorrentExtension
if /i "%rawextension%" neq ".torrent" (
echo    error %rawinput% extension is invalid for torrent: "%rawextension%"
set %~2=invalid)
goto :eof


::TODO:check to make sure current boot mode matches reccomended hard disk partition mode, if it doesn't, start over
::resumeInterupted takes a drive as an argument
:resumeInterupted
set winDrive=%~1

::function called in error, just reformat and start again
if not exist "%winDrive%\%targetTempFilesLocation%\%imagefileName%" goto formatHD
set restartedFlag=true

::reduce seeding time arbitarily (to maybe help client catch up to swarm)
set postDownloadSeedTime=1

::if in UEFI mode, mount system partition as S, else
::assume minimal format MBR mode and mount the windows
if /i "%bootMode%" equ "UEFI" (mountvol S: /s) else (subst S: %winDrive%\)
::This won't work well for normally formatted disks with multiple partitions
::would need to detect that extra partition somehow and assign it as "R" so that recovery tools could 
::one day maybe be copied into it, or if registerRE was invoked manually after imaging
::maybe set restartAutomatically to off and post a message about "this is a restarted client?"
::for now, just mount R: so any retools added later go into the OS partition, not architecturally pretty, but works
subst R: %winDrive%\

echo. &echo   Cleaning up hard disk before applying image...
chkdsk %winDrive% /f
::cleanup any old directories in case there was a deployment previously that was interupted
echo. &echo   Still cleaning hard disk please wait...
echo   rmdir /q /s "%winDrive%\Windows"
if exist "%winDrive%\Windows"  rmdir /q /s "%winDrive%\Windows"
echo   rmdir /q /s "%winDrive%\Users"
if exist "%winDrive%\Users"  rmdir /q /s "%winDrive%\Users"
echo   rmdir /q /s "%winDrive%\Program Files"
if exist "%winDrive%\Program Files" rmdir /q /s "%winDrive%\Program Files"
echo   rmdir /q /s "%winDrive%\Program Files (x86)"
if exist "%winDrive%\Program Files (x86)" rmdir /q /s "%winDrive%\Program Files (x86)"
echo.
goto :eof


:copyunattendxml
set wimWinDir=invalid
if exist w:\windows set wimWinDir=w:\windows
if exist D:\Windows  set wimWinDir=D:\windows
if exist C:\Windows  set wimWinDir=C:\windows
if exist B:\Windows  set wimWinDir=B:\windows
if not exist "%wimWinDir%" goto %callback%

echo.
echo    Will now attempt to copy unattend.xml to automate oobe
echo.
set unattendStatus=invalid
set unattendSysprepFullPath=%winDrive%\system32\sysprep\unattend.xml
::set unattendPantherFullPath=%winDrive%\Panther\unattend.xml

if exist ".\scripts\unattendxml\win%wimOSVersion%\unattend_Win%wimOSVersion%_%wimEdition%_%wimArchitecture%_RTM.xml" (
set unattendOobeFile=.\scripts\unattendxml\win%wimOSVersion%\unattend_Win%wimOSVersion%_%wimEdition%_%wimArchitecture%_RTM.xml
set unattendStatus=valid)
::make sure not to copy over any existing unattend.xml file from advanced images
if /i "%unattendStatus%" equ "valid" (
if not exist "%unattendSysprepFullPath%" copy "%unattendOobefile%" "%unattendSysprepFullPath%" & echo   copying:"%unattendOobefile%" & echo   to:"%unattendSysprepFullPath%"
)
if /i "%unattendStatus%" neq "valid" (echo  Could not find win%wimOSVersion%\unattend_Win%wimOSVersion%_%wimEdition%_%wimArchitecture%_RTM.xml)
goto %callback%


::if creating a hash or archiving drivers, need to find 7zip somewhere and set it to sevenz variable name
::if not found, then disable both hashing and archiving drivers
::skip if not finding hash and not archiving drivers
:findsevenz
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

if not exist "%sevenz%" set sevenz=invalid
goto :eof


::getWimInfo expects a wimfile and index
::call :getWimInfo d:\mywimfile.wim 4
:getWimInfo
if not exist "%~1" (echo        error please specify a valid image file. The following file does not exist:
echo         "%~1"
goto end)
set dismInfoSyntax=/get-wiminfo /wimfile:"%~1" /index:"%~2"
dism %dismInfoSyntax% > tempWimInfo.txt
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


::get details about PE
:winPEInfo

::determine (boot mode UEFI, BIOS or Unknown), winPEArchitecture (x86 or x64), PE version (2,3,4,5,10)
diskpart /s nonexist.txt > temp.txt
for /f "tokens=4" %%i in ('find /n "version" temp.txt') do set rawPEversion=%%i
for /f "tokens=1,2 delims=." %%i in ("%rawPEversion%") do set rawPEversion=%%i.%%j
if exist temp.txt del temp.txt

set winPEVersion=%rawPEversion%
if /i "%rawPEversion%" equ "6.0" (set winPEVersion=2.0
set bootDetectMode=legacy
set winPEInternalVersion=2
set winPEOSVersion=Vista)
if /i "%rawPEversion%" equ "6.1" (set winPEVersion=3.x
set bootDetectMode=legacy
set winPEInternalVersion=31
set winPEOSVersion=7)
if /i "%rawPEversion%" equ "6.2" (set winPEVersion=4.0
set bootDetectMode=modern
set winPEInternalVersion=4
set winPEOSVersion=8)
if /i "%rawPEversion%" equ "6.3" (set winPEVersion=5.x
set bootDetectMode=modern
set winPEInternalVersion=51
set winPEOSVersion=81)
if /i "%rawPEversion%" equ "10.0" (set winPEVersion=10.0
set bootDetectMode=modern
set winPEInternalVersion=10
set winPEOSVersion=10)
if /i "%bootDetectMode%" equ "modern" goto modernDetect

::legacy detect is unreliable (better than nothing tho)
:legacyDetect
set bootMode=Unknown

bcdedit > temp2.txt
for /f "tokens=2 skip=2" %%a in ('find /n "path" temp2.txt') do set extension=%%~xa
if /i "%extension%" equ ".exe" set bootMode=BIOS
if /i "%extension%" equ ".efi" set bootMode=UEFI
if exist temp2.txt del temp2.txt
goto display

:modernDetect
wpeutil UpdateBootInfo 1>nul 2>nul
for /f "tokens=2* delims=	 " %%A in ('reg query HKLM\System\CurrentControlSet\Control /v PEFirmwareType') do set Firmware=%%B 1>nul 2>nul
if %Firmware%==0x1 set bootMode=BIOS
if %Firmware%==0x2 set bootMode=UEFI

:display
::find local IP(s), current code fragile, will not work well with multiple NICs or IPs
set current_ip=invalid
ipconfig > ipinfo.txt
if exist ipaddress.txt del ipaddress.txt
for /f "tokens=1-20" %%a in ('find "IPv4 Address" ipinfo.txt') do if "%%n" neq "" echo %%n>> ipaddress.txt
if exist ipinfo.txt del ipinfo.txt
for /f %%i in (ipaddress.txt) do (set current_ip=%%i)
if exist ipaddress.txt del ipaddress.txt

if /i "%processor_architecture%" equ "AMD64" (set winPEArchitecture=x64)
if /i "%processor_architecture%" equ "x86" (set winPEArchitecture=x86)
if /i "%winPEArchitecture%" neq "x64" if /i "%winPEArchitecture%" neq "x86" (echo    error determing winPEArchitecture:"%winPEArchitecture%" from "%processor_architecture%"
set winPEArchitecture=invalid)

::echo   Current WinPE Boot Info:  %winPEVersion%  %winPEArchitecture%  %bootMode%  %current_ip%
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

for /f "skip=2 tokens=1-10" %%a in ('find /i "for data" %tempfile%') do echo %%d "%~1"
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


:restartDeploymentPrompt
set callback=formatHD
echo    Image deployment failed, Will try to reformat the drive and try the download again
::reset c:\recovery\oem back to recovery\oem so a new drive letter can be added to it again after formatting
set targetTempFilesLocation=%original_targetTempFilesLocation%
goto booleanprompt


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


::13) reboot (if specified) (restartAutomatically)
:end

echo   %~n0 shutting down
if /i "%restartAutomatically%" equ "true" exit
popd
endlocal
