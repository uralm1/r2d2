@rem echo off
@setlocal

@set inst_dir=c:\Utils\Dhcpsyn
@set perl_dir=c:\Strawberry

@rem run this with elevated privileges!

@rem copy nssm.exe to c:\utils\Dhcpsyn directory
@if not exist %inst_dir%\nssm.exe (
  @echo FATAL: nssm.exe is required!
  exit /b 1
)

nssm install Dhcpsyn %perl_dir%\perl\bin\perl.exe
nssm set Dhcpsyn AppDirectory %inst_dir%
nssm set Dhcpsyn AppParameters script\dhcpsyn threaded
nssm set Dhcpsyn DisplayName Dhcpsyn
nssm set Dhcpsyn Description R2D2 Dhcpsyn service
nssm set Dhcpsyn Start SERVICE_AUTO_START
nssm set Dhcpsyn DependOnService DhcpsynWorker
nssm set Dhcpsyn ObjectName LocalSystem
nssm set Dhcpsyn Type SERVICE_WIN32_OWN_PROCESS
nssm set Dhcpsyn AppStdout %inst_dir%\Dhcpsyn.log
nssm set Dhcpsyn AppStderr %inst_dir%\Dhcpsyn.log

nssm install DhcpsynWorker %perl_dir%\perl\bin\perl.exe
nssm set DhcpsynWorker AppDirectory %inst_dir%
nssm set DhcpsynWorker AppParameters script\dhcpsyn minion worker -j 1
nssm set DhcpsynWorker DisplayName Dhcpsyn Worker
nssm set DhcpsynWorker Description R2D2 Dhcpsyn Worker service
nssm set DhcpsynWorker Start SERVICE_AUTO_START
nssm set DhcpsynWorker ObjectName LocalSystem
nssm set DhcpsynWorker Type SERVICE_WIN32_OWN_PROCESS
nssm set DhcpsynWorker AppStdout %inst_dir%\DhcpsynWorker.log
nssm set DhcpsynWorker AppStderr %inst_dir%\DhcpsynWorker.log


@endlocal
