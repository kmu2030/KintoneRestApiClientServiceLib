<#
GNU General Public License, Version 2.0

Copyright (C) 2025 KITA Munemitsu
https://github.com/kmu2030/PwshOpcUaClient

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

using namespace Opc.Ua
using namespace Opc.Ua.Client
using namespace Opc.Ua.Client.ComplexTypes
using namespace Opc.Ua.Configuration
. "$PSScriptRoot\LoadAssembly.ps1"

function New-DefaultPwshOpcUaClientApplication {
    # Create application certificates.
    $applicationCertificates = New-Object CertificateIdentifierCollection 
    foreach($alg in @('RsaSha256', 'NistP256', 'NistP384', 'BrainpoolP256r1')) {
        $applicationCertificates.Add((New-Object CertificateIdentifier -Property @{
            StoreType = 'Directory'
            StorePath = "$PSScriptRoot/pki/own"
            SubjectName = 'CN=Pwsh Opc Ua Client, C=JP, S=Tokyo, O=ST freak, DC=localhost'
            CertificateTypeString = $alg 
        }))
    }

    $certificatePasswordProvider = New-Object CertificatePasswordProvider -ArgumentList ''
    $securityConfiguration = New-Object SecurityConfiguration -Property @{
        ApplicationCertificates = $applicationCertificates
        CertificatePasswordProvider = $certificatePasswordProvider
        AutoAcceptUntrustedCertificates = $true
        TrustedPeerCertificates = New-Object CertificateTrustList -Property @{
            StoreType = 'Directory'
            StorePath = "$PSScriptRoot/pki/trusted"
        }
        TrustedIssuerCertificates = New-Object CertificateTrustList -Property @{
            StoreType = 'Directory'
            StorePath = "$PSScriptRoot/pki/issuer"
        }
        RejectedCertificateStore = New-Object CertificateStoreIdentifier -Property @{
            StoreType = 'Directory'
            StorePath = "$PSScriptRoot/pki/rejected"
        }
        UserIssuerCertificates = New-Object CertificateTrustList -Property @{
            StoreType = 'Directory'
            StorePath = "$PSScriptRoot/pki/userIssuer"
        }
        TrustedUserCertificates = New-Object CertificateTrustList -Property @{
            StoreType = 'Directory'
            StorePath = "$PSScriptRoot/pki/trustedUser"
        }
        HttpsIssuerCertificates = New-Object CertificateTrustList -Property @{
            StoreType = 'Directory'
            StorePath = "$PSScriptRoot/pki/httpsIssuer"
        }
        TrustedHttpsCertificates = New-Object CertificateTrustList -Property @{
            StoreType = 'Directory'
            StorePath = "$PSScriptRoot/pki/trustedHttps"
        }
    }

    $wellKnownDiscoveryUrls = New-Object StringCollection -ArgumentList 1
    $wellknownDiscoveryUrls.Add('opc.tcp://localhost:4840')
    $clientConfiguration = New-Object ClientConfiguration -Property @{
        # DefaultSessionTimeout = 60000
        # MinSubscriptionLifeTime = 10000
        OperationLimits = New-Object OperationLimits -Property @{
            MaxNodesPerRead = 2500;
            MaxNodesPerHistoryReadData = 1000;
            MaxNodesPerHistoryReadEvents = 1000;
            MaxNodesPerWrite = 2500;
            MaxNodesPerHistoryUpdateData = 1000;
            MaxNodesPerHistoryUpdateEvents = 1000;
            MaxNodesPerMethodCall = 2500;
            MaxNodesPerBrowse = 2500;
            MaxNodesPerRegisterNodes = 2500;
            MaxNodesPerTranslateBrowsePathsToNodeIds = 2500;
            MaxNodesPerNodeManagement = 2500;
            MaxMonitoredItemsPerCall = 2500;
        }
        WellKnownDiscoveryUrls = $wellKnownDiscoveryUrls
    }

    $applicationName = 'Pwsh Opc Ua Client'
    $appConfiguration = New-Object ApplicationConfiguration -Property @{
        ApplicationName = $applicationName
        ApplicationUri = 'urn:localhost:OpcUaClientTools:PwshOpcUaClient'
        ApplicationType = [ApplicationType]::Client
        ProductUri = 'uri:stfreak.jp:OpcUaClientTools:PwshOpcUaClient'
        SecurityConfiguration = $securityConfiguration
        ClientConfiguration = $clientConfiguration
        TransportQuotas = New-Object TransportQuotas -Property @{
            # encoding limits
            MaxMessageSize = 4194304 #NX1:61440 (60KB) (SBCD-374, 1-6)
            MaxStringLength = 4194304 #NX1:1986
            MaxByteStringLength = 4194304
            MaxArrayLength = 65535 #NX1:~10000? 65535 is not allowed.
            # MaxEncodingNestingLevels
            # MaxDecoderRecoveries

            # message limits
            MaxBufferSize = 65535
            OperationTimeout = 120000
            ChannelLifetime = 300000
            SecurityTokenLifetime = 3600000
        }
        TraceConfiguration = New-Object TraceConfiguration -Property @{
            OutputFilePath = "$PSScriptRoot\logs\OpcUaClientTools.PwshOpcUaClient.log.txt"
            DeleteOnLoad = $false
            TraceMasks = 519
        }
    }
    $appConfiguration.validate([ApplicationType]::Client).ConfigureAwait($false).GetAwaiter().GetResult()
        | Out-Null
    $appConfiguration.TraceConfiguration.ApplySettings()
        | Out-Null

    New-Object ApplicationInstance -Property @{
        ApplicationName = $applicationName
        ApplicationType = [ApplicationType]::Client
        ApplicationConfiguration = $appConfiguration
        ConfigSectionName = 'PwshOpcUaClient'
        CertificatePasswordProvider = $certificatePasswordProvider
    }
}

