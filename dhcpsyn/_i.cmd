@rem echo off
@setlocal
@set ver=2.54
@set inst_dir=c:\Utils\Dhcpsyn

rmdir /s /q dhcpsyn-%ver%
@if not exist dhcpsyn-%ver%.tar.gz (
  @echo FATAL: dhcpsyn-%ver%.tar.gz file is required!
  exit /b 1
)
cmd /C "ptar -x -v -f dhcpsyn-%ver%.tar.gz"

cd dhcpsyn-%ver%
perl Makefile.PL
gmake
gmake install
copy /y dhcpsyn.conf_empty %inst_dir%
cd ..
rmdir /s /q dhcpsyn-%ver%
rmdir /q %inst_dir%\log

@echo.
@echo Dhcpsyn is installed to %inst_dir%
@echo.
@echo off

@endlocal
