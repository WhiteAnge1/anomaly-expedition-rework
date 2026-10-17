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
        description="Exercise production origin registry evidence in Lua 5.1/LuaJIT."
    )
    parser.add_argument("mod_root", type=Path)
    args = parser.parse_args()

    runtime_path = args.mod_root / "gamedata" / "scripts" / "zzz_rvm_sorties_rework.script"
    source = runtime_path.read_text(encoding="utf-8")
    normalizer = marked(
        source, "-- ORIGIN_POSITION_NORMALIZER_BEGIN", "-- ORIGIN_POSITION_NORMALIZER_END"
    )
    distance = marked(source, "-- ORIGIN_DISTANCE_XZ_BEGIN", "-- ORIGIN_DISTANCE_XZ_END")
    registry_match = marked(
        source, "-- ORIGIN_REGISTRY_MATCH_BEGIN", "-- ORIGIN_REGISTRY_MATCH_END"
    )
    registry_evidence = marked(
        source, "-- ORIGIN_REGISTRY_EVIDENCE_BEGIN", "-- ORIGIN_REGISTRY_EVIDENCE_END"
    )
    secondary_guard = marked(
        source, "-- ORIGIN_SECONDARY_RESCUE_GUARD_BEGIN", "-- ORIGIN_SECONDARY_RESCUE_GUARD_END"
    )

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

local real_saved = marshaled_position(0, 0, 0)
local normalized, schema, reason = ORIGIN.normalize_position(real_saved)
same(schema, "marshal_get_xyz", "real save_state schema")
same(reason, nil, "real save_state reason")
same(normalized.x, 0, "real save_state x")
same(normalized.y, 0, "real save_state y")
same(normalized.z, 0, "real save_state z")

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

local electr = { artefact_id = 6910, pos = marshaled_position(0, 0, 0), size_zone = 10, anom_zone = "electr_1_1" }
local chem = { artefact_id = 6930, pos = marshaled_position(0, 0, 0), size_zone = 16, anom_zone = "chem_2_1" }
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

-- Exact legacy records decoded from named save 1.scoc. RVM's persisted center
-- is lost to (0,0,0), but the unique artifact registry key equals the old
-- independently captured target LVID for both electr and chem.
local legacy_cases = {
    {
        id = 6910, lvid = 4294, zone = "electr_1_1", size = 10,
        spawn = { x = -170, y = 0, z = -63 }, current = { x = -52.5, y = -13.9, z = -21.7 },
    },
    {
        id = 6930, lvid = 49164, zone = "chem_2_1", size = 16,
        spawn = { x = -44, y = 0, z = 60 }, current = { x = -0.3, y = 0.6, z = -0.2 },
    },
}
for _, saved in ipairs(legacy_cases) do
    local record = {
        artifact_id = saved.id, level = "y04_pole", anom_zone = saved.zone,
        zone_size = saved.size, spawn_input_pos = saved.spawn,
        first_server = { gvid = 5326 }, causal_origin = "origin_mismatch",
        primary_reason = "origin_mismatch", origin = { proof_pending = true },
        legacy_origin_registry = { field_lvid = saved.lvid, gvid = 5326 },
    }
    local registry = {
        [saved.lvid] = {
            artefact_id = saved.id, anom_zone = saved.zone, size_zone = saved.size,
            pos = marshaled_position(0, 0, 0),
        },
    }
    local lvid, field, match_error = ORIGIN.registry_match(record, registry)
    same(match_error, nil, saved.zone .. " match error")
    same(lvid, saved.lvid, saved.zone .. " exact registry lvid")
    normalized, schema, reason = ORIGIN.normalize_position(field.pos)
    local proof, proven_pos, evidence_error = ORIGIN.registry_evidence(
        record, lvid, field, normalized, schema, "y04_pole")
    same(evidence_error, nil, saved.zone .. " evidence error")
    same(proof, "legacy_exact_registry_lvid", saved.zone .. " legacy proof")
    same(proven_pos.x, saved.spawn.x, saved.zone .. " proven center")
    expect(ORIGIN.secondary_rescue_blocked(record), saved.zone .. " origin fell through to rolling")
end

