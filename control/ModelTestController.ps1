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

using namespace Opc.Ua
using namespace Opc.Ua.Client

class ModelTestController {
    [hashtable] $Methods = $null
    [string] $BaseNodeId = ''
    [string] $NodeSeparator = '.'

    static [PSCustomObject] CreateWrapped($Client, $BaseNodeId, $NodeSeparator) {
        $controller = [ModelTestController]::new($BaseNodeId, $NodeSeparator)
        $obj = [PSCustomObject]@{
            Client = $client
            Controller = $controller
        }

        $_methods = $controller.GetType().GetMethods()
        foreach ($method in $_methods) {
            $methodName = $method.Name

            $params = $method.GetParameters();
            if ($params.Count -gt 0 -and $params[0].ParameterType.Name -eq 'ISession') {
                $scriptBlock = [scriptblock]::Create("return `$this.Controller.$methodName.Invoke(@(`$this.Client.Session) + `$args)")
            }
            else {
                $scriptBlock = [scriptblock]::Create("return `$this.Controller.$methodName.Invoke(`$args)")
            }

            $obj | Add-Member -MemberType ScriptMethod -Name $methodName -Value $scriptBlock
        }

        return $obj
    }

    ModelTestController([string]$BaseNodeId) {
        $this.Init($BaseNodeId, '.')
    }

    ModelTestController([string]$BaseNodeId, [string]$NodeSeparator) {
        $this.Init($BaseNodeId, $NodeSeparator)
    }

    hidden [void] Init([string]$BaseNodeId, [string]$NodeSeparator) {
        $this.BaseNodeId = $BaseNodeId
        $this.NodeSeparator = $NodeSeparator
        $this.Methods = @{}
    }

