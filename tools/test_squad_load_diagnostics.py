from __future__ import annotations

import importlib
from pathlib import Path
import re
import sys


BEGIN = "-- SQUAD_LOAD_DIAGNOSTICS_BEGIN"
END = "-- SQUAD_LOAD_DIAGNOSTICS_END"


def diagnostics_block(source: str) -> str:
    start = source.index(BEGIN) + len(BEGIN)
    finish = source.index(END, start)
    return source[start:finish]


def assert_read_only(block: str) -> None:
    required = (
        "stage=%s", "session=%s", "sortie=%s", "anchor_id=%s", "squad_id=%s",
        "commander_id=%s", "member_id=%s", "server_pos=(%s)", "online_pos=(%s)",
        "server_lvid=%s", "server_gvid=%s", "online_lvid=%s", "online_gvid=%s",
        "actor_distance=%s", "anchor_distance=%s", "saved_server_delta=%s",
        "saved_online_delta=%s", "smart=%s", "target=%s", "same_id=%s",
        "created_this_session=%s", "owned_by_rework=true", "position_write=false",
        '"creation"', '"before_save"', '"load_restore"', '"load_first_update_0s"',
        '"load_followup_" .. tostring(seconds) .. "s"', "{ 5, 15, 30 }",
    )
    for needle in required:
        if needle not in block:
            raise AssertionError(f"squad diagnostic invariant missing: {needle}")

    forbidden = (
        "teleport_object", "force_set_position", "set_position", "alife_create",
        "create_npc", "alife_release", "safe_release", "release_enemy_squad",
    )
    lowered = block.lower()
    for needle in forbidden:
        if needle.lower() in lowered:
            raise AssertionError(f"squad diagnostic block contains gameplay mutation: {needle}")
    if re.search(r"(?:\.position|m_level_vertex_id|m_game_vertex_id)\s*=", block):
        raise AssertionError("squad diagnostic block writes a position or vertex")


FIXTURE_PREFIX = r'''
RVM_SORTIES_SQUAD_DIAGNOSTICS = {}
PREFIX = "[fixture]"
clock = 1000
logs = {}
server_member = { position = { x = 10, y = 1, z = 20 }, m_level_vertex_id = 101, m_game_vertex_id = 201 }
online_member = { position = { x = 10, y = 1, z = 20 } }
function online_member:level_vertex_id() return 101 end
function online_member:game_vertex_id() return 201 end
squad = { smart_terrain_id = 301, current_target_id = "smart_target_401" }
level = {
    name = function() return "k01_darkscape" end,
    object_by_id = function(id) if id == 7 then return online_member end return nil end,
}
db = { actor = { position = { x = 0, y = 1, z = 0 } } }
zone = {
    kind = "enemy", anchor_id = 11, squad_id = 99, triggered = true, closed = false,
    center = { x = 5, y = 1, z = 15 }, member_ids = { [7] = true },
}
state = {
    level_name = "k01_darkscape", sortie_type = "infected", zones = { ["11"] = zone },
}
function time_global() return clock end
function safe_alife_object(id)
    if id == 99 then return squad end
    if id == 7 then return server_member end
    return nil
end
function squad_commander_id(value) if value == squad then return 7 end return nil end
function safe_object_position(obj)
    if not obj or not obj.position then return nil end
    return { x = obj.position.x, y = obj.position.y, z = obj.position.z }
end
function safe_server_vertex(obj, field) return obj and obj[field] or nil end
function fmt_number(value) return string.format("%.3f", value) end
function fmt_position(pos)
    if not pos then return "none" end
    return fmt_number(pos.x) .. "," .. fmt_number(pos.y) .. "," .. fmt_number(pos.z)
end
function release_log(fmt, ...)
    logs[#logs + 1] = string.format(fmt, ...)
end
function printf(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end
'''


FIXTURE_SUFFIX = r'''
RVM_SORTIES_SQUAD_DIAGNOSTICS.created(zone, 1000)
RVM_SORTIES_SQUAD_DIAGNOSTICS.before_save(1100)
assert(zone.squad_diag_saved["7"].server_pos.x == 10)
server_member.position.x = 12
online_member.position.x = 12
RVM_SORTIES_SQUAD_DIAGNOSTICS.load_restore(1200)
RVM_SORTIES_SQUAD_DIAGNOSTICS.first_update(1300)
RVM_SORTIES_SQUAD_DIAGNOSTICS.update(6299)
RVM_SORTIES_SQUAD_DIAGNOSTICS.update(6300)
RVM_SORTIES_SQUAD_DIAGNOSTICS.update(16300)
RVM_SORTIES_SQUAD_DIAGNOSTICS.update(31300)
RVM_SORTIES_SQUAD_DIAGNOSTICS.update(50000)

expected = {
    creation = 1, before_save = 1, load_restore = 1, load_first_update_0s = 1,
    load_followup_5s = 1, load_followup_15s = 1, load_followup_30s = 1,
}
for stage, wanted in pairs(expected) do
    local found = 0
    for _, line in ipairs(logs) do
        if string.find(line, "stage=" .. stage, 1, true) then found = found + 1 end
    end
    assert(found == wanted, stage .. " count=" .. tostring(found))
end
local first = nil
for _, line in ipairs(logs) do
    if string.find(line, "stage=load_first_update_0s", 1, true) then first = line end
end
assert(first and string.find(first, "saved_server_delta=2.000", 1, true))
assert(string.find(first, "saved_online_delta=2.000", 1, true))
assert(string.find(first, "same_id=true", 1, true))
assert(string.find(first, "created_this_session=false", 1, true))
assert(string.find(first, "position_write=false", 1, true))
assert(string.find(first, "smart=301", 1, true))
assert(string.find(first, "target=smart_target_401", 1, true))
assert(server_member.position.x == 12 and online_member.position.x == 12)
'''


def execute_fixture(block: str, variant: str) -> None:
    module = importlib.import_module(f"lupa.{variant}")
    runtime = module.LuaRuntime(unpack_returned_tuples=True)
    runtime.execute(FIXTURE_PREFIX + block + FIXTURE_SUFFIX)


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    source = (root / "gamedata/scripts/zzz_rvm_sorties_rework.script").read_text(encoding="utf-8")
    block = diagnostics_block(source)
    assert_read_only(block)
    for needle in (
        "RVM_SORTIES_SQUAD_DIAGNOSTICS.created, zone, now",
        "RVM_SORTIES_SQUAD_DIAGNOSTICS.before_save, time_global()",
        "RVM_SORTIES_SQUAD_DIAGNOSTICS.load_restore, time_global()",
        "RVM_SORTIES_SQUAD_DIAGNOSTICS.first_update, time_global()",
        "RVM_SORTIES_SQUAD_DIAGNOSTICS.update, now",
    ):
        if source.count(needle) != 1:
            raise AssertionError(f"squad diagnostic lifecycle hook count mismatch: {needle}")
    for variant in ("lua51", "luajit20", "luajit21"):
        execute_fixture(block, variant)
    print("Squad load diagnostics: OK (read-only; Lua 5.1/LuaJIT timeline 0/5/15/30s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
