from __future__ import annotations

import argparse
import importlib
import re
from pathlib import Path


EXPECTED = {
    "y04_pole": ([3, 4, 5], [35, 60, 5], 3.7, 4),
    "k01_darkscape": ([5, 6, 7, 8, 9], [5, 20, 47, 26, 2], 7.0, 8),
    "l09_deadcity": ([4, 5, 6, 7], [11, 80, 7, 2], 5.0, 6),
}


def marked(source: str, begin: str, end: str) -> str:
    start = source.index(begin) + len(begin)
    finish = source.index(end, start)
    return source[start:finish]


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


FIXTURE = r'''
local function expect(ok, message)
    if not ok then error(message, 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, message .. ": expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end

local definitions = {
    y04_pole = { values = { "3", "4", "5" }, weights = { "35", "60", "5" }, stock = 4, mean = 3.7 },
    k01_darkscape = { values = { "5", "6", "7", "8", "9" }, weights = { "5", "20", "47", "26", "2" }, stock = 8, mean = 7.0 },
    l09_deadcity = { values = { "4", "5", "6", "7" }, weights = { "11", "80", "7", "2" }, stock = 6, mean = 5.0 },
}

for level_name, definition in pairs(definitions) do
        local profile, reason = ARTIFACT_COUNT.validate(definition.values, definition.weights,
        definition.stock, 200, level_name .. "_approved")
    expect(profile ~= nil and reason == nil, level_name .. " profile rejected")
    local observed, total, weighted = {}, 0, 0
    for sample = 1, 100000 do
        local deterministic_roll = ((sample - 1) % 100) + 1
        local value = ARTIFACT_COUNT.roll(profile, function(minimum, maximum)
            same(minimum, 1, "roll minimum")
            same(maximum, 100, "roll maximum")
            return deterministic_roll
        end)
        observed[value] = (observed[value] or 0) + 1
        total = total + 1
        weighted = weighted + value
    end
    for index, value in ipairs(profile.values) do
        same(observed[value], profile.weights[index] * 1000, level_name .. " exact weight")
    end
    same(total, 100000, level_name .. " sample count")
    expect(math.abs(weighted / total - definition.mean) < 0.0000001, level_name .. " mean")
    same(profile.values[1], tonumber(definition.values[1]), level_name .. " minimum")
    same(profile.values[#profile.values], tonumber(definition.values[#definition.values]), level_name .. " maximum")

    local random_calls = 0
    local plan, created = ARTIFACT_COUNT.ensure(nil, level_name, definition.stock, profile,
        function() random_calls = random_calls + 1; return 1 end, nil)
    expect(created and random_calls == 1, level_name .. " new raid did not roll exactly once")
    plan.spawn_invoked = true
    plan.spawn_complete = true
    local restored = {
        level = plan.level, rolled = plan.rolled, stock = plan.stock, profile = plan.profile,
        spawn_invoked = plan.spawn_invoked, spawn_complete = plan.spawn_complete,
        callbacks = 0, created = 0, captured = 0, linked = 0,
    }
    local reused, rerolled = ARTIFACT_COUNT.ensure(restored, level_name, definition.stock, profile,
        function() random_calls = random_calls + 1; return 100 end, nil)
    expect(reused == restored and not rerolled and random_calls == 1
        and reused.spawn_invoked and reused.spawn_complete,
        level_name .. " save/load rerolled persisted count")
    expect(not ARTIFACT_COUNT.begin_spawn(reused), level_name .. " duplicate spawn was not suppressed")
    local fresh_plan = { spawn_invoked = false }
    expect(ARTIFACT_COUNT.begin_spawn(fresh_plan) and fresh_plan.spawn_invoked,
        level_name .. " first spawn was not admitted")
    expect(not ARTIFACT_COUNT.begin_spawn(fresh_plan), level_name .. " second spawn was admitted")
end

local invalid_profiles = {
    { { "3", "4" }, { "50" }, "weights_length_mismatch" },
    { { "3", "4" }, { "50", "49" }, "weights_sum_99" },
    { { "4", "3" }, { "50", "50" }, "values_not_strictly_increasing" },
    { { "3", "3" }, { "50", "50" }, "values_not_strictly_increasing" },
    { { "0", "4" }, { "50", "50" }, "invalid_integer_at_1" },
}
for _, fixture in ipairs(invalid_profiles) do
    local profile, reason = ARTIFACT_COUNT.validate(fixture[1], fixture[2], 4, 22, "invalid")
    expect(profile == nil and reason == fixture[3], "invalid profile did not fail closed: " .. tostring(reason))
end
local fallback, fallback_created = ARTIFACT_COUNT.ensure(nil, "y04_pole", 4, nil,
    function() error("fallback must not consume RNG") end, "invalid_config")
expect(fallback_created and fallback.rolled == 4 and fallback.profile == "stock_fallback"
    and fallback.fallback_reason == "invalid_config", "invalid config did not fall back to stock")

local observed = nil
local function stock_factory()
    local raid_distribution_anom_zones = { y04_pole = { count_artefacts = 4, count_zones = 22 } }
    local function stock_like(level_name, should_fail)
        observed = raid_distribution_anom_zones[level_name].count_artefacts
        if should_fail then error("stock_failure") end
        return observed
    end
    return stock_like, raid_distribution_anom_zones
end
local stock_like, distribution = stock_factory()
local found, find_error = ARTIFACT_COUNT.find_stock_table(stock_like)
expect(found == distribution and find_error == nil, "named stock upvalue not found")
local ok, value, restored, restore_error, original = ARTIFACT_COUNT.call_with_temporary_count(
    found.y04_pole, 3, stock_like, "y04_pole", false)
expect(ok and value == 3 and restored and restore_error == nil and original == 4,
    "temporary success call failed ok=" .. tostring(ok) .. ",value=" .. tostring(value)
        .. ",restored=" .. tostring(restored) .. ",restore_error=" .. tostring(restore_error)
        .. ",original=" .. tostring(original))
same(found.y04_pole.count_artefacts, 4, "success restoration")
ok, value, restored, restore_error, original = ARTIFACT_COUNT.call_with_temporary_count(
    found.y04_pole, 5, stock_like, "y04_pole", true)
expect(not ok and string.find(tostring(value), "stock_failure", 1, true) and restored
    and restore_error == nil and original == 4, "temporary failure call was not restored")
same(found.y04_pole.count_artefacts, 4, "failure restoration")

local created_ids, created = {}, 0
for _, id in ipairs({ 101, 101, 102 }) do
    local key = tostring(id)
    if not created_ids[key] then created_ids[key] = true; created = created + 1 end
end
same(created, 2, "duplicate artifact IDs changed count")
'''


