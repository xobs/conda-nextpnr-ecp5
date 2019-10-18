set NEXTPNR_COMMIT=0db8995e8143fd93930586f1126a833e64649008
set NEXTPNR_URI=https://github.com/xobs/nextpnr.git
set VCPKG_COMMIT=8900146533f8e38266ef89766a2bbacffcb67836
set PRJTRELLIS_COMMIT=089efdc763601da40533b902f51d34686e9361d7
set PRJTRELLIS_URI=https://github.com/xobs/prjtrellis.git
set PATH=C:\tools\vcpkg;%PATH%
REM set APPVEYOR_BUILD_FOLDER=C:\Users\smc\Code\Conda\nextpnr-ecp5
REM conda remove --name nextpnr-ecp5-build --all
REM conda env remove --name nextpnr-ecp5-build
cd %SRC_DIR%
cd
dir
powershell .\bld.ps1 install
if errorlevel 1 exit 1