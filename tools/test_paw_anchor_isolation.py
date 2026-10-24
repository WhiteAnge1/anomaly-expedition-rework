from __future__ import annotations

import importlib
from pathlib import Path
import re
import sys


BEGIN = "-- PAW_ANCHOR_RECOVERY_BEGIN"
END = "-- PAW_ANCHOR_RECOVERY_END"


def between(source: str, begin: str, end: str) -> str:
    start = source.index(begin) + len(begin)
    finish = source.index(end, start)
    return source[start:finish]


def create_anchor_block(source: str) -> str:
    match = re.search(
        r"local function create_anchor\(pos\)(.*?)\nend\n\n-- PAW_ANCHOR_RECOVERY_BEGIN",
        source,
        re.S,
    )
    if not match:
        raise AssertionError("create_anchor block not found")
    return match.group(1)


FIXTURE_PREFIX = r'''
RVM_SORTIES_ANCHOR_RECOVERY = {}
PREFIX = "[fixture]"
objects = { [10] = true, [40] = true }
created = 1000
fail_create = false
released = {}
refreshed = {}
logs = {}

artifact_zone = { ["501"] = "10" }
zone_paw = { kind = "artifact", anchor_id = 10, center = {x=1,y=2,z=3}, radius = 70,
    artifact_id = 501, artifact_section = "af_test", content_token = "artifact-content", paw_anchor = true, closed = false }
zone_missing = { kind = "loot", anchor_id = 20, center = {x=4,y=5,z=6}, radius = 80,
    content_id = 777, visual_id = 778, content_token = "loot-content", paw_anchor = false, closed = false }
zone_closed = { kind = "empty", anchor_id = 30, center = {x=7,y=8,z=9}, radius = 90,
    content_token = "closed-content", paw_anchor = true, closed = true }
zone_raw = { kind = "enemy", anchor_id = 40, center = {x=10,y=11,z=12}, radius = 60,
    squad_id = 888, content_token = "enemy-content", paw_anchor = false, closed = false }
state = {
    zones = { ["10"] = zone_paw, ["20"] = zone_missing, ["30"] = zone_closed, ["40"] = zone_raw },
    artifact_zone = artifact_zone,
}

function alife_object(id) return objects[id] and { id = id } or nil end
function pos_vector(pos) return { x=pos.x, y=pos.y, z=pos.z } end
function create_anchor(pos)
    if fail_create then return nil end
    created = created + 1
    objects[created] = true
    return created, { x=pos.x, y=pos.y, z=pos.z }, false
end
function remove_spot(zone) zone.removed_spot = (zone.removed_spot or 0) + 1 end
function release_anchor(zone)
    released[#released + 1] = { id=zone.anchor_id, paw=zone.paw_anchor == true }
    objects[zone.anchor_id] = nil
end
function link_artifact_provenance(zone) zone.provenance_anchor = zone.anchor_id end
function refresh_zone_spots(zone) refreshed[#refreshed + 1] = zone.anchor_id end
function release_log(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end
function printf(fmt, ...) logs[#logs + 1] = string.format(fmt, ...) end
'''


FIXTURE_SUFFIX = r'''
local repaired = RVM_SORTIES_ANCHOR_RECOVERY.recover_all("first_update", true)
assert(repaired == 2)
assert(zone_paw.anchor_id ~= 10 and zone_missing.anchor_id ~= 20)
assert(zone_paw.paw_anchor == false and zone_missing.paw_anchor == false)
assert(state.zones["10"] == nil and state.zones["20"] == nil)
assert(state.zones[tostring(zone_paw.anchor_id)] == zone_paw)
assert(state.zones[tostring(zone_missing.anchor_id)] == zone_missing)
assert(state.artifact_zone["501"] == tostring(zone_paw.anchor_id))
assert(zone_paw.provenance_anchor == zone_paw.anchor_id)
assert(zone_paw.content_token == "artifact-content" and zone_paw.artifact_id == 501)
assert(zone_missing.content_token == "loot-content" and zone_missing.content_id == 777 and zone_missing.visual_id == 778)
assert(zone_closed.anchor_id == 30 and state.zones["30"] == zone_closed)
assert(zone_raw.anchor_id == 40 and state.zones["40"] == zone_raw)
local paw_releases = 0
for _, released_anchor in ipairs(released) do
    if released_anchor.paw then paw_releases = paw_releases + 1 end
end
assert(#refreshed == 2 and #released == 2 and paw_releases == 1)

-- Once migrated, normal refresh/update cannot duplicate content or anchors.
local paw_raw = zone_paw.anchor_id
local loot_raw = zone_missing.anchor_id
assert(RVM_SORTIES_ANCHOR_RECOVERY.recover_all("steady", true) == 0)
assert(zone_paw.anchor_id == paw_raw and zone_missing.anchor_id == loot_raw)
assert(#refreshed == 2 and created == 1002)

-- Simulate external destruction of an open raw anchor. Only the anchor/key is
-- rebuilt; linked content and zone identity survive.
objects[paw_raw] = nil
assert(RVM_SORTIES_ANCHOR_RECOVERY.recover_all("runtime_missing", true) == 1)
assert(zone_paw.anchor_id ~= paw_raw and zone_paw.artifact_id == 501)
assert(zone_paw.content_token == "artifact-content")
assert(state.artifact_zone["501"] == tostring(zone_paw.anchor_id))

-- Failed recreation is fail-closed: the zone remains open and its content is
-- retained for a later retry. Closed zones are never resurrected.
objects[loot_raw] = nil
fail_create = true
local before_key = tostring(zone_missing.anchor_id)
assert(RVM_SORTIES_ANCHOR_RECOVERY.recover_all("deferred", true) == 0)
assert(zone_missing.anchor_id == tonumber(before_key) and zone_missing.closed == false)
assert(zone_missing.content_id == 777 and zone_missing.content_token == "loot-content")
assert(zone_closed.anchor_id == 30 and zone_closed.closed == true)
'''


def validate_source(source: str) -> str:
    anchor = create_anchor_block(source)
    for needle in ('alife_create("script_zone"', 'return anchor.id, pos_table(fixed), false'):
        if needle not in anchor:
            raise AssertionError(f"AER-owned raw anchor invariant missing: {needle}")
    for forbidden in (
        "tasks_placeable_waypoints",
        "generate_scripted_mapspot_at",
        "set_pingspot_persistence",
    ):
        if forbidden in anchor:
            raise AssertionError(f"new anchor still PAW-owned: {forbidden}")

    block = between(source, BEGIN, END)
    for needle in (
        "zone.paw_anchor == true",
        "not RVM_SORTIES_ANCHOR_RECOVERY.anchor_exists(zone.anchor_id)",
        "content_preserved=true",
        'RVM_SORTIES_ANCHOR_RECOVERY.recover_all("actor_first_update", false)',
        'RVM_SORTIES_ANCHOR_RECOVERY.recover_all("actor_update", true)',
    ):
        if needle not in block and needle not in source:
            raise AssertionError(f"anchor recovery lifecycle missing: {needle}")
    return block


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    source = (root / "gamedata/scripts/zzz_rvm_sorties_rework.script").read_text(encoding="utf-8")
    block = validate_source(source)
    for variant in ("lua51", "luajit20", "luajit21"):
        runtime = importlib.import_module(f"lupa.{variant}").LuaRuntime(unpack_returned_tuples=True)
        runtime.execute(FIXTURE_PREFIX + block + FIXTURE_SUFFIX)
    print("PAW anchor isolation: OK (raw ownership, RC6 migration, missing-anchor recovery, closed/failure guards; Lua 5.1/LuaJIT)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
