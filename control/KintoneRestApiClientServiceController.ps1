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

using namespace Opc.Ua
using namespace Opc.Ua.Configuration
using namespace Opc.Ua.Client
using namespace Opc.Ua.Client.ComplexTypes

class KintoneRestApiClientServiceController {
    [hashtable] $Methods = $null
    [hashtable] $Properties = $null
    [string] $BaseNodeId = ''
    [string] $NodeSeparator = '.'

    KintoneRestApiClientServiceController([string]$BaseNodeId) {
        $this.Init($BaseNodeId, '.')
    }

    KintoneRestApiClientServiceController([string]$BaseNodeId, [string]$NodeSeparator) {
        $this.Init($BaseNodeId, $NodeSeparator)
    }

    hidden [void] Init([string]$BaseNodeId, [string]$NodeSeparator) {
        $this.BaseNodeId = $BaseNodeId
        $this.NodeSeparator = $NodeSeparator
        $this.Methods = @{}
        $this.Properties = @{}
    }

    hidden [void] DefinePseudoMethod([hashtable]$Definition) {
        $methodName = $Definition.Name

        $callParams = [WriteValueCollection]::new()
        foreach ($p in $Definition.InParams) {
            $callParam = [WriteValue]::new()
            $callParam.NodeId = [NodeId]::new((@($this.BaseNodeId, $methodName, $p) -join $this.NodeSeparator))
            $callParam.AttributeId = [Attributes]::Value
            $callParam.Value = [DataValue]::new()
            $callParams.Add($callParam)
        }
        $callParam = [WriteValue]::new()
        $callParam.NodeId = [NodeId]::new((@($this.BaseNodeId, $methodName, 'Execute') -join $this.NodeSeparator))
        $callParam.AttributeId = [Attributes]::Value
        $callParam.Value = [DataValue]::new()
        $callParam.Value.Value = $true
        $callParams.Add($callParam)

        $doneParams = [ReadValueIdCollection]::new()
        $doneParam = New-Object ReadValueId -Property @{
            AttributeId = [Attributes]::Value
        }
        $doneParam.NodeId = [NodeId]::new((@($this.BaseNodeId, $methodName, 'Done') -join $this.NodeSeparator))
        $doneParams.Add($doneParam)
        foreach ($p in $Definition.OutParams) {
            $doneParam = New-Object ReadValueId -Property @{
                AttributeId = [Attributes]::Value
            }
            $doneParam.NodeId = [NodeId]::new((@($this.BaseNodeId, $methodName, $p) -join $this.NodeSeparator))
            $doneParams.Add($doneParam)
        }

        $clearParams = [WriteValueCollection]::new()
        $clearParam = [WriteValue]::new()
        $clearParam.NodeId = [NodeId]::new((@($this.BaseNodeId, $methodName, 'Execute') -join $this.NodeSeparator))
        $clearParam.AttributeId = [Attributes]::Value
        $clearParam.Value = [DataValue]::new()
        $clearParam.Value.Value = $false
        $clearParams.Add($clearParam)

        $this.Methods[$methodName] = @{
            CallParams = $callParams
            DoneParams = $doneParams
            ClearParams = $clearParams
            InProcessor = $Definition.InProcessor
            OutProcessor = $Definition.OutProcessor
            OnCalled = $Definition.OnCalled
            OnDone = $Definition.OnDone
            OnCleared = $Definition.OnCleared
        }
    }

    hidden [void] DefineProperty([hashtable]$Definition) {
        $readValues = [ReadValueIdCollection]::new()
        foreach ($r in $Definition.ReadValues) {
            $readValue = New-Object ReadValueId -Property @{
                AttributeId = [Attributes]::Value
            }
            $readValue.NodeId = [NodeId]::new((@($this.BaseNodeId, $r) -join $this.NodeSeparator))
            $readValues.Add($readValue)
        }

        $this.Properties[$Definition.Name] = @{
            ReadValues = $readValues
            PostProcessor = $Definition.PostProcessor
        }
    }

    hidden [Object] CallMethod(
        [ISession]$Session,
        [hashtable]$Context
    ) {
        return $this.CallMethod($Session, $Context, $null)
    }

