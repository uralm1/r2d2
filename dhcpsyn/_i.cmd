@rem echo off
@setlocal
@set ver=2.52
@set inst_dir=c:\utils\dhcpsyn

rmdir /s /q dhcpsyn-%ver%
cmd /C "ptar -x -v -f dhcpsyn-%ver%.tar.gz"

cd dhcpsyn-%ver%
perl Makefile.PL
gmake
gmake install
copy /y dhcpsyn.conf_empty %inst_dir%
cd ..
rmdir /s /q dhcpsyn-%ver%

@echo.
@echo Dhcpsyn is installed to %inst_dir%
@echo.
@echo off

@endlocal