function New-PwshOpcUaClientApplication {
    param(
        [string]$ConfigFilePath = $null
    )

    if ([String]::IsNullOrEmpty($ConfigFilePath)) {
        return (New-DefaultPwshOpcUaClientApplication)
    }

    $passwordProvider = New-Object CertificatePasswordProvider -ArgumentList ''
    $application = New-Object ApplicationInstance -Property @{
        ApplicationName = 'Pwsh Opc Ua Client'
        ApplicationType = [ApplicationType]::Client
        ConfigSectionName = 'PwshOpcUaClient'
        CertificatePasswordProvider = $passwordProvider
    }

    $application.LoadApplicationConfiguration($ConfigFilePath, $true).ConfigureAwait($false).GetAwaiter().GetResult()
        | Out-Null
    $application
}

function New-PwshOpcUaClientCert {
    param(
        [ApplicationInstance]$Application
    )

    $ok = $Application.DeleteApplicationInstanceCertificate().GetAwaiter().GetResult()
    $ok -and $Application.CheckApplicationInstanceCertificates($true).GetAwaiter().GetResult()
}

function New-PwshOpcUaClient {
    param(
        [string]$ServerUrl = 'opc.tcp://localhost:4840',
        [UserIdentity]$AccessUserIdentity = $null,
        [bool]$UseSecurity = $true,
        [int]$SessionLifeTime = 60000,
        [string]$ConfigFilePath = $null
    )

    $application = New-PwshOpcUaClientApplication -ConfigFilePath $ConfigFilePath
    $application.CheckApplicationInstanceCertificates($true).ConfigureAwait($false).GetAwaiter().GetResult()
        | Out-Null
    $endpointDescription = [CoreClientUtils]::SelectEndpoint($application.ApplicationConfiguration, $ServerUrl, $UseSecurity)
    $endpointConfiguration = [EndpointConfiguration]::Create($application.ApplicationConfiguration)
    $endpoint = New-Object ConfiguredEndpoint -ArgumentList $null, $endpointDescription, $endpointConfiguration

    # if null then Anonymous
    $AccessUserIdentity ??= New-Object UserIdentity
    $session = [TraceableSessionFactory]::Instance.CreateAsync(
        $application.ApplicationConfiguration,
        $endpoint,
        $false,
        $application.ApplicationConfiguration.ApplicationName,
        $SessionLifeTime,
        $AccessUserIdentity,
        $null
    ).ConfigureAwait($false).GetAwaiter().GetResult()

    $complexTypeSystem = New-Object ComplexTypeSystem -ArgumentList $session
    $complexTypeSystem.Load().ConfigureAwait($false).GetAwaiter().GetResult()
        | Out-Null

    @{
        Application = $application
        Endpoint = $endpoint
        Session = $session
        ComplexTypeSystem = $complexTypeSystem
    }
}

function Dispose-PwsOpcUaClient {
    param(
        [hashtable]$Client
    )
    if ($null -eq $Client -or $null -eq $Client.Session) {
        return
    }

    [void]$Client.Session.Close()
    [void]$Client.Session.Dispose()
    $Client.Session = $null
    $Client.Application = $null
    $Client.Endpoint = $null
    $Client.ComplexTypeSystem = $null
}
