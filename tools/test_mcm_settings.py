from __future__ import annotations

import argparse
import importlib
from pathlib import Path


def parse_ltx(path: Path) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    section = ""
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split(";", 1)[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            result.setdefault(section, {})
        elif "=" in line and section:
            key, value = line.split("=", 1)
            result[section][key.strip()] = value.strip()
    return result


SCALARS = {
    ("global", "enabled"): "rvm_sorties_rework/general/enabled",
    ("global", "stash_mode"): "rvm_sorties_rework/general/stash_mode",
    ("global", "enable_enemy_decoys"): "rvm_sorties_rework/decoys/enable_enemy",
    ("global", "enable_loot_decoys"): "rvm_sorties_rework/decoys/enable_loot",
    ("global", "enable_empty_decoys"): "rvm_sorties_rework/decoys/enable_empty",
    ("global", "weight_enemy"): "rvm_sorties_rework/decoys/weight_enemy",
    ("global", "weight_loot"): "rvm_sorties_rework/decoys/weight_loot",
    ("global", "weight_empty"): "rvm_sorties_rework/decoys/weight_empty",
    ("global", "show_exact_artifact_markers"): "rvm_sorties_rework/markers/artifact",
    ("global", "show_exact_loot_markers"): "rvm_sorties_rework/markers/loot",
    ("global", "show_exact_enemy_markers"): "rvm_sorties_rework/markers/enemy",
    ("global", "remove_on_npc_pickup"): "rvm_sorties_rework/markers/remove_on_npc_pickup",
    ("global", "enable_location_artifact_counts"): "rvm_sorties_rework/artifact_counts/enabled",
    ("global", "enable_location_zone_counts"): "rvm_sorties_rework/zone_counts/enabled",
    ("global", "artifact_proactive_hold"): "rvm_sorties_rework/schema9/enabled",
    ("global", "artifact_proactive_clearance"): "rvm_sorties_rework/schema9/server_clearance",
    ("global", "artifact_online_hold_clearance"): "rvm_sorties_rework/schema9/online_clearance",
    ("global", "artifact_proactive_position_tolerance"): "rvm_sorties_rework/schema9/position_tolerance",
    ("global", "artifact_spawn_guard_attempts"): "rvm_sorties_rework/schema9/guard_attempts",
    ("global", "update_interval_ms"): "rvm_sorties_rework/advanced/update_interval_ms",
    ("artifact_pool", "profile"): "rvm_sorties_rework/artifact_pool/profile",
    ("level_k01_darkscape", "ambush_spawn_timing"): "rvm_sorties_rework/darkscape/spawn_timing",
}
for tier in range(1, 4):
    for quality in ("junk", "low", "medium", "high", "unique"):
        SCALARS[("artifact_pool", f"tier_{tier}_weight_{quality}")] = (
            f"rvm_sorties_rework/artifact_pool/tier{tier}_{quality}"
        )


def lua_list(table) -> list[str]:
    return [str(table[index]) for index in range(1, len(table) + 1)]


def run_variant(name: str, root: Path, ltx: dict[str, dict[str, str]]) -> None:
    module = importlib.import_module(f"lupa.{name}")
    lua = module.LuaRuntime(unpack_returned_tuples=True)
    globals_ = lua.globals()
    globals_.LTX = lua.table_from({section: lua.table_from(values) for section, values in ltx.items()})
    lua.execute(
        """
        function ini_file(path)
            local obj = {}
            function obj:section_exist(section) return LTX[section] ~= nil end
            function obj:line_exist(section, key) return LTX[section] ~= nil and LTX[section][key] ~= nil end
            function obj:r_string(section, key) return LTX[section][key] end
            return obj
        end
        """
    )
    lua.execute((root / "gamedata/scripts/rvm_sorties_mcm.script").read_text(encoding="utf-8"))
    lua.execute(
        """
        MCM_VALUES = {}
        local root = on_mcm_load()
        local function walk(node, prefix)
            local current = prefix == "" and node.id or (prefix .. "/" .. node.id)
            if node.gr then
                for _, child in ipairs(node.gr) do walk(child, current) end
            elseif node.val ~= nil then
                MCM_VALUES[current] = node.def
            end
        end
        walk(root, "")
        ui_mcm = {
            is_gathering = function() return false end,
            get = function(path) return MCM_VALUES[path] end,
        }
        """
    )
    lua.execute((root / "gamedata/scripts/rvm_sorties_config.script").read_text(encoding="utf-8"))

    for (section, key), path in SCALARS.items():
        expected = ltx[section][key]
        default = globals_.MCM_VALUES[path]
        if expected.lower() in ("true", "false"):
            actual = globals_.get_bool(section, key, not (expected.lower() == "true"))
            assert actual is (expected.lower() == "true"), (name, section, key, actual, expected)
            assert bool(default) == actual, (name, path, default, expected)
        elif key.startswith("tier_") or key in {
            "weight_enemy", "weight_loot", "weight_empty", "artifact_proactive_clearance",
            "artifact_online_hold_clearance", "artifact_proactive_position_tolerance",
            "artifact_spawn_guard_attempts", "update_interval_ms",
        }:
            actual = globals_.get_number(section, key, -999)
            assert abs(actual - float(expected)) < 1e-9, (name, section, key, actual, expected)
            assert abs(float(default) - float(expected)) < 1e-9, (name, path, default, expected)
        else:
            actual = globals_.get_string(section, key, "missing")
            assert actual == expected, (name, section, key, actual, expected)
            assert str(default) == expected, (name, path, default, expected)

    for level in ("y04_pole", "k01_darkscape", "l09_deadcity"):
        section = f"level_{level}"
        assert lua_list(globals_.get_list(section, "artifact_count_weights")) == ltx[section]["artifact_count_weights"].split(",")
        assert lua_list(globals_.get_list(section, "zone_count_weights")) == ltx[section]["zone_count_weights"].split(",")

    globals_.MCM_VALUES["rvm_sorties_rework/general/stash_mode"] = "disabled"
    globals_.MCM_VALUES["rvm_sorties_rework/darkscape/spawn_timing"] = "start"
    for quality in ("junk", "low", "medium", "high", "unique"):
        globals_.MCM_VALUES[f"rvm_sorties_rework/artifact_pool/tier2_{quality}"] = 10
    for count in (5, 6, 7, 8, 9):
        globals_.MCM_VALUES[f"rvm_sorties_rework/artifact_counts/darkscape_{count}"] = 1
    snapshot = globals_.build_snapshot("k01_darkscape")
    assert globals_.activate_snapshot(snapshot) is True
    globals_.MCM_VALUES["rvm_sorties_rework/general/stash_mode"] = "scouting"
    globals_.MCM_VALUES["rvm_sorties_rework/darkscape/spawn_timing"] = "proximity"
    assert globals_.get_string("global", "stash_mode", "missing") == "disabled"
    assert globals_.get_string("level_k01_darkscape", "ambush_spawn_timing", "missing") == "start"
    assert lua_list(globals_.get_list("level_k01_darkscape", "artifact_count_weights")) == ["20"] * 5
    for quality in ("junk", "low", "medium", "high", "unique"):
        assert globals_.get_number("artifact_pool", f"tier_2_weight_{quality}", -1) == 20

    globals_.clear_snapshot()
    for kind in ("enemy", "loot", "empty"):
        globals_.MCM_VALUES[f"rvm_sorties_rework/decoys/weight_{kind}"] = 0
    for quality in ("junk", "low", "medium", "high", "unique"):
        globals_.MCM_VALUES[f"rvm_sorties_rework/artifact_pool/tier2_{quality}"] = 0
    invalid_snapshot = globals_.build_snapshot("k01_darkscape")
    assert globals_.activate_snapshot(invalid_snapshot) is True
    assert globals_.get_number("global", "weight_enemy", -1) == float(ltx["global"]["weight_enemy"])
    assert globals_.get_number("artifact_pool", "tier_2_weight_medium", -1) == float(
        ltx["artifact_pool"]["tier_2_weight_medium"]
    )

    globals_.clear_snapshot()
    globals_.ui_mcm = None
    assert globals_.get_string("global", "stash_mode", "missing") == ltx["global"]["stash_mode"]
    assert lua_list(globals_.get_list("level_k01_darkscape", "artifact_count_weights")) == ltx["level_k01_darkscape"]["artifact_count_weights"].split(",")

    lua.execute('ui_mcm = { is_gathering=function() return false end, get=function() error("broken MCM") end }')
    assert globals_.get_number("global", "weight_enemy", -1) == float(ltx["global"]["weight_enemy"])


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate MCM API mapping, fallback and expedition snapshots.")
    parser.add_argument("mod_root", type=Path)
    args = parser.parse_args()
    root = args.mod_root
    ltx = parse_ltx(root / "gamedata/configs/plugins/rvm_sorties_rework.ltx")
    for variant in ("lua51", "luajit20", "luajit21"):
        run_variant(variant, root, ltx)
    print("MCM settings: OK (defaults parity, round-trip, normalization, broken/missing fallback, snapshot; lua51, luajit20, luajit21)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
