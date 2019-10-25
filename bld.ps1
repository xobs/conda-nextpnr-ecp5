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

$stage = "$($Env:PREFIX)"

# $vcpkg_path = "D:\code\vcpkg"
# # $vcpkg_path = "C:\tools\vcpkg"
# # Set up vcpkg and ensure modules are installed
# Set-Location $vcpkg_path
# git rev-parse HEAD
# if ($LastExitCode -ne 0) { exit $LastExitCode }
# git checkout $env:VCPKG_COMMIT
# if ($LastExitCode -ne 0) { exit $LastExitCode }
# .\bootstrap-vcpkg.bat
# if ($LastExitCode -ne 0) { exit $LastExitCode }
# vcpkg integrate install
# if ($LastExitCode -ne 0) { exit $LastExitCode }
# vcpkg install boost-filesystem:x64-windows-static boost-program-options:x64-windows-static boost-thread:x64-windows-static boost-python:x64-windows-static eigen3:x64-windows-static boost-dll:x64-windows-static
# if ($LastExitCode -ne 0) { exit $LastExitCode }

# Validate conda Python environment
python -V
if ($LastExitCode -ne 0) { exit $LastExitCode }
python -c 'import sys; print(sys.path)'
if ($LastExitCode -ne 0) { exit $LastExitCode }

# Extract the chipdb files to the source file directory.
# These files contain lots of redundant information, so we must compress them to fit them
# in the git repositry.
mkdir $env:SRC_DIR\chipdb-extract
DeGZip-File "$($env:RECIPE_DIR)\chipdb\chipdb-25k.bba.gz" "$($env:SRC_DIR)\chipdb-extract\chipdb-25k.bba"
DeGZip-File "$($env:RECIPE_DIR)\chipdb\chipdb-45k.bba.gz" "$($env:SRC_DIR)\chipdb-extract\chipdb-45k.bba"
DeGZip-File "$($env:RECIPE_DIR)\chipdb\chipdb-85k.bba.gz" "$($env:SRC_DIR)\chipdb-extract\chipdb-85k.bba"
$chipdb = "$($env:SRC_DIR.replace("\", "/"))/chipdb-extract"

Write-Output ""
Set-Location $env:SRC_DIR

$compiler = "Visual Studio 16 2019"
$arch = ""
If ($true) {
    $compiler = "Visual Studio 15 2017"
    $arch = ""
} else {
    $compiler = "Visual Studio 16 2019"
    $arch = "-A x64"
}

# cmake "-DCMAKE_TOOLCHAIN_FILE=$($vcpkg_path.replace("\", "/"))/scripts/buildsystems/vcpkg.cmake" -DARCH=ecp5 "-DTRELLIS_ROOT=$prjtrellis" "-DPYTRELLIS_LIBDIR=$libtrellis" "-DPREGENERATED_BBA_PATH=$chipdb" "-DCMAKE_INSTALL_PREFIX=$stage" -DVCPKG_TARGET_TRIPLET=x64-windows-static -G "Visual Studio 16 2019" -A "x64" -DSTATIC_BUILD=ON -DBUILD_GUI=OFF .


# cmake requires we use forward slashes, so patch up various environment variables
# to use forward slashes.
Get-ChildItem $Env:LIBRARY_PREFIX
$prjtrellis = "$($env:LIBRARY_PREFIX.replace("\", "/"))/share/trellis"
$libtrellis = "$($env:LIBRARY_PREFIX.replace("\", "/"))/share/trellis/libtrellis/release"
cmake "-DCMAKE_TOOLCHAIN_FILE=$($vcpkg_path.replace("\", "/"))/scripts/buildsystems/vcpkg.cmake" -DARCH=ecp5 "-DTRELLIS_ROOT=$prjtrellis" "-DPYTRELLIS_LIBDIR=$libtrellis" "-DPREGENERATED_BBA_PATH=$chipdb" "-DCMAKE_INSTALL_PREFIX=$stage" -DVCPKG_TARGET_TRIPLET=x64-windows-static -G "Visual Studio 15 2017" -A "x64" -DSTATIC_BUILD=ON -DBUILD_GUI=OFF .
if ($LastExitCode -ne 0) { exit $LastExitCode }
cmake --build . --target install --config Release
if ($LastExitCode -ne 0) { exit $LastExitCode }
