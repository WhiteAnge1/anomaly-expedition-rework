param([string]$ModRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$ModRoot = (Resolve-Path -LiteralPath $ModRoot).Path
$modulePath = Join-Path $ModRoot 'fomod\ModuleConfig.xml'
$content = @'
<?xml version="1.0" encoding="utf-8"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://qconsulting.ca/fo3/ModConfig5.0.xsd">
    <moduleName>[&#1043;&#1077;&#1081;&#1084;&#1087;&#1083;&#1077;&#1081;] Anomaly Expedition Rework by White_Angel 0.3.0-rc2</moduleName>
    <requiredInstallFiles>
        <folder source="gamedata" destination="gamedata" priority="0" />
    </requiredInstallFiles>
    <installSteps order="Explicit">
        <installStep name="Recommended">
            <optionalFileGroups order="Explicit">
                <group name="Configuration" type="SelectExactlyOne">
                    <plugins order="Explicit">
                        <plugin name="Recommended MCM baseline">
                            <description>Installs the tested defaults. Change supported gameplay settings in MCM after installation.</description>
                            <typeDescriptor><type name="Required" /></typeDescriptor>
                        </plugin>
                    </plugins>
                </group>
            </optionalFileGroups>
        </installStep>
    </installSteps>
</config>
'@
[IO.File]::WriteAllText($modulePath, $content.TrimStart(), (New-Object Text.UTF8Encoding($false)))
Write-Output 'Generated FOMOD: one Recommended MCM baseline; no LTX variants'
