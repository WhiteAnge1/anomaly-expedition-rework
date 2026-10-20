from __future__ import annotations

import argparse
import importlib
import re
from pathlib import Path


FIXTURE = r'''
local module_env = {}
setmetatable(module_env, { __index = _G })
local chunk, load_error = loadstring(SOURCE, "@rvm_sorties_artifact_pool.script")
assert(chunk, load_error)
setfenv(chunk, module_env)
chunk()

local quality_group = { junk = 1, low = 5, medium = 6, high = 7, unique = 8 }
local canonical = ACTUAL_CANONICAL or {}
for index = 1, 8 do
    if not canonical[index] then canonical[index] = { artefacts = {} } end
end
local total = 0
local cells = 0
for _, family in ipairs({ "gravi", "electro", "chem", "thermo" }) do
    for _, quality in ipairs({ "junk", "low", "medium", "high", "unique" }) do
        local pool = module_env.POOLS[family][quality]
        assert(type(pool) == "table" and #pool > 0)
        cells = cells + 1
        if ACTUAL_CELLS then
            local expected = ACTUAL_CELLS[family][quality]
            assert(#pool == #expected, "actual cell count mismatch " .. family .. ":" .. quality
                .. " module=" .. tostring(#pool) .. " actual=" .. tostring(#expected))
            local expected_set = {}
            for _, section in ipairs(expected) do expected_set[section] = true end
            for _, section in ipairs(pool) do assert(expected_set[section], "actual family mismatch " .. section) end
        end
        for _, section in ipairs(pool) do
            if not ACTUAL_CANONICAL then
                local target = canonical[quality_group[quality]].artefacts
                target[#target + 1] = section
            end
            total = total + 1
        end
    end
end
assert(cells == 20 and total == 223)
assert(module_env.validate_pools(canonical, function(_) return true end))

local production = {
    [1] = { junk = 45, low = 45, medium = 10, high = 0, unique = 0 },
    [2] = { junk = 10, low = 32, medium = 43, high = 15, unique = 0 },
    [3] = { junk = 2, low = 8, medium = 43, high = 45, unique = 2 },
}
assert(module_env.validate_weights(production))

local stock_pool = {
    gravi = { [1] = { "stock_g" }, [2] = { "stock_g" }, [3] = { "stock_g" } },
    mosquito = { [1] = { "stock_m" }, [2] = { "stock_m" }, [3] = { "stock_m" } },
    electr = { [1] = { "stock_e" }, [2] = { "stock_e" }, [3] = { "stock_e" } },
    psy = { [1] = { "stock_p" }, [2] = { "stock_p" }, [3] = { "stock_p" } },
    chem = { [1] = { "stock_c" }, [2] = { "stock_c" }, [3] = { "stock_c" } },
    fuzz = { [1] = { "stock_f" }, [2] = { "stock_f" }, [3] = { "stock_f" } },
    therm = { [1] = { "stock_t" }, [2] = { "stock_t" }, [3] = { "stock_t" } },
}
local function make_stock_spawn(pool)
    local raid_groups_artifacts = pool
    return function(zone, tier)
        local prefix = string.match(zone, "^([^_]+)")
        return raid_groups_artifacts[prefix][tier][1]
    end
end
local stock_spawn = make_stock_spawn(stock_pool)
local found_stock_pool, found_stock_error = module_env.find_stock_pool(stock_spawn)
assert(found_stock_pool == stock_pool, tostring(found_stock_error))

local config = {
    get_string = function(_, _, default) return "weighted" or default end,
    get_number = function(_, key, default)
        local tier, quality = string.match(key, "tier_(%d)_weight_(.+)")
        return production[tonumber(tier)][quality] or default
    end,
}
local context = module_env.create_context(stock_spawn, canonical, function(_) return true end, config)
assert(context.enabled and context.stock_pool == stock_pool)

local function sequence(...)
    local values = { ... }
    local index = 0
    return function(low, high)
        index = index + 1
        local value = values[index]
        assert(value and value >= low and value <= high)
        return value
    end
end
local boundaries = {
    { 1, 1, "junk" }, { 1, 45, "junk" }, { 1, 46, "low" }, { 1, 90, "low" },
    { 1, 91, "medium" }, { 1, 100, "medium" },
    { 2, 10, "junk" }, { 2, 11, "low" }, { 2, 42, "low" }, { 2, 43, "medium" },
    { 2, 85, "medium" }, { 2, 86, "high" }, { 2, 100, "high" },
    { 3, 2, "junk" }, { 3, 3, "low" }, { 3, 10, "low" }, { 3, 11, "medium" },
    { 3, 53, "medium" }, { 3, 54, "high" }, { 3, 98, "high" }, { 3, 99, "unique" },
    { 3, 100, "unique" },
}
for _, item in ipairs(boundaries) do
    local choice = assert(module_env.choose(context, "gravi_1", item[1], sequence(item[2], 1)))
    assert(choice.quality == item[3])
end

-- Aliases preserve the stock family while mapping to the canonical family.
assert(assert(module_env.choose(context, "mosquito_1", 1, sequence(1, 1))).family == "gravi")
assert(assert(module_env.choose(context, "psy_1", 2, sequence(50, 1))).family == "electro")
assert(assert(module_env.choose(context, "fuzz_1", 3, sequence(50, 1))).family == "chem")
assert(assert(module_env.choose(context, "therm_1", 3, sequence(50, 1))).family == "thermo")

-- Independent rolls deliberately permit duplicate sections.
local duplicate_a = assert(module_env.choose(context, "chem_1", 2, sequence(50, 1)))
local duplicate_b = assert(module_env.choose(context, "chem_1", 2, sequence(50, 1)))
assert(duplicate_a.section == duplicate_b.section)

-- Temporary local-table override is visible only during the call and restores
-- even when the callback throws.
local selected = assert(module_env.choose(context, "gravi_1", 3, sequence(99, 1)))
local original = stock_pool.gravi[3]
local ok, value, _, restored, restore_error, fallback = module_env.call_with_override(
    context, selected, stock_spawn, "gravi_1", 3)
assert(ok and value == selected.section and restored and restore_error == nil and fallback == nil,
    "override ok=" .. tostring(ok) .. " value=" .. tostring(value) .. " expected=" .. tostring(selected.section)
    .. " restored=" .. tostring(restored) .. " restore_error=" .. tostring(restore_error)
    .. " fallback=" .. tostring(fallback))
assert(stock_pool.gravi[3] == original)
ok, value, _, restored = module_env.call_with_override(context, selected,
    function() error("fixture_failure") end)
assert(not ok and string.find(tostring(value), "fixture_failure", 1, true) and restored)
assert(stock_pool.gravi[3] == original and not context.active)

-- Invalid configuration fails closed and invokes the untouched stock selector.
local bad_config = {
    get_string = config.get_string,
    get_number = function(_, key, default)
        if key == "tier_2_weight_high" then return 14 end
        return config.get_number(_, key, default)
    end,
}
local bad_context = module_env.create_context(stock_spawn, canonical, function(_) return true end, bad_config)
assert(not bad_context.enabled and string.find(bad_context.reason, "weight_sum:2", 1, true))
ok, value, _, restored, restore_error, fallback = module_env.call_with_override(
    bad_context, nil, stock_spawn, "gravi_1", 1)
assert(ok and value == "stock_g" and restored and restore_error == nil and fallback == bad_context.reason)

-- All 14 unique sections are reachable through T3 family cells; production T1
-- and T2 never select unique, regardless of the section roll.
local unique_seen = {}
local unique_total = 0
local family_zone = { gravi = "gravi_1", electro = "electr_1", chem = "chem_1", thermo = "therm_1" }
for _, family in ipairs({ "gravi", "electro", "chem", "thermo" }) do
    local pool = module_env.POOLS[family].unique
    for section_index = 1, #pool do
        local choice = assert(module_env.choose(context, family_zone[family], 3, sequence(99, section_index)))
        assert(choice.quality == "unique" and choice.section == pool[section_index])
        unique_seen[choice.section] = true
        unique_total = unique_total + 1
    end
end
assert(unique_total == 14 and unique_seen.af_oasis_heart)
for tier = 1, 2 do
    for roll = 1, 100 do
        local choice = assert(module_env.choose(context, "chem_1", tier, sequence(roll, 1)))
        assert(choice.quality ~= "unique")
        if tier == 1 then assert(choice.quality ~= "high") end
    end
end

-- Deterministic distribution simulation checks the configured quality weights.
math.randomseed(782347)
for tier = 1, 3 do
    local counts = { junk = 0, low = 0, medium = 0, high = 0, unique = 0 }
    local samples = 100000
    for _ = 1, samples do
        local choice = assert(module_env.choose(context, "electr_1", tier, math.random))
        counts[choice.quality] = counts[choice.quality] + 1
    end
    for quality, expected in pairs(production[tier]) do
        local actual = counts[quality] * 100 / samples
        assert(math.abs(actual - expected) < 0.6,
            "distribution " .. tier .. ":" .. quality .. " actual=" .. actual .. " expected=" .. expected)
    end
end
'''


