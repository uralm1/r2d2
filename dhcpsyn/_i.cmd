@rem echo off
@setlocal
@set ver=2.57
@set ver_ljq=1.0
@set inst_dir=c:\Utils\Dhcpsyn

rmdir /s /q dhcpsyn-%ver%
rmdir /s /q ljq-%ver_ljq%
@if not exist dhcpsyn-%ver%.tar.gz (
  @echo FATAL: dhcpsyn-%ver%.tar.gz file is required!
  exit /b 1
)
@if not exist ljq-%ver_ljq%.tar.gz (
  @echo FATAL: ljq-%ver_ljq%.tar.gz file is required!
  exit /b 1
)
cmd /C "ptar -x -v -f dhcpsyn-%ver%.tar.gz"
cmd /C "ptar -x -v -f ljq-%ver_ljq%.tar.gz"

cd dhcpsyn-%ver%
perl Makefile.PL
gmake
gmake install
copy /y dhcpsyn.conf_empty %inst_dir%
cd ..
rmdir /s /q dhcpsyn-%ver%

cd ljq-%ver_ljq%
perl Makefile.PL PREFIX=%inst_dir% INSTALLPRIVLIB=%inst_dir%/lib INSTALLSITELIB=%inst_dir%/lib
gmake
gmake install
cd ..
rmdir /s /q ljq-%ver_ljq%

rmdir /q %inst_dir%\log

@echo.
@echo Dhcpsyn is installed to %inst_dir%
@echo.
@echo off

@endlocal
