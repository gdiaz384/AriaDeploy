# AriaDeploy

AriaDeploy is an Automated Scalable Windows Deployment Tool

AriaDeploy transfers previously captured .wim images (captured via dism/mdt/imagex/gimagex/sccm) over the network using Aria, a bittorrent client, and automates common deployment tasks such as the installation of drivers.

Currently AriaDeploy supports all Windows 7-10 x86/x64 images (both RTM and custom) for deployment on BIOS/UEFI systems.

The development emphasis is on zero-configuration "just works" software with minimal end-user dependencies.

## Screenshot:

![screenshot1](redist/AriaDeploy/docs/AriaDeployPic.png)

![screenshot1](redist/AriaDeploy/docs/AriaSystemLifecycle.png)

## Key Features:

1. Supports extremely simple deployments
2. Supports fully authomated management of drivers/OOBE/hard drive partitioning/booting aspects of deployment "out of the box"
3. Supports complicated scenarios via config.ini files and extensibility points
4. Reduces dependencies on fragile and configuration intensive multicasting by switching to P2P technology
5. Minimal external dependencies and configuration required (ADK still required)
6. Transparent design built using Free Open Source Software whenever possible and industry standard tools (ADK)

## Planned Features include:

1. "Installation" script to prebuild Windows PE .wims/isos and transfer the relevant files
2. Support for deployment on heterogenous hardware systems (via adding WMI packages to WinPE)
3. "Deployment-on-a-stick" scenarios
4. Automated deployment image and tools integration into recovery partitions (this is useful to OEMs)
5. AriaDeploy for OS/X (will be a while)

## AriaDeploy is/will

1. deploy images in the standard windows imaging and electronic software delivery formats (wim/esd)
2. reformat the main disk on the target systems as specified (normal or minimalistic)
3. automate the installation of drivers
4. make the target systems bootable using the PE boot mode information
5. automate oobe
6. an implementation of the best technology to use when transfering large files over unreliable networks
7. designed to integrate into existing MDT and SCCM workflows, including those involving Active Directory

## AriaDeploy is not/will not

1. capture images or deploy virtual disks (.vhd/vmx files)
2. will NOT preserve user data on target systems
3. download the correct drivers for you
4. determine that windows version X cannot boot as configured on target system Y due to incompatability Z
5. input the correct product key for you in the unattend.xml templates or autogenerate unattend.xml files (use MDT for that instead)
6. a full deployment solution
7. dependent upon WDS/MDT/SCCM/AD

## Typical Usage Guide:

![screenshot1](redist/AriaDeploy/docs/AriaDeployWorkflow.png)

