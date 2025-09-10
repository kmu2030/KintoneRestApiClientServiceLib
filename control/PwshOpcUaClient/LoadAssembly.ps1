<#
GNU General Public License, Version 2.0

Copyright (C) 2025 KITA Munemitsu
https://github.com/kmu2030

This program is free software; you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation;
either version 2 of the License, or (at your option) any later version.
This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.
You should have received a copy of the GNU General Public License along with this program;
if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#>

if ([bool]([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -like "*Opc.Ua.Core*" })) {
    exit
}

$libPath = "$PSScriptRoot\libs"
$libDotnetVersion = 'net9.0'
@(
    'Microsoft.Extensions.Logging.Abstractions.dll'
    'Opc.Ua.Core.dll'
    'Opc.Ua.Security.Certificates.dll'
    'Opc.Ua.Configuration.dll'
    'Opc.Ua.Client.dll'
    'Opc.Ua.Client.ComplexTypes.dll'
)
| ForEach-Object { (Get-ChildItem -Path $libPath -Recurse -Include $_ | Where-Object {$_.Directory.Name -contains $libDotnetVersion}) }
| ForEach-Object { Add-Type -Path $_.FullName }
