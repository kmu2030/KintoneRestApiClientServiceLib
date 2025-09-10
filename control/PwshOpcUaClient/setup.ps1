$tmpDir = "$PSScriptRoot\tmp"
$libDir = "$PSScriptRoot\libs"
$setupLog = "$PSScriptRoot\setup.log.txt"
& {
    # Cleanup.
    if (Test-Path -Path $tmpDir) {
        Remove-Item $tmpDir -Recurse
    }
    if (Test-Path -Path $libDir) {
        Remove-Item $libDir -Recurse
    }

    # Download nuget.
    New-Item -ItemType Directory -Path $tmpDir -Force
    Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile "$tmpDir\nuget.exe"
    $env:Path += ";$tmpDir"
    # Get related DLLs.
    nuget install OPCFoundation.NetStandard.Opc.Ua.Client -Version 1.5.376.244 -OutputDirectory "$tmpDir/libs"
    nuget install OPCFoundation.NetStandard.Opc.Ua.Client.ComplexTypes -Version 1.5.376.244 -OutputDirectory "$tmpDir/libs"

    Move-Item -Path "$tmpDir/libs" -Destination $libDir
    Remove-Item $tmpDir -Recurse
} >$setupLog 2>&1
