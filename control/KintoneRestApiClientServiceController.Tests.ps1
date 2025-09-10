<#
GNU General Public License, Version 2.0

Copyright (C) 2025 KITA Munemitsu
https://github.com/kmu2030/RingBufferOpcUaExtensionLib

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
# このスクリプトについて
このスクリプトは**Pester**による`KintoneRestApiClientServiceController.ps1`のテストです。
コントローラまたは、シミュレータでモデルテスト(`ModelTest` POU)を動作させ、
OPC UAでアクセスできる状態にして使用します。

## 使用環境
コントローラ: OMRON社製 NX1(Ver.1.64以降), NX5(Ver.1.64以降), NX7(Ver.1.35以降), NJ5(Ver.1.63以降)
IDE        : Sysmac Studio Ver.1.62以降
PowerShell : PowerShell 7.5以降
Pester     : 5.7.1

## 使用手順 (シミュレータ)
1.  `./PwshOpcUaClient/setup.ps1`を実行
    `PwshOpcUaClient`が必要とするアセンブリをNuGetで取得。
2.  Sysmac Studioで`KintoneRestApiClientServiceLib.smc2`を開く
    `POU/プログラム/ModelTest`をタスクに登録し、OPC UAサーバ設定でFBインスタンスを登録する。
3.  シミュレータとシミュレータ用OPC UAサーバを起動
4.  シミュレータ用OPC UAサーバで証明書を生成
    既に生成してある場合は不要。
5.  シミュレータ用OPC UAサーバへユーザーとパスワードを登録
    既に登録してある場合は不要。
6.  `Invoke-Pester`を実行
7.  `PwshOpcUaClient`でサーバ証明書を信頼
    `./PwshOpcUaClient/pki/rejected/certs`にある拒否したサーバ証明書を`./PwshOpcUaClient/pki/trusted/certs`に移動。
8.  `Invoke-Pester`を実行

## 使用手順 (コントローラ)
1.  `./PwshOpcUaClient/setup.ps1`を実行
    `PwshOpcUaClient`が必要とするアセンブリをNuGetで取得。
2.  Sysmac Studioで`KintoneRestApiClientServiceLib.smc2`を開く
    `POU/プログラム/ModelTest`をタスクに登録し、OPC UAサーバ設定でFBインスタンスを登録する。
3.  プロジェクトの構成と設定を使用するコントローラに合わせる
4.  プロジェクトをコントローラに転送
5.  コントローラのOPC UAサーバで証明書を生成
    既に生成してある場合は不要。
6.  コントローラのOPC UAサーバへユーザーとパスワードを登録
    既に登録してある場合は不要。
7.  Pesterを実行
    以下の`YOUR_SERVER_ENDPOINT`をコントローラのOPC UAサーバのエンドポイントに置き換え実行。
    ```powershell
    Invoke-Pester -Container $(New-PesterContainer -Path . -Data @{ UseSimulator=$false; ServerUrl=YOUR_SERVER_ENDPOINT })
    ```
8.  コントローラのOPC UAサーバでクライアント証明書の信頼
    拒否されたクライアント証明書を信頼する。
    Anonymousでメッセージ交換に署名も暗号化も使用しないのであれば不要。
9.  `PwshOpcUaClient`でサーバ証明書を信頼
    `./PwshOpcUaClient/pki/rejected/certs`にある拒否したサーバ証明書を`./PwshOpcUaClient/pki/trusted/certs`に移動。
10.  Pesterを実行
    以下の`YOUR_SERVER_ENDPOINT`をコントローラのOPC UAサーバのエンドポイントに置き換え実行。
    ```powershell
    Invoke-Pester -Container $(New-PesterContainer -Path . -Data @{ UseSimulator=$false; ServerUrl=YOUR_SERVER_ENDPOINT })
    ```
#>