def main() -> int:
    parser = argparse.ArgumentParser(description="Test the weighted artifact family/quality selector.")
    parser.add_argument("mod_root", type=Path)
    parser.add_argument("build_mods_root", nargs="?", type=Path)
    args = parser.parse_args()
    source = (args.mod_root / "gamedata" / "scripts" / "rvm_sorties_artifact_pool.script").read_text(
        encoding="utf-8"
    )
    for variant in ("lua51", "luajit20", "luajit21"):
        module = importlib.import_module(f"lupa.{variant}")
        lua = module.LuaRuntime(unpack_returned_tuples=True)
        lua.globals()["SOURCE"] = source
        if args.build_mods_root:
            rojok_candidates = list(args.build_mods_root.rglob("raid_artefacts.script"))
            rojok_path = next(
                path for path in rojok_candidates if "raid_artefacts_tiers_by_dop" in path.read_text(encoding="utf-8", errors="ignore")
            )
            rojok_text = rojok_path.read_text(encoding="utf-8", errors="ignore")
            canonical: dict[int, dict[str, list[str]]] = {}
            for group_id in range(1, 9):
                match = re.search(
                    rf"\[{group_id}\]\s*=\s*\{{\s*artefacts\s*=\s*\{{(.*?)\}}",
                    rojok_text,
                    re.S,
                )
                if not match:
                    raise RuntimeError(f"canonical group {group_id} missing in {rojok_path}")
                canonical[group_id] = {"artefacts": re.findall(r'"([^"]+)"', match.group(1))}

            deanons_candidates = list(args.build_mods_root.rglob("artefacts.ltx"))
            deanons_path = next(
                path for path in deanons_candidates
                if "Deanons_Artefact_Pack" in str(path)
                and "[af_class_gravi_junk_1]" in path.read_text(encoding="utf-8", errors="ignore")
            )
            deanons_text = deanons_path.read_text(encoding="utf-8", errors="ignore")
            cells: dict[str, dict[str, list[str]]] = {}
            for family in ("gravi", "electro", "chem", "thermo"):
                cells[family] = {}
                section_names = {
                    "junk": [f"af_class_{family}_junk_{index}" for index in range(1, 5)],
                    "low": [f"af_class_{family}_1"],
                    "medium": [f"af_class_{family}_2"],
                    "high": [f"af_class_{family}_3"],
                    "unique": [f"af_class_{family}_4"],
                }
                for quality, names in section_names.items():
                    values: list[str] = []
                    for name in names:
                        match = re.search(rf"(?ms)^\[{re.escape(name)}\]\s*(.*?)(?=^\[|\Z)", deanons_text)
                        if not match:
                            raise RuntimeError(f"family section {name} missing in {deanons_path}")
                        values.extend(
                            line.strip()
                            for line in match.group(1).splitlines()
                            if line.strip() and not line.lstrip().startswith(";")
                        )
                    cells[family][quality] = values
            def one_based(value):
                if isinstance(value, list):
                    return {index + 1: one_based(item) for index, item in enumerate(value)}
                if isinstance(value, dict):
                    return {key: one_based(item) for key, item in value.items()}
                return value

            lua.globals()["ACTUAL_CANONICAL"] = lua.table_from(one_based(canonical), recursive=True)
            lua.globals()["ACTUAL_CELLS"] = lua.table_from(one_based(cells), recursive=True)
        lua.execute(FIXTURE)
    print("Artifact family x quality pool: OK (223 sections, 20 cells, boundaries, fallback, distribution; lua51, luajit20, luajit21)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
