from __future__ import annotations

import importlib
from pathlib import Path
import re
import sys


BEGIN = "-- AMBUSH_ISOLATION_BEGIN"
END = "-- AMBUSH_ISOLATION_END"


def isolation_block(source: str) -> str:
    start = source.index(BEGIN) + len(BEGIN)
    finish = source.index(END, start)
    return source[start:finish]


def assert_policy(block: str, source: str) -> None:
    for needle in (
        'squad.scripted_target = self_target',
        'zone.squad_isolation_policy = "self_target"',
        'online_policy=unchanged position_write=false',
        'no target cleared and no position changed',
        'RVM_SORTIES_AMBUSH_ISOLATION.apply(zone, squad, reason .. "_migration", true)',
    ):
        if needle not in block:
            raise AssertionError(f"ambush isolation invariant missing: {needle}")

    forbidden = (
        "alife_create", "create_npc", "alife_release", "safe_release",
        "set_position", "teleport", "assign_squad_to_smart",
    )
    lowered = block.lower()
    for needle in forbidden:
        if needle in lowered:
            raise AssertionError(f"ambush isolation contains forbidden mutation: {needle}")
    for pattern in (
        r"(?:\.position|m_level_vertex_id|m_game_vertex_id)\s*=",
        r"(?:assigned_target_id|current_target_id|smart_id|__lock|force_online)\s*=",
    ):
        if re.search(pattern, block):
            raise AssertionError(f"ambush isolation contains forbidden assignment: {pattern}")

    for needle in (
        'RVM_SORTIES_AMBUSH_ISOLATION.apply(\n        temporary, squad, "creation", true)',
        'RVM_SORTIES_AMBUSH_ISOLATION.restore_all("load_state")',
        'RVM_SORTIES_AMBUSH_ISOLATION.restore_all("actor_first_update")',
        'RegisterScriptCallback("squad_on_first_update", RVM_SORTIES_AMBUSH_ISOLATION.squad_on_update)',
        'RegisterScriptCallback("squad_on_update", RVM_SORTIES_AMBUSH_ISOLATION.squad_on_update)',
        'release_enemy_squad(temporary, "isolation_rollback")',
    ):
        if source.count(needle) != 1:
            raise AssertionError(f"ambush isolation lifecycle mismatch: {needle}")

    # T1/T3 LTX start and T2 MCM start must converge before one shared creator;
    # there is no level-specific T2 immediate create/register lifecycle.
    if source.count("local function spawn_exact_squad(") != 1:
        raise AssertionError("expected exactly one shared exact squad creator")
    if source.count("spawn_exact_squad(zone, pos, lvid, stage.name)") != 1:
        raise AssertionError("all cascade modes must converge on the shared squad creator")
    for needle in (
        'if spawn_timing == "start" then',
        'timing_ready = spawn_timing == "start" or distance_xz',
        'trigger_ambush(zone, now, spawn_timing)',
    ):
        if needle not in source:
            raise AssertionError(f"shared start/proximity selector missing: {needle}")


FIXTURE_PREFIX = r'''
RVM_SORTIES_AMBUSH_ISOLATION = {}
PREFIX = "[fixture]"
logs = {}
squad = { id = 99 }
zone = {
    kind = "enemy", triggered = true, closed = false, squad_id = 99,
}
state = { zones = { ["11"] = zone } }
function safe_object_id_any(obj) return obj and obj.id or nil end
function safe_alife_object(id) if id == 99 then return squad end return nil end
function release_log(fmt, ...)
    logs[#logs + 1] = string.format(fmt, ...)
end
function printf(fmt, ...)
    logs[#logs + 1] = string.format(fmt, ...)
end
'''