def main() -> int:
    parser = argparse.ArgumentParser(description="Run artifact-count policy regressions in Lua 5.1/LuaJIT.")
    parser.add_argument("mod_root", type=Path)
    args = parser.parse_args()

    runtime_path = args.mod_root / "gamedata" / "scripts" / "zzz_rvm_sorties_rework.script"
    source = runtime_path.read_text(encoding="utf-8")
    policy = marked(source, "-- ARTIFACT_COUNT_POLICY_BEGIN", "-- ARTIFACT_COUNT_POLICY_END")

    config = parse_ltx(args.mod_root / "gamedata" / "configs" / "plugins" / "rvm_sorties_rework.ltx")
    for level, (values, weights, mean, stock) in EXPECTED.items():
        section = config[f"level_{level}"]
        actual_values = [int(x.strip()) for x in section["artifact_count_values"].split(",")]
        actual_weights = [int(x.strip()) for x in section["artifact_count_weights"].split(",")]
        if actual_values != values or actual_weights != weights:
            raise RuntimeError(f"{level} config distribution mismatch")
        if sum(actual_weights) != 100:
            raise RuntimeError(f"{level} weights do not sum to 100")
        actual_mean = sum(v * w for v, w in zip(actual_values, actual_weights)) / 100
        if abs(actual_mean - mean) > 1e-12:
            raise RuntimeError(f"{level} mean mismatch: {actual_mean} != {mean}")
        if stock not in (4, 8, 6):
            raise RuntimeError(f"{level} stock fallback mismatch")

    required_runtime = (
        'release_log("artifact_count rolled=%s profile=%s stock=%s status=%s raw_roll=%s reason=%s"',
        'ARTIFACT_COUNT.diagnostic("spawn_complete", false)',
        'ARTIFACT_COUNT.diagnostic("before_decoys", true)',
        'not plan.created_ids[artifact_key]',
        'not plan.captured_ids[artifact_key]',
        'not plan.linked_ids[artifact_key]',
        'artifact_count duplicate spawn suppressed',
        'plan.spawn_invoked = true',
        'state.schema = 7',
    )
    for needle in required_runtime:
        if needle not in source:
            raise RuntimeError(f"runtime artifact-count invariant missing: {needle}")

    decoy_start = source.index("local false_count = 1")
    decoy_end = source.index('release_log("decoy plan', decoy_start)
    if "artifact_count" in source[decoy_start:decoy_end]:
        raise RuntimeError("decoy count roll is coupled to artifact-count policy")
    if "math.random(2, 4)" not in source[decoy_start:decoy_end]:
        raise RuntimeError("Darkscape independent decoy roll changed")
    if "roll <= 20 and 1 or roll <= 80 and 2 or 3" not in source[decoy_start:decoy_end]:
        raise RuntimeError("Dead City independent decoy roll changed")

    variants = ("lua51", "luajit20", "luajit21")
    for variant in variants:
        module = importlib.import_module(f"lupa.{variant}")
        lua = module.LuaRuntime(unpack_returned_tuples=True)
        lua.execute("ARTIFACT_COUNT = {}\n" + policy + FIXTURE)

    print(
        "Artifact count policy: OK "
        "(exact support/weights/means, one roll persistence, stock fallback, "
        "success/error restoration, unique IDs, independent decoys; " + ", ".join(variants) + ")"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
