Set-StrictMode -Version 1.0
Set-PSDebug -Trace 1
$ErrorActionPreference = "stop"

# This function is a poor-man's reimplementation of "gunzip"
Function DeGZip-File{
    Param(
        $infile,
        $outfile = ($infile -replace '\.gz$','')
        )
    Set-PSDebug -Off
    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
    $buffer = New-Object byte[](1024)
    while($true){
        $read = $gzipstream.Read($buffer, 0, 1024)
        if ($read -le 0){break}
        $output.Write($buffer, 0, $read)
        }
    $gzipStream.Close()
    $output.Close()
    $input.Close()
    Set-PSDebug -Trace 1
}

# . C:\Users\smc\Miniconda3\shell\condabin\conda-hook.ps1

# Allow us to access System.IO.Compression.GzipStream
Add-Type -AssemblyName System.IO.Compression.FileSystem

# $stage_temp = [System.Guid]::NewGuid().ToString()
# Set-Location $ENV:Temp
# New-Item -Type Directory -Name $stage_temp
# $stage = "$($ENV:Temp)\$($stage_temp)"
# $stage = "C:\Users\smc\AppData\Local\Temp\089ecb48-75ff-42b3-94e6-c707f76566d3"
$stage = "$($Env:PREFIX)"

# Set up vcpkg and ensure modules are installed
Set-Location C:\tools\vcpkg
git rev-parse HEAD
if ($LastExitCode -ne 0) { exit $LastExitCode }
git checkout $env:VCPKG_COMMIT
if ($LastExitCode -ne 0) { exit $LastExitCode }
.\bootstrap-vcpkg.bat
if ($LastExitCode -ne 0) { exit $LastExitCode }
vcpkg integrate install
if ($LastExitCode -ne 0) { exit $LastExitCode }
vcpkg install boost-filesystem:x64-windows-static boost-program-options:x64-windows-static boost-thread:x64-windows-static boost-python:x64-windows-static eigen3:x64-windows-static boost-dll:x64-windows-static
if ($LastExitCode -ne 0) { exit $LastExitCode }

# # Create conda Python environment
# conda create -y -n nextpnr-ecp5-build python=3.7.3
# if ($LastExitCode -ne 0) { exit $LastExitCode }
# conda activate nextpnr-ecp5-build
# if ($LastExitCode -ne 0) { exit $LastExitCode }
python -V
if ($LastExitCode -ne 0) { exit $LastExitCode }
python -c 'import sys; print(sys.path)'
if ($LastExitCode -ne 0) { exit $LastExitCode }

# Extract the chipdb files to the source file directory.
# These files contain lots of redundant information, so we must compress them to fit them
# in the git repositry.
Set-Location $env:SRC_DIR\chipdb
DeGZip-File "$($env:SRC_DIR)\chipdb\chipdb-25k.bba.gz" "$($env:SRC_DIR)\chipdb\chipdb-25k.bba"
DeGZip-File "$($env:SRC_DIR)\chipdb\chipdb-45k.bba.gz" "$($env:SRC_DIR)\chipdb\chipdb-45k.bba"
DeGZip-File "$($env:SRC_DIR)\chipdb\chipdb-85k.bba.gz" "$($env:SRC_DIR)\chipdb\chipdb-85k.bba"

# Check out (and build) prjtrellis
Write-Output ""
Set-Location $env:SRC_DIR
if (!(Test-Path "prjtrellis")) {
    git clone $env:PRJTRELLIS_URI prjtrellis
    if ($LastExitCode -ne 0) { exit $LastExitCode }
}
git -C prjtrellis checkout $env:PRJTRELLIS_COMMIT
if ($LastExitCode -ne 0) { exit $LastExitCode }
git -C prjtrellis submodule init
if ($LastExitCode -ne 0) { exit $LastExitCode }
git -C prjtrellis submodule update
if ($LastExitCode -ne 0) { exit $LastExitCode }
git -C prjtrellis log -1
if ($LastExitCode -ne 0) { exit $LastExitCode }

# Configure and build libtrellis, which includes the various bitstream manipulation
# programs such as ecpmulti and ecppack.
Set-Location $env:SRC_DIR\prjtrellis\libtrellis
cmake -DCMAKE_TOOLCHAIN_FILE=c:/tools/vcpkg/scripts/buildsystems/vcpkg.cmake -DVCPKG_TARGET_TRIPLET=x64-windows-static -G "Visual Studio 16 2019" -A "x64" -DBUILD_SHARED=OFF -DSTATIC_BUILD=ON "-DCMAKE_INSTALL_PREFIX=$stage" .
if ($LastExitCode -ne 0) { exit $LastExitCode }
cmake --build . --target install --config Release
if ($LastExitCode -ne 0) { exit $LastExitCode }

Write-Output ""
Set-Location $env:SRC_DIR
if (!(Test-Path "nextpnr")) {
    git clone $env:NEXTPNR_URI nextpnr
    if ($LastExitCode -ne 0) { exit $LastExitCode }
}
git -C nextpnr checkout $env:NEXTPNR_COMMIT
if ($LastExitCode -ne 0) { exit $LastExitCode }
git -C nextpnr log -1
if ($LastExitCode -ne 0) { exit $LastExitCode }

# cmake requires we use forward slashes, so patch up various environment variables
# to use forward slashes.
Set-Location $env:SRC_DIR\nextpnr
$prjtrellis = "$($env:SRC_DIR.replace("\", "/"))/prjtrellis"
$libtrellis = "$($env:SRC_DIR.replace("\", "/"))/prjtrellis/libtrellis/release"
$chipdb = "$($env:SRC_DIR.replace("\", "/"))/chipdb"
cmake -DCMAKE_TOOLCHAIN_FILE=c:/tools/vcpkg/scripts/buildsystems/vcpkg.cmake -DARCH=ecp5 "-DTRELLIS_ROOT=$prjtrellis" "-DPYTRELLIS_LIBDIR=$libtrellis" "-DPREGENERATED_BBA_PATH=$chipdb" "-DCMAKE_INSTALL_PREFIX=$stage" -DVCPKG_TARGET_TRIPLET=x64-windows-static -G "Visual Studio 16 2019" -A "x64" -DSTATIC_BUILD=ON -DBUILD_GUI=OFF .
if ($LastExitCode -ne 0) { exit $LastExitCode }
cmake --build . --target install --config Release
if ($LastExitCode -ne 0) { exit $LastExitCode }

# # Now that everything is built and installed, package it up.
# Set-Location $stage
# $zip = "$ENV:Temp\nextpnr-ecp5-windows_amd64-$($ENV:APPVEYOR_REPO_TAG_NAME).zip"
# [System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip)

# # Publish the resulting zipfile.
# Push-AppveyorArtifact "$zip"
# Set-Location $env:SRC_DIR
# Remove-Item -Recurse -Force $stage
# Remove-Item -Recurse -Force $zip
# conda env remove --name nextpnr-ecp5-build
