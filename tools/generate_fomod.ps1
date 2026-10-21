param(
    [string]$ModRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$ModRoot = (Resolve-Path -LiteralPath $ModRoot).Path
$basePath = Join-Path $ModRoot 'gamedata\configs\plugins\rvm_sorties_rework.ltx'
$variantRoot = Join-Path $ModRoot 'installer\variants'
$modulePath = Join-Path $ModRoot 'fomod\ModuleConfig.xml'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Set-ConfigValue([string]$Text, [string]$Key, [string]$Value) {
    $pattern = '(?m)^' + [regex]::Escape($Key) + '\s*=.*$'
    $matches = [regex]::Matches($Text, $pattern)
    if ($matches.Count -ne 1) { throw "Expected exactly one config key '$Key', found $($matches.Count)" }
    return [regex]::Replace($Text, $pattern, "$Key = $Value")
}

function FlagPlugin([string]$Name, [string]$Description, [string]$Flag, [string]$Value, [string]$Type) {
    return @"
                        <plugin name="$Name">
                            <description>$Description</description>
                            <conditionFlags><flag name="$Flag">$Value</flag></conditionFlags>
                            <typeDescriptor><type name="$Type" /></typeDescriptor>
                        </plugin>
"@
}

function Dependency([string]$Flag, [string]$Value) {
    return "                        <flagDependency flag=`"$Flag`" value=`"$Value`" />"
}

if (Test-Path -LiteralPath $variantRoot) {
    Remove-Item -LiteralPath $variantRoot -Recurse -Force
}
[void](New-Item -ItemType Directory -Path $variantRoot)

$base = [IO.File]::ReadAllText($basePath, [Text.Encoding]::UTF8)
$profiles = @(
    @{ Id = 'recommended'; Debug = 'off'; Observe = 'false' },
    @{ Id = 'observe'; Debug = 'off'; Observe = 'true' },
    @{ Id = 'diagnostic'; Debug = 'on'; Observe = 'true' }
)
$bits = @(0, 1)
$patterns = New-Object System.Collections.Generic.List[string]
$variantCount = 0

foreach ($profile in $profiles) {
    foreach ($enemy in $bits) { foreach ($loot in $bits) { foreach ($empty in $bits) {
        $markerSets = if ($profile.Id -eq 'diagnostic') { @(@{ Artifact = 0; Loot = 0; Enemy = 0 }) } else {
            $sets = @()
            foreach ($artifactMarker in $bits) { foreach ($lootMarker in $bits) { foreach ($enemyMarker in $bits) {
                $sets += @{ Artifact = $artifactMarker; Loot = $lootMarker; Enemy = $enemyMarker }
            } } }
            $sets
        }
        foreach ($markers in $markerSets) {
            $id = '{0}-z{1}{2}{3}-m{4}{5}{6}' -f $profile.Id, $enemy, $loot, $empty,
                $markers.Artifact, $markers.Loot, $markers.Enemy
            $config = $base
            $values = [ordered]@{
                debug_mode = $profile.Debug
                artifact_rescue_observe_only = $profile.Observe
                artifact_rescue_actions = 'false'
                enable_enemy_decoys = @('false','true')[$enemy]
                enable_loot_decoys = @('false','true')[$loot]
                enable_empty_decoys = @('false','true')[$empty]
                show_exact_artifact_markers = @('false','true')[$markers.Artifact]
                show_exact_loot_markers = @('false','true')[$markers.Loot]
                show_exact_enemy_markers = @('false','true')[$markers.Enemy]
                debug_force_decoy_type = 'off'
                debug_force_tier = '0'
                debug_cleanup_current_sortie = 'false'
                artifact_proactive_hold = 'true'
            }
            foreach ($entry in $values.GetEnumerator()) {
                $config = Set-ConfigValue $config $entry.Key $entry.Value
            }
            $config = (($config -split "`r?`n") | Where-Object { $_ -notmatch '^\s*;' }) -join "`r`n"
            $config = [regex]::Replace($config, "(`r`n){3,}", "`r`n`r`n").Trim() + "`r`n"
            $folder = Join-Path $variantRoot $id
            [void](New-Item -ItemType Directory -Path $folder)
            [IO.File]::WriteAllText((Join-Path $folder 'rvm_sorties_rework.ltx'), $config, $utf8)

            $dependencies = New-Object System.Collections.Generic.List[string]
            $dependencies.Add((Dependency 'Profile' $profile.Id))
            $dependencies.Add((Dependency 'EnemyZones' @('off','on')[$enemy]))
            $dependencies.Add((Dependency 'LootZones' @('off','on')[$loot]))
            $dependencies.Add((Dependency 'EmptyZones' @('off','on')[$empty]))
            if ($profile.Id -ne 'diagnostic') {
                $dependencies.Add((Dependency 'ArtifactMarker' @('off','on')[$markers.Artifact]))
                $dependencies.Add((Dependency 'LootMarker' @('off','on')[$markers.Loot]))
                $dependencies.Add((Dependency 'EnemyMarker' @('off','on')[$markers.Enemy]))
            }
            $patterns.Add(@"
            <pattern>
                <dependencies operator="And">
$($dependencies -join "`r`n")
                </dependencies>
                <files><file source="installer\variants\$id\rvm_sorties_rework.ltx" destination="gamedata\configs\plugins\rvm_sorties_rework.ltx" priority="100" /></files>
            </pattern>
"@)
            $variantCount++
        }
    } } }
}

$profilePlugins = @(
    (FlagPlugin 'Recommended' 'Public defaults: debug off, schema-9 protection and weighted pool on.' 'Profile' 'recommended' 'Recommended'),
    (FlagPlugin 'Observe-only' 'Debug remains off; legacy provenance is logged without relocation actions.' 'Profile' 'observe' 'Optional'),
    (FlagPlugin 'Diagnostic' 'Full technical debug, census and all exact markers. No forced spawns or legacy relocation.' 'Profile' 'diagnostic' 'Optional')
) -join "`r`n"

$xml = @"
<?xml version="1.0" encoding="utf-8"?>
<config xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://qconsulting.ca/fo3/ModConfig5.0.xsd">
    <moduleName>[&#1043;&#1077;&#1081;&#1084;&#1087;&#1083;&#1077;&#1081;] Anomaly Expedition Rework by White_Angel 0.3.0-rc1</moduleName>
    <requiredInstallFiles><folder source="gamedata" destination="gamedata" priority="0" /></requiredInstallFiles>
    <installSteps order="Explicit">
        <installStep name="Behavior profile">
            <optionalFileGroups order="Explicit"><group name="Choose one profile" type="SelectExactlyOne"><plugins order="Explicit">
$profilePlugins
            </plugins></group></optionalFileGroups>
        </installStep>
        <installStep name="Search-area types">
            <optionalFileGroups order="Explicit">
                <group name="Dangerous areas (enemy ambushes)" type="SelectExactlyOne"><plugins order="Explicit">
$(FlagPlugin 'Enabled' 'Allow dangerous false search areas with an owned mutant squad.' 'EnemyZones' 'on' 'Recommended')
$(FlagPlugin 'Disabled' 'Do not generate dangerous false search areas.' 'EnemyZones' 'off' 'Optional')
                </plugins></group>
                <group name="Valuable areas (loot caches)" type="SelectExactlyOne"><plugins order="Explicit">
$(FlagPlugin 'Enabled' 'Allow valuable false search areas with a loot container.' 'LootZones' 'on' 'Recommended')
$(FlagPlugin 'Disabled' 'Do not generate valuable false search areas.' 'LootZones' 'off' 'Optional')
                </plugins></group>
                <group name="Safe areas (empty decoys)" type="SelectExactlyOne"><plugins order="Explicit">
$(FlagPlugin 'Enabled' 'Allow safe empty false search areas.' 'EmptyZones' 'on' 'Recommended')
$(FlagPlugin 'Disabled' 'Do not generate safe empty false search areas.' 'EmptyZones' 'off' 'Optional')
                </plugins></group>
            </optionalFileGroups>
        </installStep>
        <installStep name="Optional exact markers">
            <visible><dependencies operator="Or"><flagDependency flag="Profile" value="recommended" /><flagDependency flag="Profile" value="observe" /></dependencies></visible>
            <optionalFileGroups order="Explicit">
                <group name="Exact artifact markers" type="SelectExactlyOne"><plugins order="Explicit">
$(FlagPlugin 'Hidden (default)' 'Show only approximate search circles.' 'ArtifactMarker' 'off' 'Recommended')
$(FlagPlugin 'Visible' 'Add a nontechnical exact marker for linked expedition artifacts.' 'ArtifactMarker' 'on' 'Optional')
                </plugins></group>
                <group name="Exact loot markers" type="SelectExactlyOne"><plugins order="Explicit">
$(FlagPlugin 'Hidden (default)' 'Show only approximate search circles.' 'LootMarker' 'off' 'Recommended')
$(FlagPlugin 'Visible' 'Add a nontechnical exact marker for expedition loot containers.' 'LootMarker' 'on' 'Optional')
                </plugins></group>
                <group name="Exact enemy markers" type="SelectExactlyOne"><plugins order="Explicit">
$(FlagPlugin 'Hidden (default)' 'Show only approximate search circles.' 'EnemyMarker' 'off' 'Recommended')
$(FlagPlugin 'Visible' 'Mark the current commander of an owned expedition squad.' 'EnemyMarker' 'on' 'Optional')
                </plugins></group>
            </optionalFileGroups>
        </installStep>
    </installSteps>
    <conditionalFileInstalls><patterns>
$($patterns -join "`r`n")
    </patterns></conditionalFileInstalls>
</config>
"@
[IO.File]::WriteAllText($modulePath, $xml.Trim() + "`r`n", $utf8)
Write-Output "Generated FOMOD: $variantCount complete LTX variants and ModuleConfig.xml"