FIXTURE_SUFFIX = r'''
local ok, status = RVM_SORTIES_AMBUSH_ISOLATION.apply(zone, squad, "creation", true)
assert(ok and status == "applied")
assert(squad.scripted_target == "99")
assert(zone.squad_isolation_policy == "self_target")
assert(squad.__lock == nil and squad.force_online == nil)
assert(squad.smart_id == nil and squad.assigned_target_id == nil and squad.current_target_id == nil)

-- The normal engine path sees a scripted squad target and therefore chooses
-- specific_update(self), whose self-target branch returns before generic_update.
local function get_script_target(value)
    local id = tonumber(value.scripted_target)
    return id == value.id and id or nil
end
local generic_calls = 0
local specific_calls = 0
local target = get_script_target(squad)
if target then
    specific_calls = specific_calls + 1
    assert(target == squad.id)
else
    generic_calls = generic_calls + 1
end
assert(specific_calls == 1 and generic_calls == 0)

-- Simulate a non-serialized/cleared runtime field after load. The owned policy
-- restores only the self target and leaves online policy and position alone.
squad.scripted_target = nil
ok, status = RVM_SORTIES_AMBUSH_ISOLATION.enforce(zone, squad, "load")
assert(ok and status == "applied" and squad.scripted_target == "99")
assert(squad.__lock == nil and squad.force_online == nil)

-- A migrated RC5 squad that already has a foreign smart/target is never
-- detached, cleared, teleported or returned to its old requested position.
zone.squad_isolation_policy = nil
squad.scripted_target = nil
squad.smart_id = 16913
squad.assigned_target_id = 16913
squad.current_target_id = 16913
ok, status = RVM_SORTIES_AMBUSH_ISOLATION.apply(zone, squad, "migration", true)
assert(not ok and string.find(status, "preassigned", 1, true))
assert(squad.scripted_target == nil)
assert(squad.smart_id == 16913 and squad.assigned_target_id == 16913 and squad.current_target_id == 16913)

-- Clean legacy squads can be migrated by the early squad callback even when
-- actor/load restoration has not resolved the server object yet.
squad.smart_id = nil
squad.assigned_target_id = nil
squad.current_target_id = nil
squad.scripted_target = nil
RVM_SORTIES_AMBUSH_ISOLATION.squad_on_update(squad)
assert(zone.squad_isolation_policy == "self_target" and squad.scripted_target == "99")

-- The load/actor restoration path enforces the same persisted policy.
squad.scripted_target = nil
RVM_SORTIES_AMBUSH_ISOLATION.restore_all("load_state")
assert(zone.squad_isolation_policy == "self_target" and squad.scripted_target == "99")

-- Callback enforcement is scoped to the active owned squad only.
squad.scripted_target = nil
RVM_SORTIES_AMBUSH_ISOLATION.squad_on_update(squad)
assert(squad.scripted_target == "99")
local foreign = { id = 100 }
RVM_SORTIES_AMBUSH_ISOLATION.squad_on_update(foreign)
assert(foreign.scripted_target == nil)
'''


def execute_fixture(block: str, variant: str) -> None:
    module = importlib.import_module(f"lupa.{variant}")
    runtime = module.LuaRuntime(unpack_returned_tuples=True)
    runtime.execute(FIXTURE_PREFIX + block + FIXTURE_SUFFIX)


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    source = (root / "gamedata/scripts/zzz_rvm_sorties_rework.script").read_text(encoding="utf-8")
    ltx = (root / "gamedata/configs/plugins/rvm_sorties_rework.ltx").read_text(encoding="utf-8-sig")
    for section, timing in (
        ("level_y04_pole", "start"),
        ("level_k01_darkscape", "proximity"),
        ("level_l09_deadcity", "start"),
    ):
        body = ltx.split(f"[{section}]", 1)[1].split("[", 1)[0]
        if f"ambush_spawn_timing = {timing}" not in body:
            raise AssertionError(f"unexpected {section} timing baseline")
    block = isolation_block(source)
    assert_policy(block, source)
    for variant in ("lua51", "luajit20", "luajit21"):
        execute_fixture(block, variant)
    print("Squad target isolation: OK (self-target; no generic target, offline lock, target clearing or position write; Lua 5.1/LuaJIT)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
