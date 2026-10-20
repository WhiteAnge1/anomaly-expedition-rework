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
    target: tuple[float, float, float] = (10.0, 5.75, 20.0)
    surface_y: float = 5.0
    clearance: float = 0.75
    state: str = "target_ready"
    required: bool = True
    own: list[int] = field(default_factory=list)
    foreign: list[int] = field(default_factory=list)


def position_safe(record: Record, position: tuple[float, float, float], tolerance: float = 0.35) -> bool:
    dx = position[0] - record.target[0]
    dz = position[2] - record.target[2]
    dy = position[1] - record.target[1]
    clearance = position[1] - record.surface_y
    return (dx * dx + dz * dz) ** 0.5 <= tolerance and abs(dy) <= tolerance \
        and clearance >= max(0.05, record.clearance - tolerance)


def hold(record: Record, object_id: int, section: str, position: tuple[float, float, float], shell: Shell) -> str:
    if object_id != record.object_id or section != record.section:
        record.state = "unresolved"
        return "identity"
    if not position_safe(record, position):
        record.state = "unresolved"
        return "position"
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
        "artifact_proactive_hold", "artifact_proactive_clearance", "artifact_proactive_position_tolerance",
        'source = "guarded_spawn_target"', 'state = "target_ready"', 'state = "awaiting_online"',
        'state = "held_accessible"', 'state = "rehydrate_pending"', 'state = "unresolved"',
        'item_artefact.artefact_binder.net_spawn', 'RegisterScriptCallback("artefact_on_first_update"',
        "online teleport forbidden", "foreign_fixed_indices", "hold_preserved=true",
        "math.max(0.5, math.min(1,",
        "local ARTIFACT_PROVENANCE_SCHEMA = 6", "state.schema = 6",
    )
    for needle in required_source:
        if needle not in source:
            raise RuntimeError(f"proactive runtime invariant missing: {needle}")
    if "teleport_object" in proactive:
        raise RuntimeError("proactive lifecycle must never teleport an online object")
    for needle in (
        "artifact_proactive_hold = true",
        "artifact_proactive_clearance = 0.75",
        "artifact_proactive_position_tolerance = 0.35",
        "profile = weighted",
    ):
        if needle not in config:
            raise RuntimeError(f"proactive config invariant missing: {needle}")

    record = Record()
    shell = Shell([Element(), Element(fixed=True, foreign=True)])
    assert record.target[1] == record.surface_y + 0.75
    assert hold(record, 42, "af_test", record.target, shell) == "held"
    assert record.own == [0] and record.foreign == [1]
    assert shell.linear == (0.0, 0.0, 0.0) and shell.angular == (0.0, 0.0, 0.0)
    assert hold(record, 42, "af_test", record.target, shell) == "idempotent"

    # Save/load and a new online incarnation must not inherit stale ownership.
    record.state, record.own, record.foreign = "rehydrate_pending", [], []
    loaded_shell = Shell([Element(), Element()])
    assert hold(record, 42, "af_test", record.target, loaded_shell) == "held"
    assert record.own == [0, 1]

    # Offline/online and PAW-equivalent recreation reapply without action counters.
    record.state, record.own, record.foreign = "awaiting_online", [], []
    recreated_shell = Shell([Element(), Element(fixed=True, foreign=True)])
    assert hold(record, 42, "af_test", record.target, recreated_shell) == "held"
    assert record.own == [0] and record.foreign == [1]

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
    assert hold(cleanup, 42, "af_test", cleanup.target, cleanup_shell) == "held"
    release(cleanup, cleanup_shell)
    assert cleanup_shell.elements[0].fixed is False and cleanup.state == "released"

    print("Artifact proactive hold lifecycle policy test: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
