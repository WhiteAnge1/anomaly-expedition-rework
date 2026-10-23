param([string]$ModRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$ModRoot = (Resolve-Path -LiteralPath $ModRoot).Path
$modulePath = Join-Path $ModRoot 'fomod\ModuleConfig.xml'
$content = @'
<?xml version="1.0" encoding="utf-8"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://qconsulting.ca/fo3/ModConfig5.0.xsd">
    <moduleName>[&#1043;&#1077;&#1081;&#1084;&#1087;&#1083;&#1077;&#1081;] Anomaly Expedition Rework by White_Angel 0.3.0-rc5</moduleName>
    <requiredInstallFiles>
        <folder source="gamedata" destination="gamedata" priority="0" />
    </requiredInstallFiles>
    <installSteps order="Explicit">
        <installStep name="Рекомендуемая установка">
            <optionalFileGroups order="Explicit">
                <group name="Настройка" type="SelectExactlyOne">
                    <plugins order="Explicit">
                        <plugin name="Рекомендуемая базовая конфигурация MCM">
                            <description>Устанавливает проверенные значения по умолчанию. Поддерживаемые игровые параметры изменяются в MCM после установки.</description>
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
Write-Output 'Generated FOMOD: one Russian recommended MCM baseline; no LTX variants'
