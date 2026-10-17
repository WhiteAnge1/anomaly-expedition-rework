from __future__ import annotations

import argparse
import importlib
from pathlib import Path


FIXTURE = r'''
local engine_calls = { name = 0, custom = 0, vertex_id = 0, vertex_position = 0 }
local engine_level = {
    weather = "clear",
    name = function()
        engine_calls.name = engine_calls.name + 1
        return "y04_pole"
    end,
    custom_call = function(value)
        engine_calls.custom = engine_calls.custom + 1
        return value * 2
    end,
    vertex_id = function(candidate)
        engine_calls.vertex_id = engine_calls.vertex_id + 1
        return candidate.valid and 4294 or 4294967295
    end,
    vertex_position = function(lvid)
        engine_calls.vertex_position = engine_calls.vertex_position + 1
        return { x = lvid, y = 0, z = 1 }
    end,
}

local module_env = { level = engine_level }
setmetatable(module_env, { __index = _G })

local function stock_like_spawn(candidate, fail_after_reads)
    assert(level.name() == "y04_pole")
    assert(level.weather == "clear")
    assert(level.custom_call(4) == 8)
    if fail_after_reads then error("stock_fixture_failure") end
    local lvid = level.vertex_id(candidate)
    local pos = level.vertex_position(lvid)
    return pos and pos.x or nil
end
setfenv(stock_like_spawn, module_env)

local function wrapped(candidate, fail_after_reads)
    local rejection = nil
    local saved_level = module_env.level
    local level_proxy = {
        vertex_id = function(value)
            return engine_level.vertex_id(value)
        end,
        vertex_position = function(lvid)
            if lvid == 4294967295 then
                rejection = "invalid_second_vertex"
                return nil
            end
            return engine_level.vertex_position(lvid)
        end,
    }
    setmetatable(level_proxy, {
        __index = function(_, key)
            return engine_level[key]
        end,
    })
    module_env.level = level_proxy
    local ok, value = pcall(stock_like_spawn, candidate, fail_after_reads)
    module_env.level = saved_level
    return ok, value, rejection, module_env.level == engine_level
end

local ok, value, rejection, restored = wrapped({ valid = true }, false)
assert(ok and value == 4294 and rejection == nil and restored)
assert(engine_calls.name == 1 and engine_calls.custom == 1)
assert(engine_calls.vertex_id == 1 and engine_calls.vertex_position == 1)

ok, value, rejection, restored = wrapped({ valid = false }, false)
assert(ok and value == nil and rejection == "invalid_second_vertex" and restored)
assert(engine_calls.name == 2 and engine_calls.custom == 2)
assert(engine_calls.vertex_id == 2 and engine_calls.vertex_position == 1)

ok, value, rejection, restored = wrapped({ valid = true }, true)
assert(not ok and string.find(tostring(value), "stock_fixture_failure", 1, true) and restored)
assert(engine_calls.name == 3 and engine_calls.custom == 3)
assert(engine_calls.vertex_id == 2 and engine_calls.vertex_position == 1)
'''


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run the stock-like artifact spawn level-proxy regression."
    )
    parser.add_argument("mod_root", type=Path)
    args = parser.parse_args()

    runtime_source = (
        args.mod_root / "gamedata" / "scripts" / "zzz_rvm_sorties_rework.script"
    ).read_text(encoding="utf-8")
    for needle in (
        'type(engine_level.name) ~= "function"',
        "setmetatable(level_proxy, {",
        "return engine_level[key]",
        'rawset(raid_anomalys, "level", saved_level)',
    ):
        if needle not in runtime_source:
            raise RuntimeError(f"runtime level-proxy invariant missing: {needle}")

    variants = ("lua51", "luajit20", "luajit21")
    for variant in variants:
        module = importlib.import_module(f"lupa.{variant}")
        lua = module.LuaRuntime(unpack_returned_tuples=True)
        lua.execute(FIXTURE)

    print(
        "Artifact spawn level proxy: OK "
        "(stock name/value/call delegation, vertex interception, exception restoration; "
        + ", ".join(variants)
        + ")"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