1. (optional) Download drivers for your hardware model(s) from [Dell](http://en.community.dell.com/techcenter/enterprise-client/w/wiki/2065.dell-command-deploy-driver-packs-for-enterprise-client-os-deployment), [Lenovo](https://support.lenovo.com/us/en/documents/ht074984) and [HP](http://www8.hp.com/us/en/ads/clientmanagement/drivers-pack.html) 
2. (optional) Extrac	t to some folder like D:\Drivers\Dell\Optiplex9010\Win7\x64
3. Double click on AriaDeploy.exe
4. Select your .wim image created using DISM/MDT
5. (optional) Select the drivers folder from step 2 (D:\Drivers\Dell\Optiplex9010\Win7\x64)
6. (optional) Select the type of unattend.xml file to use, an RTM one or a custom one
7. Click on "Start"
8. Boot target systems using Windows PE (any version using any boot method: usb drives/cds/PXE) 
9. Map network drive from within Windows PE (or write a script to do this automatically)
10. Start Y:\client\AriaDeployClient.bat (or write a script to do this automatically)

## Download:

Click [here](https://github.com/gdiaz384/AriaDeploy/releases) or on "releases" at the top to download the latest version.

## Install guide:

I have bundled most of the dependencies into the installer, but due to the ADK's non-redistributable clause, I cannot provide prebuilt WinPE images (part of the ADK) for use with AriaDeploy. For similar reasons, I also cannot provide full unattend.xml files, only templates for them.

1. So go download and install the [ADK for Windows 10](https://msdn.microsoft.com/en-us/windows/hardware/dn913721.aspx) and/or [Windows 8.1U](https://www.microsoft.com/en-US/download/details.aspx?id=39982). Having both is prefered but just one works. [Win7's AIK] (https://www.microsoft.com/en-us/download/details.aspx?id=5753) and [supplement](https://www.microsoft.com/en-us/download/details.aspx?id=5188) also works.
2. (optional) While waiting for the ADKs to download/install (takes a while), go download drivers for WinPE from  [Dell](http://en.community.dell.com/techcenter/enterprise-client/w/wiki/2065.dell-command-deploy-driver-packs-for-enterprise-client-os-deployment), [Lenovo](https://support.lenovo.com/us/en/documents/ht074984) and [HP](http://www8.hp.com/us/en/ads/clientmanagement/drivers-pack.html) 
3. (optional) extract the PE drivers to the appropriate folders: AriaDeploy\drivers\WinPE\5_x\x64 or 10_x86
4. After the ADK finishes installing, double click on InstallAriaDeploy.bat
5. (optional) Also get the [generic RTM unattend.xml files](https://github.com/gdiaz384/AriaDeploy/releases) and here for the [MS license keys to use when deploying systems](https://technet.microsoft.com/en-us/library/jj612867.aspx)
6. (optional) Input the MS keys into the unattend.RTM.xml files

## Internal Dependency List:

1. Requires ADK tools (dism, windowsPE, ocdimg, bcdboot) -[ADK for Windows 8.1](https://www.microsoft.com/en-US/download/details.aspx?id=39982) or [above](https://msdn.microsoft.com/en-us/windows/hardware/dn913721.aspx) preferred
2. ESD deployment is supported when using DISM versions for Windows 8.1 and above on x64 PE images
3. Aria2 available over at sourceforge [1.19.0](http://aria2.sourceforge.net/) 
4. 7zip available here [15.0.9b](http://www.7-zip.org)
5. py3createtorrent [0.9.5](https://py3createtorrent.readthedocs.org/en/latest/user.html)
6. py3bt_tracker [1.0.0-rc.1](https://github.com/gdiaz384/py3bt_tracker)
7. #5 and #6 and have internal dependencies: TDM-GCC over MingGW, tornado, bencode, pyinstaller, python etc
8. Architectural diagram illustrating these dependencies can be found at redist\AriaDeploy\AriaDeployControlFlow.png

## Version History/Planning

Note: Anything prior to version 1.0 is alpha/beta quality depending upon release and current focus of development is on architectural imrovements and features not stability/bug fixes.

```
Latest Release: v0.3.1a
In Development: v0.4.0a

::0.5.0 added partial mac support (no drivers)(?) winpe/dism not licensed for use on non-windows systems, 
::gparted can HFS+, rEFInd can boot, live distros are common, just need to find one that can access NFS/CIFS shares easily
::might need to convert batch script to .sh so maybe AriaDeployForMac
0.4.3 added optional 7z deployment scenario
0.4.2 formalized "deployment on a stick" and installer scenarios by precompiling and bunding software into "WinPE5_x64_AriaDeploy.iso" files
0.4.1 added heterogenous hardware support using WMI, (requires WMI components in PE images however), streamlined installation files
0.4.0 added support for "deployment on a stick" scenarios (by replacing qTorrent with py3bt_tracker), made server architecture agnostic, bug fixed AriaDeploy.exe
0.3.1 refractored code, improved overall reliability, created "installer", switched to FOSS qTorrent over uTorrent for server aspect, and reduced requirements
0.3 refractored code, addedUI, improved client side reliability, changed name to "AiraDeploy"
0.2 refractored code, added server component, improved scalability (architecture agnostic using Aria instead of uTorrent3.3)
0.1 "massDeploy" concept art using uTorrent 3.3/psutils, client side only
```

## License:
Pick your License: GPL (any) or BSD (any) or MIT/Apache

If I get any questions, I'm changing this to "beerware" and will refuse to elaborate further. You've been warned.
