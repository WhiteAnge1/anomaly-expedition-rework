from __future__ import annotations

import argparse
import importlib
from pathlib import Path


def marked(source: str, begin: str, end: str) -> str:
    start = source.index(begin) + len(begin)
    finish = source.index(end, start)
    return source[start:finish]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Exercise the production origin-position normalizer in Lua 5.1/LuaJIT."
    )
    parser.add_argument("mod_root", type=Path)
    args = parser.parse_args()

    runtime_path = args.mod_root / "gamedata" / "scripts" / "zzz_rvm_sorties_rework.script"
    source = runtime_path.read_text(encoding="utf-8")
    normalizer = marked(
        source, "-- ORIGIN_POSITION_NORMALIZER_BEGIN", "-- ORIGIN_POSITION_NORMALIZER_END"
    )
    distance = marked(source, "-- ORIGIN_DISTANCE_XZ_BEGIN", "-- ORIGIN_DISTANCE_XZ_END")

    fixture = r'''
local function expect(ok, message)
    if not ok then error(message, 2) end
end
local function same(actual, expected, message)
    expect(actual == expected, message .. ": expected=" .. tostring(expected) .. " actual=" .. tostring(actual))
end
local function marshaled_position(x, y, z)
    -- Real RVM saves expose the persisted field center as userdata with the
    -- engine get(Y,M,D,h,m,s,ms) interface and no direct x/y/z fields.
    local value = newproxy(true)
    getmetatable(value).__index = {
        get = function(self, Y, M, D, h, m, s, ms)
            return x, y, z, 0, 0, 0, 0
        end,
    }
    return value
end

local real_saved = marshaled_position(-52.5, -13.9, -21.7)
local normalized, schema, reason = ORIGIN.normalize_position(real_saved)
same(schema, "marshal_get_xyz", "real save_state schema")
same(reason, nil, "real save_state reason")
same(normalized.x, -52.5, "real save_state x")
same(normalized.y, -13.9, "real save_state y")
same(normalized.z, -21.7, "real save_state z")

normalized, schema, reason = ORIGIN.normalize_position({ x = 1, y = 2, z = 3 })
same(schema, "keyed_xyz", "keyed schema")
same(normalized.z, 3, "keyed z")
normalized, schema, reason = ORIGIN.normalize_position({ 4, 5, 6 })
same(schema, "array_xyz", "array schema")
same(normalized.y, 5, "array y")

local malformed = {
    {},
    { x = 1, y = "2", z = 3 },
    { x = 1, [2] = 2, z = 3 },
    { 1, false, 3 },
    { get = function() return 1, "2", 3 end },
    { get = function() error("fixture") end },
}
for index = 1, #malformed do
    normalized, schema, reason = ORIGIN.normalize_position(malformed[index])
    expect(normalized == nil and reason ~= nil, "malformed fixture accepted at " .. tostring(index))
end
normalized, schema, reason = ORIGIN.normalize_position(nil)
same(normalized, nil, "missing normalized")
same(reason, "missing", "missing reason")

local electr = { artefact_id = 6910, pos = marshaled_position(-18.25, 1.5, 42.75), size_zone = 45, anom_zone = "electr_1_1" }
local chem = { artefact_id = 6930, pos = marshaled_position(9.5, -2.25, 31.125), size_zone = 55, anom_zone = "chem_2_1" }
for _, field in ipairs({ electr, chem }) do
    normalized, schema, reason = ORIGIN.normalize_position(field.pos)
    same(schema, "marshal_get_xyz", field.anom_zone .. " schema")
    expect(normalized and reason == nil, field.anom_zone .. " normalization")
    local measured, distance_error = distance_xz(normalized, normalized)
    same(measured, 0, field.anom_zone .. " distance")
    same(distance_error, nil, field.anom_zone .. " distance reason")
end

local sentinel, distance_error = distance_xz({ x = 1, y = 2 }, { x = 1, y = 2, z = 3 })
same(sentinel, 999999, "malformed distance sentinel")
expect(type(distance_error) == "string", "malformed distance lacks named reason")
'''

    chunk = "local ORIGIN = {}\n" + normalizer + "\n" + distance + "\n" + fixture
    variants = ("lua51", "luajit20", "luajit21")
    for variant in variants:
        module = importlib.import_module(f"lupa.{variant}")
        lua = module.LuaRuntime(unpack_returned_tuples=True)
        lua.execute(chunk)

    print("Origin position normalization: OK (real marshal/get, keyed, array, malformed, electr, chem; " + ", ".join(variants) + ")")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
