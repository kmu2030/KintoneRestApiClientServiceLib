<#
GNU General Public License, Version 2.0

Copyright (C) 2025 KITA Munemitsu
https://github.com/kmu2030/KintoneRestApiClientServiceLib

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

<#
# About This Script
This script starts the KintoneRestApiClientService running in the controller.
Parameters are passed as script arguments or environment variables.

## Usage Environment
Controllers: OMRON Co., Ltd. NX1 (Ver. 1.64 or later), NX5 (Ver. 1.64 or later), NX7 (Ver. 1.35 or later), NJ5 (Ver. 1.63 or later)
IDE        : Sysmac Studio Ver.1.62 or later
PowerShell : PowerShell 7.5 or later

## Environmental Variables
* OPC_UA_ENDPOINT: OPC UA server endpoint running on the controller.
* OPC_UA_CLIENT_USER: User accessing the OPC UA server.
* OPC_UA_CLIENT_USER_PASSWORD: User password accessing the OPC UA server.
* KINTONE_REST_API_CLIENT_SERVICE_NODE: Node ID of the KintoneRestApiClientService.


# このスクリプトについて
このスクリプトは、コントローラで動作するKintoneRestApiClientServiceを開始します。
パラメータは、スクリプトの引数または、環境変数で渡します。

## 使用環境
コントローラ: OMRON社製 NX1(Ver.1.64以降), NX5(Ver.1.64以降), NX7(Ver.1.35以降), NJ5(Ver.1.63以降)
IDE        : Sysmac Studio Ver.1.62以降
PowerShell : PowerShell 7.5以降

## 環境変数
* OPC_UA_ENDPOINT: コントローラで動作するOPC UAサーバエンドポイント
* OPC_UA_CLIENT_USER: OPC UAサーバにアクセスするユーザー
* OPC_UA_CLIENT_USER_PASSWORD: OPC UAサーバにアクセスするユーザーパスワード
* KINTONE_REST_API_CLIENT_SERVICE_NODE: KintoneRestApiClientServiceのノードID
#>

using namespace Opc.Ua
param(
    [string]$ServerUrl,
    [string]$UserName,
    [string]$UserPassword,
    [string]$ServiceNode
)
. "$PSScriptRoot/PwshOpcUaClient/PwshOpcUaClient.ps1"
. "$PSScriptRoot/KintoneRestApiClientServiceController.ps1"

try {
    $ServerUrl = [System.String]::IsNullOrEmpty($ServerUrl) ? $Env:OPC_UA_ENDPOINT : $ServerUrl
    $UserName = [System.String]::IsNullOrEmpty($UserName) ? $Env:OPC_UA_CLIENT_USER : $UserName
    $UserPassword = [System.String]::IsNullOrEmpty($UserPassword) ? $Env:OPC_UA_CLIENT_PASSWORD : $UserPassword
    $ServiceNode = [System.String]::IsNullOrEmpty($ServiceNode) ? $Env:KINTONE_REST_API_CLIENT_SERVICE_NODE : $ServiceNode

    $accessUserIdentity = [string]::IsNullOrEmpty($UserName) `
                            ? (New-Object UserIdentity) `
                            : (New-Object UserIdentity -ArgumentList $UserName, $UserPassword)
    $clientParam = @{
        ServerUrl = $ServerUrl
        UseSecurity = $true
        SessionLifeTime = 60000
        AccessUserIdentity = $accessUserIdentity
    }
    $client = New-PwshOpcUaClient @clientParam
    $clientParam = $null
    $accessUserIdentity = $null
    $UserPassword = $null

    $separator = '/'
    $service = [KintoneRestApiClientServiceController]::new($ServiceNode, $separator)

    & {
        $service.Start($client.Session)
        do {
            Start-Sleep -Milliseconds 200
            if ($service.IsHalt($client.Session)) { throw 'Service is halt.' } 
        }
        until ($service.IsActive($client.Session))
    } | Out-Null

    Write-Output $true
}
catch {
    Write-Error $_.Exception
    Write-Output $false
}
finally {
    Dispose-PwsOpcUaClient -Client $client
    $client = $null
}
