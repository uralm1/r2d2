@rem echo off
@setlocal

set sitelib=c:\Strawberry\perl\site\lib

@rem cpanm working directory is %USERPROFILE%\.cpanm
@rem Don't use EV on WINDOWS!
cmd /C "cpanm -v Mojolicious"
@rem cmd /C "cpanm -v Mojo::Server::Threaded"
cmd /C "cpanm -v NetAddr::IP::Lite"
cmd /C "cpanm -v NetAddr::MAC"

@endlocal
