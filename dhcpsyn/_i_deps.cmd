@rem echo off
@setlocal

set sitelib=c:\Strawberry\perl\site\lib

@rem cpanm working directory is %USERPROFILE%\.cpanm
@rem Don't use EV on WINDOWS!
cmd /C "cpanm -v Mojolicious"
cmd /C "cpanm -v Mojo::Server::Threaded"
cmd /C "cpanm -v Mojo::SQLite"
cmd /C "cpanm -v Minion"
cmd /C "cpanm -v Minion::Backend::SQLite"
cmd /C "cpanm -v NetAddr::IP::Lite"
cmd /C "cpanm -v NetAddr::MAC"

@rem we have to enable pseudofork for minion worker
attrib -R %sitelib%\Minion.pm
attrib -R %sitelib%\Minion\Job.pm
@rem copy Minion.patch, Minion-Job.patch into install dir, file must be in dos cr-lf format,
@rem otherwise patch.exe will die!
@if not exist Minion.patch (
  @echo FATAL: Minion.patch file is required!
  exit /b 1
)
@if not exist Minion-Job.patch (
  @echo FATAL: Minion-Job.patch file is required!
  exit /b 1
)

patch -u -b %sitelib%\Minion.pm Minion.patch
patch -u -b %sitelib%\Minion\Job.pm Minion-Job.patch

@endlocal