    hidden [Object] CallMethod(
        [ISession]$Session,
        [hashtable]$Context,
        [array]$CallArgs
    ) {
        if (-not $Session.Connected) {
            throw [System.ArgumentException]::new('Session is not connected.', $Session, 'Session')
        }

        if ($null -ne $CallArgs) {
            (& $Context.InProcessor $CallArgs $Context)
                | Out-Null
        }

        $exception = $null
        try {
            $results = $null
            $diagnosticInfos = $null
            $response = $Session.Write(
                $null,
                $Context.CallParams,
                [ref]$results,
                [ref]$diagnosticInfos
            )
            if ($null -ne ($exception = $this.ValidateResponse(
                                                $response,
                                                $results,
                                                $diagnosticInfos,
                                                $Context.CallParams,
                                                'Failed to write call parameters.'))
            ) {
                throw $exception
            }

            if ($null -ne $Context.OnCalled) {
                (& $Context.OnCalled $response $results $diagnosticInfos $Context)
            }
    
            $results= [DataValueCollection]::new()
            $diagnosticInfos = [DiagnosticInfoCollection]::new()
            do {
                $response = $Session.Read(
                    $null,
                    [double]0,
                    [TimestampsToReturn]::Both,
                    $Context.DoneParams,
                    [ref]$results,
                    [ref]$diagnosticInfos
                )
                if ($null -ne ($exception = $this.ValidateResponse(
                                                    $response,
                                                    $results,
                                                    $diagnosticInfos,
                                                    $Context.DoneParams,
                                                    'Failed to get execution result parameters.'))
                ) {
                    throw $exception
                }
            }
            until ($results.Count -gt 0 -and $results[0].Value)
    
            if ($null -ne $Context.OnDone) {
                (& $Context.OnDone $response $results $diagnosticInfos $Context)
            }

            $outs = New-Object System.Collections.ArrayList
            foreach ($r in $results | Select-Object -Skip 1) {
                $outs.Add($r.Value)
            }
    
            return (& $Context.OutProcessor $outs $Context)
        }
        finally {
            $results = $null
            $diagnosticInfos = $null
            $response = $Session.Write(
                $null,
                $Context.ClearParams,
                [ref]$results,
                [ref]$diagnosticInfos
            )
            if (($null -ne ($_exception = $this.ValidateResponse(
                                                $response,
                                                $results,
                                                $diagnosticInfos,
                                                $Context.ClearParams,
                                                'Failed to clear method call parameters.'))) `
                -and ($null -eq $exception)
            ) {
                throw $_exception
            }

            if ($null -ne $Context.OnCleared) {
                (& $Context.OnCleared $response $results $diagnosticInfos $Context)
            }
        }
    }

    hidden [Object] FetchProperty(
        [ISession]$Session,
        [hashtable]$Context
    ) {
        if (-not $Session.Connected) {
            throw [System.ArgumentException]::new('Session is not connected.', $Session, 'Session')
        }
  
        $results= [DataValueCollection]::new()
        $diagnosticInfos = [DiagnosticInfoCollection]::new()
        do {
            $response = $Session.Read(
                $null,
                [double]0,
                [TimestampsToReturn]::Both,
                $Context.ReadValues,
                [ref]$results,
                [ref]$diagnosticInfos
            )
            if ($null -ne ($exception = $this.ValidateResponse(
                                                $response,
                                                $results,
                                                $diagnosticInfos,
                                                $Context.ReadValues,
                                                'Failed to read values.'))
            ) {
                throw $exception
            }
        }
        until ($results.Count -eq $Context.ReadValues.Count)

        $reads = New-Object System.Collections.ArrayList
        foreach ($r in $results) {
            $reads.Add($r.Value)
        }

        return (& $Context.PostProcessor $reads $Context)
    }

    hidden [Object] ValidateResponse($Response, $Results, $DiagnosticInfos, $Requests, $ExceptionMessage) {
        if (($Results
                | Where-Object { $_ -is [StatusCode]}
                | ForEach-Object { [ServiceResult]::IsNotGood($_) }
            ) -contains $true `
            -or ($Results.Count -ne $Requests.Count)
        ) {
            return [MethodCallException]::new($ExceptionMessage, @{
                Response = $Response
                Results = $Results
                DiagnosticInfos = $DiagnosticInfos
            })
        } else {
            return $null
        }
    }

    hidden [hashtable] GetMethodContext([string]$Name) {
        if ($null -eq $this.Methods.$Name) {
            return $null
        }

        return @{
            CallParams = $this.Methods.$Name.CallParams.Clone()
            DoneParams = $this.Methods.$Name.DoneParams.Clone()
            ClearParams = $this.Methods.$Name.ClearParams.Clone()
            InProcessor = $this.Methods.$Name.InProcessor
            OutProcessor = $this.Methods.$Name.OutProcessor
            OnCalled = $this.Methods.$Name.OnCalled
            OnDone = $this.Methods.$Name.OnDone
            OnCleared = $this.Methods.$Name.OnCleared
        }
    }

    hidden [hashtable] GetPropertyContext([string]$Name) {
        if ($null -eq $this.Properties.$Name) {
            return $null
        }

        return @{
            ReadValues = $this.Properties.$Name.ReadValues.Clone()
            PostProcessor = $this.Properties.$Name.PostProcessor
        }
    }

    [bool] IsBusy ([ISession]$Session) {
        $propContext = $this.GetPropertyContext((Get-PSCallStack)[0].FunctionName);
        if ($null -eq $propContext) {
            $propName = (Get-PSCallStack)[0].FunctionName
            $this.DefineProperty(@{
                Name = $propName
                ReadValues = @($propName)
                PostProcessor = {
                    param($Reads, $Context)
                    return $Reads[0]
                }
            })
            $propContext = $this.GetPropertyContext($propName);
        }

        return [bool]$this.FetchProperty($Session, $propContext)
    }

    [bool] IsActive ([ISession]$Session) {
        $propContext = $this.GetPropertyContext((Get-PSCallStack)[0].FunctionName);
        if ($null -eq $propContext) {
            $propName = (Get-PSCallStack)[0].FunctionName
            $this.DefineProperty(@{
                Name = $propName
                ReadValues = @($propName)
                PostProcessor = {
                    param($Reads, $Context)
                    return $Reads[0]
                }
            })
            $propContext = $this.GetPropertyContext($propName);
        }

        return [bool]$this.FetchProperty($Session, $propContext)
    }

    [bool] IsHalt ([ISession]$Session) {
        $propContext = $this.GetPropertyContext((Get-PSCallStack)[0].FunctionName);
        if ($null -eq $propContext) {
            $propName = (Get-PSCallStack)[0].FunctionName
            $this.DefineProperty(@{
                Name = $propName
                ReadValues = @($propName)
                PostProcessor = {
                    param($Reads, $Context)
                    return $Reads[0]
                }
            })
            $propContext = $this.GetPropertyContext($propName);
        }

        return [bool]$this.FetchProperty($Session, $propContext)
    }

    [bool] Start([ISession]$Session) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName);
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefinePseudoMethod(@{
                Name = $methodName
                InParams = @()
                OutParams = @('Ok')
                InProcessor = {}
                OutProcessor = {
                    param($Outs, $Context)
                    return $Outs[0]
                }
            })
            $methodContext = $this.GetMethodContext($methodName);
        }

        return [bool]$this.CallMethod($Session, $methodContext)
    }

    [bool] Stop([ISession]$Session) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName);
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefinePseudoMethod(@{
                Name = $methodName
                InParams = @()
                OutParams = @('Ok')
                InProcessor = {}
                OutProcessor = {
                    param($Outs, $Context)
                    return $Outs[0]
                }
            })
            $methodContext = $this.GetMethodContext($methodName);
        }

        return [bool]$this.CallMethod($Session, $methodContext)
    }

    [bool] Restart([ISession]$Session) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName);
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefinePseudoMethod(@{
                Name = $methodName
                InParams = @()
                OutParams = @('Ok')
                InProcessor = {}
                OutProcessor = {
                    param($Outs, $Context)
                    return $Outs[0]
                }
            })
            $methodContext = $this.GetMethodContext($methodName);
        }

        return [bool]$this.CallMethod($Session, $methodContext)
    }

    [bool] InitSettings([ISession]$Session) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName);
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefinePseudoMethod(@{
                Name = $methodName
                InParams = @()
                OutParams = @('Ok')
                InProcessor = {}
                OutProcessor = {
                    param($Outs, $Context)
                    return $Outs[0]
                }
            })
            $methodContext = $this.GetMethodContext($methodName);
        }

        return [bool]$this.CallMethod($Session, $methodContext)
    }

    [bool] RegisterApplication([ISession]$Session, [hashtable]$application) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName);
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefinePseudoMethod(@{
                Name = $methodName
                InParams = @('Name', 'Subdomain', 'AppId', 'ApiToken', 'TlsSessionName')
                OutParams = @('Ok')
                InProcessor = {
                    param($CallArgs, $Context)
                    $Context.CallParams[0].Value.Value = $CallArgs[0].Name
                    $Context.CallParams[1].Value.Value = $CallArgs[0].Subdomain
                    $Context.CallParams[2].Value.Value = $CallArgs[0].AppId
                    $Context.CallParams[3].Value.Value = $CallArgs[0].ApiToken
                    $Context.CallParams[4].Value.Value = $CallArgs[0].TlsSessionName
                }
                OutProcessor = {
                    param($Outs, $Context)
                    return $Outs[0]
                }
            })
            $methodContext = $this.GetMethodContext($methodName);
        }

        return [bool]$this.CallMethod($Session, $methodContext, @(,$application))
    }

    [bool] RegisterTlsSession([ISession]$Session, [string]$TlsSessionName) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName);
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefinePseudoMethod(@{
                Name = $methodName
                InParams = @('TlsSessionName')
                OutParams = @('Ok')
                InProcessor = {
                    param($CallArgs, $Context)
                    $Context.CallParams[0].Value.Value = $CallArgs[0]
                }
                OutProcessor = {
                    param($Outs, $Context)
                    return $Outs[0]
                }
            })
            $methodContext = $this.GetMethodContext($methodName);
        }

        return [bool]$this.CallMethod($Session, $methodContext, @(,$TlsSessionName))
    }

    [bool] ApplySettings([ISession]$Session, [hashtable]$Settings) {
        $this.InitSettings($Session)

        $results = $Settings.Applications
            | ForEach-Object { $this.RegisterApplication($Session, $_) }
        if ($results -contains $false) { return $false }

        $results = $Settings.TlsSessionNames
            | ForEach-Object { $this.RegisterTlsSession($Session, $_) }

        return $results -notcontains $false
    }
}

class MethodCallException : System.Exception {
    [hashtable]$CallInfo
    MethodCallException([string]$Message, [hashtable]$CallInfo) : base($Message) {
        $this.CallInfo = $CallInfo
    }
}
