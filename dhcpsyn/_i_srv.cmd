@rem echo off
@setlocal

@rem run this with elevated privileges!

@rem copy nssm.exe to c:\utils\Dhcpsyn directory

nssm install Dhcpsyn c:\Strawberry\perl\bin\perl.exe
nssm set Dhcpsyn AppDirectory c:\Utils\Dhcpsyn
nssm set Dhcpsyn AppParameters script\dhcpsyn threaded
nssm set Dhcpsyn DisplayName Dhcpsyn
nssm set Dhcpsyn Description R2D2 Dhcpsyn service
nssm set Dhcpsyn Start SERVICE_AUTO_START
nssm set Dhcpsyn DependOnService DhcpsynWorker
nssm set Dhcpsyn ObjectName LocalSystem
nssm set Dhcpsyn Type SERVICE_WIN32_OWN_PROCESS
nssm set Dhcpsyn AppStdout c:\Utils\Dhcpsyn\Dhcpsyn.log
nssm set Dhcpsyn AppStderr c:\Utils\Dhcpsyn\Dhcpsyn.log

nssm install DhcpsynWorker c:\Strawberry\perl\bin\perl.exe
nssm set DhcpsynWorker AppDirectory c:\Utils\Dhcpsyn
nssm set DhcpsynWorker AppParameters script\dhcpsyn minion worker -j 1
nssm set DhcpsynWorker DisplayName Dhcpsyn Worker
nssm set DhcpsynWorker Description R2D2 Dhcpsyn Worker service
nssm set DhcpsynWorker Start SERVICE_AUTO_START
nssm set DhcpsynWorker ObjectName LocalSystem
nssm set DhcpsynWorker Type SERVICE_WIN32_OWN_PROCESS
nssm set DhcpsynWorker AppStdout c:\Utils\Dhcpsyn\DhcpsynWorker.log
nssm set DhcpsynWorker AppStderr c:\Utils\Dhcpsyn\DhcpsynWorker.log


@endlocal
