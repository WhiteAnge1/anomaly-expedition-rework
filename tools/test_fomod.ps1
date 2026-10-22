param([string]$ModRoot = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
$ModRoot = (Resolve-Path -LiteralPath $ModRoot).Path
$modulePath = Join-Path $ModRoot 'fomod\ModuleConfig.xml'
$installerPath = Join-Path $ModRoot 'installer'
if (Test-Path -LiteralPath $installerPath) { throw 'Obsolete installer variant matrix must not be packaged' }
[xml]$xml = Get-Content -LiteralPath $modulePath -Raw -Encoding UTF8
$plugins = @($xml.config.installSteps.installStep.optionalFileGroups.group.plugins.plugin)
if ($plugins.Count -ne 1) { throw "Expected one Recommended plugin, found $($plugins.Count)" }
if ([string]$xml.config.installSteps.installStep.name -ne 'Рекомендуемая установка') { throw 'FOMOD install step must be Russian' }
if ([string]$xml.config.installSteps.installStep.optionalFileGroups.group.name -ne 'Настройка') { throw 'FOMOD group must be Russian' }
if ([string]$plugins[0].name -ne 'Рекомендуемая базовая конфигурация MCM') { throw 'Unexpected FOMOD baseline name' }
if ([string]$plugins[0].description -ne 'Устанавливает проверенные значения по умолчанию. Поддерживаемые игровые параметры изменяются в MCM после установки.') { throw 'FOMOD description must be Russian' }
if ([string]$plugins[0].typeDescriptor.type.name -ne 'Required') { throw 'Recommended baseline must be required' }
if ($null -ne $xml.config.conditionalFileInstalls) { throw 'Conditional LTX installs must not remain' }
if ([string]$xml.config.requiredInstallFiles.folder.source -ne 'gamedata') { throw 'FOMOD must install gamedata directly' }
Write-Output 'FOMOD baseline: OK (Russian user text; one required profile; settings delegated to MCM)'