local new_record = {
    artifact_id = 8001, level = "y04_pole", anom_zone = "therm_2_1", zone_size = 16,
    spawn_input_pos = { x = 11, y = 0, z = 22 },
    rvm_field = { lvid = 1234, anom_zone = "therm_2_1", size = 16, pos = { x = 11, y = 0, z = 22 } },
}
local new_field = { artefact_id = 8001, anom_zone = "therm_2_1", size_zone = 16, pos = marshaled_position(0, 0, 0) }
local proof, proven_pos, evidence_error = ORIGIN.registry_evidence(
    new_record, 1234, new_field, { x = 0, y = 0, z = 0 }, "marshal_get_xyz", "y04_pole")
same(evidence_error, nil, "new schema evidence error")
same(proof, "saved_exact_registry", "new schema proof")
same(proven_pos.z, 22, "new schema saved center")

local direct_record = {
    artifact_id = 8002, level = "y04_pole", anom_zone = "gravi_1", zone_size = 10,
    spawn_input_pos = { x = 5, y = 0, z = 7 },
}
local direct_field = { artefact_id = 8002, anom_zone = "gravi_1", size_zone = 10, pos = { x = 5, y = 0, z = 7 } }
proof, proven_pos, evidence_error = ORIGIN.registry_evidence(
    direct_record, 1235, direct_field, direct_field.pos, "keyed_xyz", "y04_pole")
same(proof, "live_registry_center", "live schema proof")

local ambiguous = {
    [100] = { artefact_id = 6910, pos = { x = 1, y = 0, z = 1 } },
    [101] = { artefact_id = 6910, pos = { x = 2, y = 0, z = 2 } },
}
local lvid, field, match_error = ORIGIN.registry_match({ artifact_id = 6910 }, ambiguous)
same(lvid, nil, "ambiguous lvid")
same(match_error, "rvm_field_match_count:2", "ambiguous reason")
lvid, field, match_error = ORIGIN.registry_match({ artifact_id = 9999 }, ambiguous)
same(match_error, "rvm_field_match_count:0", "missing reason")

local negative = {
    { field = { anom_zone = "chem_1_1", size_zone = 10 }, lvid = 4294, level = "y04_pole", reason = "rvm_field_template_mismatch:" },
    { field = { anom_zone = "electr_1_1", size_zone = 16 }, lvid = 4294, level = "y04_pole", reason = "rvm_field_size_mismatch:" },
    { field = { anom_zone = "electr_1_1", size_zone = 10 }, lvid = 4294, level = "l09_deadcity", reason = "rvm_field_level_mismatch:" },
    { field = { anom_zone = "electr_1_1", size_zone = 10 }, lvid = 4000, level = "y04_pole", reason = "rvm_field_legacy_lvid_mismatch:" },
}
local base_record = {
    artifact_id = 6910, level = "y04_pole", anom_zone = "electr_1_1", zone_size = 10,
    spawn_input_pos = { x = -170, y = 0, z = -63 }, first_server = { gvid = 5326 },
    legacy_origin_registry = { field_lvid = 4294, gvid = 5326 },
}
for index, item in ipairs(negative) do
    proof, proven_pos, evidence_error = ORIGIN.registry_evidence(
        base_record, item.lvid, item.field, { x = 0, y = 0, z = 0 }, "marshal_get_xyz", item.level)
    expect(proof == nil and string.find(evidence_error, item.reason, 1, true) == 1,
        "negative evidence accepted at " .. tostring(index) .. ": " .. tostring(evidence_error))
end
'''

    helpers = r'''
local INVALID_VERTEX_ID = 4294967295
local function valid_vertex_id(value)
    return type(value) == "number" and value >= 0 and value < INVALID_VERTEX_ID
end
local function pos_table(pos)
    local normalized = ORIGIN.normalize_position(pos)
    return normalized
end
local function fmt_number(value)
    value = tonumber(value) or 0
    return tostring(math.floor(value * 10 + 0.5) / 10)
end
'''
    chunk = (
        "local ORIGIN = {}\n"
        + normalizer
        + "\n"
        + distance
        + "\n"
        + helpers
        + "\n"
        + registry_match
        + "\n"
        + registry_evidence
        + "\n"
        + secondary_guard
        + "\n"
        + fixture
    )
    variants = ("lua51", "luajit20", "luajit21")
    for variant in variants:
        module = importlib.import_module(f"lupa.{variant}")
        lua = module.LuaRuntime(unpack_returned_tuples=True)
        lua.execute(chunk)

    print("Origin registry evidence: OK (save-1 #6910/#6930, new/live schema, ambiguous/mismatch negatives, manual displacement guard; " + ", ".join(variants) + ")")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
