from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
import sys


@dataclass
class Element:
    fixed: bool = False
    foreign: bool = False


@dataclass
class Shell:
    elements: list[Element]
    linear: tuple[float, float, float] = (1.0, -4.0, 2.0)
    angular: tuple[float, float, float] = (0.0, 3.0, 0.0)


@dataclass
class Record:
    object_id: int = 42
    section: str = "af_test"
    target: tuple[float, float, float] = (10.0, 6.0, 20.0)
    spawn_target: tuple[float, float, float] = (10.0, 5.75, 20.0)
    surface_y: float = 5.0
    clearance: float = 0.75
    hold_clearance: float = 1.0
    state: str = "target_ready"
    required: bool = True
    own: list[int] = field(default_factory=list)
    foreign: list[int] = field(default_factory=list)
    lifts: int = 0
    lift_attempts: int = 0
    lift_verified: bool = False


def position_safe(record: Record, position: tuple[float, float, float], tolerance: float = 0.35) -> bool:
    dx = position[0] - record.target[0]
    dz = position[2] - record.target[2]
    dy = position[1] - record.target[1]
    clearance = position[1] - record.surface_y
    return (dx * dx + dz * dz) ** 0.5 <= tolerance and abs(dy) <= tolerance \
        and clearance >= record.hold_clearance - tolerance


def surface_position_safe(record: Record, position: tuple[float, float, float], tolerance: float = 0.35) -> bool:
    dx = position[0] - record.target[0]
    dz = position[2] - record.target[2]
    clearance = position[1] - record.surface_y
    return (dx * dx + dz * dz) ** 0.5 <= tolerance and abs(clearance) <= tolerance


def schema6_position_safe(record: Record, position: tuple[float, float, float], tolerance: float = 0.35) -> bool:
    """Rejected field predicate: treated the raised server spawn as online pivot."""
    dx = position[0] - record.spawn_target[0]
    dz = position[2] - record.spawn_target[2]
    dy = position[1] - record.spawn_target[1]
    clearance = position[1] - record.surface_y
    return (dx * dx + dz * dz) ** 0.5 <= tolerance and abs(dy) <= tolerance \
        and clearance >= max(0.05, record.clearance - tolerance)


def hold(record: Record, object_id: int, section: str, position: tuple[float, float, float], shell: Shell | None) -> str:
    if object_id != record.object_id or section != record.section:
        record.state = "unresolved"
        return "identity"
    # Field schema 8 proved force_set_position may succeed before a shell is
    # ready, after which X-Ray restores the surface pivot. Schema 9 waits so
    # lift, verification and fixation complete in the same callback.
    if shell is None:
        record.state = "awaiting_online"
        return "shell_pending"
    if not position_safe(record, position):
        if not surface_position_safe(record, position):
            record.state = "unresolved"
            return "position"
        if record.lift_verified:
            record.state = "unresolved"
            return "verified_position_lost"
        if record.lift_attempts >= 3:
            record.state = "unresolved"
            return "lift_retry_exhausted"
        # Installed Modded Exes exports object:force_set_position(pos, true).
        # Model its immediate, physics-initializing lift and verification.
        record.lift_attempts += 1
        position = record.target
        record.lifts += 1
        if not position_safe(record, position):
            record.state = "unresolved"
            return "lift"
        record.lift_verified = True
    if record.state == "held_accessible" and all(shell.elements[i].fixed for i in record.own):
        return "idempotent"
    record.own, record.foreign = [], []
    shell.linear = shell.angular = (0.0, 0.0, 0.0)
    for index, element in enumerate(shell.elements):
        if element.fixed:
            record.foreign.append(index)
        else:
            element.fixed = True
            record.own.append(index)
    record.state = "held_accessible"
    return "held"