    hidden [void] DefineExecuteMethod([hashtable]$Definition) {
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
        }
    }

    hidden [void] DefineStrictExecuteMethod([hashtable]$Definition) {
        $methodName = $Definition.Name

        $checkCallableParams = [ReadValueIdCollection]::new()
        $checkCallableParam = New-Object ReadValueId -Property @{
            AttributeId = [Attributes]::Value
        }
        $checkCallableParam.NodeId = [NodeId]::new((@($this.BaseNodeId, $methodName, 'Busy') -join $this.NodeSeparator))
        $checkCallableParams.Add($checkCallableParam)

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

        $checkClearedParams = [ReadValueIdCollection]::new()
        $checkClearedParam = New-Object ReadValueId -Property @{
            AttributeId = [Attributes]::Value
        }
        $checkClearedParam.NodeId = [NodeId]::new((@($this.BaseNodeId, $methodName, 'Done') -join $this.NodeSeparator))
        $checkClearedParams.Add($checkClearedParam)

        $this.Methods[$methodName] = @{
            CheckCallableParams = $checkCallableParams
            CallParams = $callParams
            DoneParams = $doneParams
            ClearParams = $clearParams
            CheckClearedParams = $checkClearedParams
            InProcessor = $Definition.InProcessor
            OutProcessor = $Definition.OutProcessor
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
            if ($null -ne $Context.CheckCallableParams) {
                $results= [DataValueCollection]::new()
                $diagnosticInfos = [DiagnosticInfoCollection]::new()
                do {
                    $response = $Session.Read(
                        $null,
                        [double]0,
                        [TimestampsToReturn]::Both,
                        $Context.CheckCallableParams,
                        [ref]$results,
                        [ref]$diagnosticInfos
                    )
                    if ($null -ne ($exception = $this.ValidateResponse(
                                                        $response,
                                                        $results,
                                                        $diagnosticInfos,
                                                        $Context.CheckCallableParams,
                                                        'Failed to check callable.'))
                    ) {
                        throw $exception
                    }
                }
                until ($results.Count -gt 0 -and -not $results[0].Value)
            }

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

            if ($null -ne $Context.CheckClearedParams) {
                $results= [DataValueCollection]::new()
                $diagnosticInfos = [DiagnosticInfoCollection]::new()
                do {
                    $response = $Session.Read(
                        $null,
                        [double]0,
                        [TimestampsToReturn]::Both,
                        $Context.CheckClearedParams,
                        [ref]$results,
                        [ref]$diagnosticInfos
                    )
                    if ($null -ne ($exception = $this.ValidateResponse(
                                                        $response,
                                                        $results,
                                                        $diagnosticInfos,
                                                        $Context.CheckCallableParams,
                                                        'Failed to check cleared.'))
                    ) {
                        throw $exception
                    }
                }
                until ($results.Count -gt 0 -and -not $results[0].Value)
            }
        }
    }

    hidden [Object] ValidateResponse($Response, $Results, $DiagnosticInfos, $Requests, $ExceptionMessage) {
        if (($Results
                | Where-Object { $_ -is [StatusCode]}
                | ForEach-Object { [ServiceResult]::IsNotGood($_) }
            ) -contains $true `
            -or ($Results.Count -ne $Requests.Count)
        ) {
            return [ModelTestControllerMethodCallException]::new($ExceptionMessage, @{
                Response = $Response
                Results = $Results
                DiagnosticInfos = $DiagnosticInfos
            })
        } else {
            return $null
        }
    }

    [hashtable] GetMethodContext([string]$Name) {
        if ($null -eq $this.Methods.$Name) {
            return $null
        }

        return @{
            CheckCallableParams = $this.Methods.$Name.CheckCallableParams?.Clone()
            CallParams = $this.Methods.$Name.CallParams.Clone()
            DoneParams = $this.Methods.$Name.DoneParams.Clone()
            ClearParams = $this.Methods.$Name.ClearParams.Clone()
            CheckClearedParams = $this.Methods.$Name.CheckClearedParams?.Clone()
            InProcessor = $this.Methods.$Name.InProcessor
            OutProcessor = $this.Methods.$Name.OutProcessor
        }
    }

    [void] Initialize([ISession]$Session) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName)
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefineStrictExecuteMethod(@{
                Name = $methodName
                InParams = @()
                OutParams = @()
                InProcessor = {}
                OutProcessor = {}
            })
            $methodContext = $this.GetMethodContext($methodName)
        }

        $this.CallMethod($Session, $methodContext)
            | Out-Null
    }

    [void] SetupApplication([ISession]$Session) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName)
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefineStrictExecuteMethod(@{
                Name = $methodName
                InParams = @()
                OutParams = @()
                InProcessor = {}
                OutProcessor = {}
            })
            $methodContext = $this.GetMethodContext($methodName)
        }

        $this.CallMethod($Session, $methodContext)
            | Out-Null
    }

    [void] ActivateService([ISession]$Session) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName)
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefineStrictExecuteMethod(@{
                Name = $methodName
                InParams = @()
                OutParams = @()
                InProcessor = {}
                OutProcessor = {}
            })
            $methodContext = $this.GetMethodContext($methodName)
        }

        $this.CallMethod($Session, $methodContext)
            | Out-Null
    }

    [void] DeactivateService([ISession]$Session) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName)
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefineStrictExecuteMethod(@{
                Name = $methodName
                InParams = @()
                OutParams = @()
                InProcessor = {}
                OutProcessor = {}
            })
            $methodContext = $this.GetMethodContext($methodName)
        }

        $this.CallMethod($Session, $methodContext)
            | Out-Null
    }

    [void] TearDown([ISession]$Session) {
        $methodContext = $this.GetMethodContext((Get-PSCallStack)[0].FunctionName)
        if ($null -eq $methodContext) {
            $methodName = (Get-PSCallStack)[0].FunctionName
            $this.DefineStrictExecuteMethod(@{
                Name = $methodName
                InParams = @()
                OutParams = @()
                InProcessor = {}
                OutProcessor = {}
            })
            $methodContext = $this.GetMethodContext($methodName)
        }

        $this.CallMethod($Session, $methodContext)
            | Out-Null
    }
}

class ModelTestControllerMethodCallException : System.Exception {
    [hashtable]$CallInfo
    ModelTestControllerMethodCallException([string]$Message, [hashtable]$CallInfo) : base($Message) {
        $this.CallInfo = $CallInfo
    }
}
