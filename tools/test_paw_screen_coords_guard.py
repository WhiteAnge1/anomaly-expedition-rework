from __future__ import annotations

import importlib
from pathlib import Path
import sys


BEGIN = "-- PAW_SCREEN_COORDS_GUARD_BEGIN"
END = "-- PAW_SCREEN_COORDS_GUARD_END"


def between(source: str, begin: str, end: str) -> str:
    start = source.index(begin) + len(begin)
    finish = source.index(end, start)
    return source[start:finish]


FIXTURE_PREFIX = r'''
PREFIX = "[fixture]"
logs = {}
server_objects = {}
client_objects = {}
base_mode = "normal"
base_calls = 0
cleanup_calls = 0

function printf(fmt, ...)
    logs[#logs + 1] = string.format(fmt, ...)
end

function alife_object(id)
    return server_objects[id]
end

db = { storage = {} }
level = {}
function level.object_by_id(id)
    return client_objects[id]
end

tasks_placeable_waypoints = nil
function paw_base_get_screen_coords(id)
    base_calls = base_calls + 1
    if base_mode == "se_obj_race" then
        error("tasks_placeable_waypoints.script:4430: attempt to index local 'se_obj' (a nil value)")
    end
    if base_mode == "unrelated_error" then
        error("PAW unrelated fixture failure")
    end
    if not server_objects[id] and not client_objects[id] then
        cleanup_calls = cleanup_calls + 1
        return nil
    end
    return "base:" .. tostring(id)
end
'''


FIXTURE_SUFFIX = r'''
-- AER can run before PAW exposes the function. Installation must fail closed
-- and succeed on the next lifecycle retry without mutating anything.
assert(RVM_SORTIES_PAW_COMPAT.install() == false)
tasks_placeable_waypoints = { get_screen_coords = paw_base_get_screen_coords }
assert(RVM_SORTIES_PAW_COMPAT.install() == true)
local wrapper = tasks_placeable_waypoints.get_screen_coords
assert(wrapper == RVM_SORTIES_PAW_COMPAT.wrapper)
assert(RVM_SORTIES_PAW_COMPAT.install() == true)
assert(tasks_placeable_waypoints.get_screen_coords == wrapper)

-- Stable server/client state delegates to PAW unchanged.
server_objects[10] = { id = 10 }
client_objects[10] = { id = 10 }
assert(tasks_placeable_waypoints.get_screen_coords(10) == "base:10")
assert(base_calls == 1 and cleanup_calls == 0)

-- Exact crash state: client survives after server removal. The wrapper returns
-- no coordinate for this frame and does not invoke PAW cleanup or base logic.
server_objects[20] = nil
client_objects[20] = { id = 20 }
assert(tasks_placeable_waypoints.get_screen_coords(20) == nil)
assert(base_calls == 1 and cleanup_calls == 0)
assert(#logs == 2)
assert(string.find(logs[2], "id=20", 1, true))
assert(string.find(logs[2], "route_pin_preserved=true", 1, true))
-- Repeated HUD updates remain quiet and still preserve the route/pin.
assert(tasks_placeable_waypoints.get_screen_coords(20) == nil)
assert(base_calls == 1 and cleanup_calls == 0 and #logs == 2)

-- Both objects absent is PAW's stable missing-object case. Delegate so PAW
-- keeps ownership of its normal cleanup semantics.
server_objects[30] = nil
client_objects[30] = nil
assert(tasks_placeable_waypoints.get_screen_coords(30) == nil)
assert(base_calls == 2 and cleanup_calls == 1)

-- A disappearance between precheck and PAW lookup is caught narrowly.
server_objects[40] = { id = 40 }
client_objects[40] = { id = 40 }
base_mode = "se_obj_race"
assert(tasks_placeable_waypoints.get_screen_coords(40) == nil)
assert(base_calls == 3 and cleanup_calls == 1)
assert(#logs == 3)
assert(string.find(logs[3], "stage=caught_race", 1, true))

-- Unrelated PAW failures must remain visible.
server_objects[50] = { id = 50 }
client_objects[50] = { id = 50 }
base_mode = "unrelated_error"
local unrelated_ok, unrelated_error = pcall(tasks_placeable_waypoints.get_screen_coords, 50)
assert(unrelated_ok == false)
assert(string.find(tostring(unrelated_error), "unrelated fixture failure", 1, true))
'''


def validate_source(source: str) -> str:
    block = between(source, BEGIN, END)
    for needle in (
        "type(paw.get_screen_coords)",
        "server_ok and client_ok and not server_object and client_object",
        'RVM_SORTIES_PAW_COMPAT.report(id, "precheck")',
        'RVM_SORTIES_PAW_COMPAT.report(id, "caught_race")',
        "route_pin_preserved=true",
        "pcall(base_get_screen_coords, id)",
        "error(result, 0)",
        "paw.get_screen_coords = RVM_SORTIES_PAW_COMPAT.wrapper",
    ):
        if needle not in block:
            raise AssertionError(f"PAW screen-coords guard invariant missing: {needle}")
    for forbidden in (
        "end_waypoint_task",
        'do_paw_action("pn_del"',
        "remove_map_spot",
    ):
        if forbidden in block:
            raise AssertionError(f"AER compatibility guard mutates PAW state: {forbidden}")
    if "RVM_SORTIES_PAW_COMPAT.install()\n    if hooks_installed then return end" not in source:
        raise AssertionError("PAW guard must retry before the general hook idempotence gate")
    return block


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    source = (root / "gamedata/scripts/zzz_rvm_sorties_rework.script").read_text(encoding="utf-8")
    block = validate_source(source)
    for variant in ("lua51", "luajit20", "luajit21"):
        runtime = importlib.import_module(f"lupa.{variant}").LuaRuntime(unpack_returned_tuples=True)
        runtime.execute(FIXTURE_PREFIX + block + FIXTURE_SUFFIX)
    print(
        "PAW screen-coords guard: OK "
        "(late-load retry, client-only transition, caught race, state preservation, stable delegation, unrelated-error passthrough; Lua 5.1/LuaJIT)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