using namespace Opc.Ua
param(
    [bool]$UseSimulator = $true,
    [string]$ServerUrl = 'opc.tcp://localhost:4840',
    [bool]$UseSecurity = $true,
    [string]$UserName = 'taker',
    [string]$UserPassword = 'chocolatepancakes'
)

BeforeAll {
    . "$PSScriptRoot/PwshOpcUaClient/PwshOpcUaClient.ps1"
    . "$PSScriptRoot/ModelTestController.ps1"
    . "$PSScriptRoot/KintoneRestApiClientServiceController.ps1"

    $AccessUserIdentity = [string]::IsNullOrEmpty($UserName) `
                            ? (New-Object UserIdentity) `
                            : (New-Object UserIdentity -ArgumentList $UserName, $UserPassword)
    $clientParam = @{
        ServerUrl = $ServerUrl
        UseSecurity = $UseSecurity
        SessionLifeTime = 60000
        AccessUserIdentity = $AccessUserIdentity
    }
    $client = New-PwshOpcUaClient @clientParam
    $nodeSeparator = $UseSimulator ? '.' : '/'
    $testNode = "ns=$($UseSimulator ? '2;Programs.' : '4;')ModelTest${nodeSeparator}KintoneRestApiClientService"

    $testController = [ModelTestController]::CreateWrapped($client, $testNode, $nodeSeparator)
    $testController.Initialize()

    $target = [KintoneRestApiClientServiceController]::new("${testNode}${nodeSeparator}Target", $nodeSeparator)
}

AfterAll {
    Dispose-PwsOpcUaClient -Client $client
}

Describe 'IsBusy' {
    It 'サービスが動作中であるとき、trueを返す' {
        $testController.SetupApplication()
        $testController.ActivateService()

        $IsBusy = $target.IsBusy($client.Session)

        $IsBusy
            | Should -BeTrue
    }

    It 'サービスが非動作中であるとき、falseを返す' {
        $testController.SetupApplication()

        $IsBusy = $target.IsBusy($client.Session)

        $IsBusy
            | Should -BeFalse
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        { $target.IsBusy($null) }
            | Should -Throw
    }

    AfterEach {
        $testController.TearDown()
    }
}

Describe 'IsActive' {
    It 'サービスが有効であるとき、trueを返す' {
        $testController.SetupApplication()
        $testController.ActivateService()

        $isActive = $target.IsActive($client.Session)

        $isActive
            | Should -BeTrue
    }

    It 'サービスが無効であるとき、falseを返す' {
        $testController.SetupApplication()

        $isActive = $target.IsActive($client.Session)

        $isActive
            | Should -BeFalse
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        { $target.IsActive($null) }
            | Should -Throw
    }

    AfterEach {
        $testController.TearDown()
    }
}

Describe 'IsHalt' {
    It 'サービスがHaltしたとき、trueを返す' {
        # アプリケーションの登録が無いのでHaltする。
        $target.Start($client.Session)
        Start-Sleep -Milliseconds 500

        $isHalt = $target.IsHalt($client.Session)

        $isHalt
            | Should -BeTrue
    }

    It 'サービスがHaltしていないとき、falseを返す' {
        $testController.SetupApplication()
        $testController.ActivateService()

        $isHalt = $target.IsHalt($client.Session)

        $isHalt
            | Should -BeFalse
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        { $target.IsHalt($null) }
            | Should -Throw
    }

    AfterEach {
        $testController.TearDown()
    }
}

Describe 'Start' {
    It 'サービスを開始する' {
        $testController.SetupApplication()

        $ok = $target.Start($client.Session)
        
        $ok | Should -BeTrue
        Start-Sleep -Milliseconds 100
        $target.IsActive($client.Session)
            | Should -BeTrue
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        { $target.Start($null) }
            | Should -Throw
    }
        
    AfterEach {
        $testController.TearDown()
    }
}

