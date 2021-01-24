@rem echo off
@setlocal

set sitelib=c:\Strawberry\perl\site\lib

@rem cpanm working directory is %USERPROFILE%\.cpanm
@rem Don't use EV on WINDOWS!
cpanm -v Mojolicious
cpanm -v Mojo::Server::Threaded
cpanm -v Mojo::SQLite
cpanm -v Minion
cpanm -v Minion::Backend::SQLite

@rem we have to enable pseudofork for minion worker
attrib -R %sitelib%\Minion.pm
@rem copy Minion.patch into install dir, file must be in dos format, otherwise patch.exe die!
patch -u -b %sitelib%\Minion.pm Minion.patch

@endlocal