def release(record: Record, shell: Shell | None, ownership: bool = False) -> None:
    if shell is not None:
        for index in record.own:
            shell.elements[index].fixed = False
    elif not ownership and record.own:
        raise AssertionError("world shell disappeared without an ownership transition")
    record.own = []
    record.required = False
    record.state = "released"


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    source = (root / "gamedata/scripts/zzz_rvm_sorties_rework.script").read_text(encoding="utf-8")
    config = (root / "gamedata/configs/plugins/rvm_sorties_rework.ltx").read_text(encoding="utf-8")

    begin = source.index("-- PROACTIVE_HOLD_BEGIN")
    end = source.index("-- PROACTIVE_HOLD_END", begin)
    proactive = source[begin:end]
    required_source = (
        "artifact_proactive_hold", "artifact_proactive_clearance", "artifact_online_hold_clearance",
        "artifact_proactive_position_tolerance", 'source = "guarded_online_hold_target"',
        'state = "target_ready"', 'state = "awaiting_online"',
        'state = "held_accessible"', 'state = "rehydrate_pending"', 'state = "unresolved"',
        'item_artefact.artefact_binder.net_spawn', 'RegisterScriptCallback("artefact_on_first_update"',
        "online teleport forbidden", "foreign_fixed_indices", "hold_preserved=true",
        "math.max(0.5, math.min(1,",
        "local ARTIFACT_PROVENANCE_SCHEMA = 9", "state.schema = 9",
        "schema_8_shell_ready_migration", "spawn_clearance = guarded_target.clearance",
        "artifact proactive lift", "online.force_set_position", "pos_vector(target.pos), true",
        "lift_retry_exhausted", "lift_attempts_this_online >= maximum_attempts",
        "artifact proactive incarnation", "artifact proactive online pending",
        "RVM_SORTIES_PROACTIVE.capture_in_progress = true",
        "RVM_SORTIES_PROACTIVE.capture_in_progress == true",
        'lifecycle.reason = "physics_shell_unavailable"',
        "local required_clearance = (tonumber(target.hold_clearance)",
    )
    for needle in required_source:
        if needle not in source:
            raise RuntimeError(f"proactive runtime invariant missing: {needle}")
    if "teleport_object" in proactive:
        raise RuntimeError("proactive lifecycle must never teleport an online object")
    if "runtime_online_ref" in proactive:
        raise RuntimeError("X-Ray game_object userdata must never be compared for online identity")
    for needle in (
        "artifact_proactive_hold = true",
        "artifact_proactive_clearance = 0.75",
        "artifact_online_hold_clearance = 1.0",
        "artifact_proactive_position_tolerance = 0.35",
        "profile = weighted",
    ):
        if needle not in config:
            raise RuntimeError(f"proactive config invariant missing: {needle}")

    record = Record()
    shell = Shell([Element(), Element(fixed=True, foreign=True)])
    assert record.spawn_target[1] == record.surface_y + 0.75
    assert record.target[1] == record.surface_y + 1.0
    assert hold(record, 42, "af_test", (10.0, 5.0, 20.0), None) == "shell_pending"
    assert record.lifts == 0
    assert hold(record, 42, "af_test", (10.0, 5.0, 20.0), shell) == "held"
    assert record.lifts == 1
    assert record.own == [0] and record.foreign == [1]
    assert shell.linear == (0.0, 0.0, 0.0) and shell.angular == (0.0, 0.0, 0.0)
    assert hold(record, 42, "af_test", record.target, shell) == "idempotent"

    # Save/load and a new online incarnation must not inherit stale ownership.
    record.state, record.own, record.foreign = "rehydrate_pending", [], []
    record.lift_attempts, record.lift_verified = 0, False
    loaded_shell = Shell([Element(), Element()])
    assert hold(record, 42, "af_test", (10.0, 5.0, 20.0), loaded_shell) == "held"
    assert record.own == [0, 1]

    # Offline/online and PAW-equivalent recreation reapply without action counters.
    record.state, record.own, record.foreign = "awaiting_online", [], []
    record.lift_attempts, record.lift_verified = 0, False
    recreated_shell = Shell([Element(), Element(fixed=True, foreign=True)])
    assert hold(record, 42, "af_test", (10.0, 5.0, 20.0), recreated_shell) == "held"
    assert record.own == [0] and record.foreign == [1]

    # Exact positions captured in the failed field run. X-Ray converted every
    # raised server spawn to a surface-relative online pivot before callbacks.
    # The old +clearance target rejected all seven; the surface-pivot contract
    # must accept binder positions while they are still accessible.
    field_rows = (
        (6703, 1.0, 1.0),
        (6905, -0.4, -0.4),
        (6959, -1.0, -1.0),
        (6994, 0.7, 0.7),
        (7002, 11.1, 11.1),
        (7016, 9.1, 9.2),
        (7795, 5.1, 5.0),
    )
    surfaces = {6703: 1.0, 6905: -0.4, 6959: -1.0, 6994: 0.7, 7002: 11.1, 7016: 9.2, 7795: 5.1}
    for artifact_id, binder_y, first_update_y in field_rows:
        surface = surfaces[artifact_id]
        observed = Record(object_id=artifact_id, target=(10.0, surface + 1.0, 20.0),
                          spawn_target=(10.0, surface + 0.75, 20.0), surface_y=surface)
        observed_shell = Shell([Element()])
        assert not schema6_position_safe(observed, (10.0, binder_y, 20.0))
        assert not position_safe(observed, (10.0, binder_y, 20.0))
        assert surface_position_safe(observed, (10.0, binder_y, 20.0))
        assert hold(observed, artifact_id, "af_test", (10.0, binder_y, 20.0), observed_shell) == "held"
        assert observed.lifts == 1
        assert observed_shell.elements[0].fixed
        assert position_safe(observed, observed.target)

        # Save/load clears runtime ownership, then the new shell is fixed again
        # at the same surface pivot instead of preserving a falling body.
        observed.state, observed.own, observed.foreign = "rehydrate_pending", [], []
        observed.lift_attempts, observed.lift_verified = 0, False
        reloaded_shell = Shell([Element()])
        assert hold(observed, artifact_id, "af_test", (10.0, first_update_y, 20.0), reloaded_shell) == "held"
        assert observed.lifts == 2
        assert reloaded_shell.elements[0].fixed

        # A failed/non-applying client method must not become a per-update loop
        # on the same online incarnation.
        blocked = Record(object_id=artifact_id, target=(10.0, surface + 1.0, 20.0),
                         spawn_target=(10.0, surface + 0.75, 20.0), surface_y=surface,
                         lift_attempts=3)
        assert hold(blocked, artifact_id, "af_test", (10.0, binder_y, 20.0), Shell([Element()])) \
            == "lift_retry_exhausted"
        assert blocked.lifts == 0

    # Exact schema-8 field log regression. The initial binder had an online
    # object but no usable shell for these IDs; lifting at that moment was
    # verified yet never followed by held. Schema 9 must leave the item at the
    # surface without consuming a lift, then atomically lift+fix on the first
    # callback that actually supplies a shell. 6905 also represents the far
    # offline case: no action occurs until its first real online shell.
    schema8_rows = (
        (6919, "af_propeller", 3.4),
        (6431, "af_night_star", 2.5),
        (6435, "af_vyvert", 4.8),
        (6905, "af_bracelet", 2.7),
    )
    for artifact_id, section, surface in schema8_rows:
        observed = Record(object_id=artifact_id, section=section,
                          target=(10.0, surface + 1.0, 20.0),
                          spawn_target=(10.0, surface + 0.75, 20.0), surface_y=surface)
        surface_position = (10.0, surface, 20.0)
        assert hold(observed, artifact_id, section, surface_position, None) == "shell_pending"
        assert observed.lifts == 0 and not observed.lift_verified
        ready_shell = Shell([Element()])
        assert hold(observed, artifact_id, section, surface_position, ready_shell) == "held"
        assert observed.lifts == 1 and observed.lift_attempts == 1 and observed.lift_verified
        assert ready_shell.elements[0].fixed

    # Pickup/ownership releases only our element; a foreign pre-fix survives.
    release(record, recreated_shell, ownership=True)
    assert recreated_shell.elements[0].fixed is False
    assert recreated_shell.elements[1].fixed is True

    # Unsafe current shell fails closed and is never moved to target.
    unsafe = Record()
    unsafe_shell = Shell([Element()])
    unsafe_position = (999.0, -40.0, 999.0)
    assert hold(unsafe, 42, "af_test", unsafe_position, unsafe_shell) == "position"
    assert unsafe.state == "unresolved" and unsafe_shell.elements[0].fixed is False

    # Ownership before hold and cleanup with an exact world shell are both safe.
    preowned = Record(state="owned")
    preowned.required = False
    assert preowned.own == []
    cleanup = Record()
    cleanup_shell = Shell([Element()])
    assert hold(cleanup, 42, "af_test", (10.0, 5.0, 20.0), cleanup_shell) == "held"
    release(cleanup, cleanup_shell)
    assert cleanup_shell.elements[0].fixed is False and cleanup.state == "released"

    print("Artifact proactive hold lifecycle policy test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