Describe 'Stop' {
    It 'サービスを停止する' {
        $testController.SetupApplication()
        $testController.ActivateService()

        $ok = $target.Stop($client.Session)
        
        $ok | Should -BeTrue
        Start-Sleep -Milliseconds 100
        $target.IsActive($client.Session)
            | Should -BeFalse
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        { $target.Stop($null) }
            | Should -Throw
    }
        
    AfterEach {
        $testController.TearDown()
    }
}

Describe 'Restart' {
    It 'サービスを再起動する' {
        $testController.SetupApplication()
        $testController.ActivateService()

        $ok = $target.Restart($client.Session)
        
        $ok | Should -BeTrue
        Start-Sleep -Milliseconds 500
        $target.IsActive($client.Session)
            | Should -BeTrue
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        { $target.Restart($null) }
            | Should -Throw
    }
        
    AfterEach {
        $testController.TearDown()
    }
}

Describe 'InitSettings' {
    It 'サービス設定を初期化する' {
        $ok = $target.InitSettings($client.Session)

        $ok | Should -BeTrue
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        { $target.InitSettings($null) }
            | Should -Throw
    }
        
    AfterEach {
        $testController.TearDown()
    }
}

Describe 'RegisterApplication' {
    It 'kintoneアプリケーションを登録する' {
        $app = @{
            Name = 'myapp'
            Subdomain = 'mysubdomain'
            AppId = 'myappid'
            ApiToken = 'myapitoken'
            TlsSessionName = ''
        }

        $ok = $target.RegisterApplication($client.Session, $app)

        $ok | Should -BeTrue
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        $app = @{
            Name = 'myapp'
            Subdomain = 'mysubdomain'
            AppId = 'myappid'
            ApiToken = 'myapitoken'
            TlsSessionName = ''
        }

        { $target.RegisterApplication($null, $app) }
            | Should -Throw
    }
        
    AfterEach {
        $testController.TearDown()
    }
}

Describe 'RegisterTlsSession' {
    It 'TLSセッションを登録する' {
        $tlsSessionName = 'TLSSession1'

        $ok = $target.RegisterTlsSession($client.Session, $tlsSessionName)

        $ok | Should -BeTrue
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        { $target.RegisterTlsSession($null, '') }
            | Should -Throw
    }
        
    AfterEach {
        $testController.TearDown()
    }
}

Describe 'ApplySettings' {
    It 'サービス設定を適用する' {
        $settings = @{
            Applications = @(
                @{
                    Name = 'myapp1'
                    Subdomain = 'mydomain'
                    AppId = 'appid1'
                    ApiToken = 'myapitoken1'
                    TlsSessionName = ''
                },
                @{
                    Name = 'myapp2'
                    Subdomain = 'mydomain'
                    AppId = 'appid2'
                    ApiToken = 'myapitoken2'
                    TlsSessionName = ''
                }
            )
            TlsSessionNames = @(
                'TLSSession0',
                'TLSSession1'
            )
        }

        $ok = $target.ApplySettings($client.Session, $settings)

        $ok | Should -BeTrue
        $target.Start($client.Session)
        Start-Sleep -Milliseconds 500
        $target.IsHalt($client.Session)
            | Should -BeFalse
        $target.IsActive($client.Session)
            | Should -BeTrue
    }

    It 'Sessionが不正であるとき、例外が発生する' {
        $settings = @{
            Applications = @(
                @{
                    Name = 'myapp1'
                    Subdomain = 'mydomain'
                    AppId = 'appid1'
                    ApiToken = 'myapitoken1'
                    TlsSessionName = ''
                },
                @{
                    Name = 'myapp2'
                    Subdomain = 'mydomain'
                    AppId = 'appid2'
                    ApiToken = 'myapitoken2'
                    TlsSessionName = ''
                }
            )
            TlsSessionNames = @(
                'TLSSession0',
                'TLSSession1'
            )
        }

        { $target.ApplySettings($null, $settings) }
            | Should -Throw
    }
        
    AfterEach {
        $testController.TearDown()
    }
}
