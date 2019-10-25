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

# Allow us to access System.IO.Compression.GzipStream
Add-Type -AssemblyName System.IO.Compression.FileSystem

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

# cmake requires we use forward slashes, so patch up various environment variables
# to use forward slashes.
$prjtrellis = "$($env:LIBRARY_PREFIX.replace("\", "/"))/share/trellis"
$libtrellis = "$($env:LIBRARY_PREFIX.replace("\", "/"))/share/trellis/libtrellis/release"

Write-Output ""
Set-Location $env:SRC_DIR

# Configure cmake
cmake -DARCH=ecp5 "-DTRELLIS_ROOT=$prjtrellis" "-DPYTRELLIS_LIBDIR=$libtrellis" "-DPREGENERATED_BBA_PATH=$chipdb" "-DCMAKE_INSTALL_PREFIX=$env:PREFIX" -G $env:CMAKE_GENERATOR -DSTATIC_BUILD=ON -DBUILD_GUI=OFF .
if ($LastExitCode -ne 0) { exit $LastExitCode }

# Perform the build
cmake --build . --target install --config Release --verbose
if ($LastExitCode -ne 0) { exit $LastExitCode }
