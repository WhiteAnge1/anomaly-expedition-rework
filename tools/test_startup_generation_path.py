from __future__ import annotations

from pathlib import Path
import sys


def require(source: str, needle: str, label: str) -> None:
    if needle not in source:
        raise AssertionError(f"startup/generation path missing {label}: {needle}")


def model(runtime_loaded: bool) -> list[str]:
    if not runtime_loaded:
        return ["stock_sortie"]
    return [
        "startup",
        "hooks_installed",
        "prepare",
        "artifact_pool",
        "captured",
        "artifact_zone_created",
        "decoys_created",
    ]


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    source = (root / "gamedata/scripts/zzz_rvm_sorties_rework.script").read_text(encoding="utf-8")

    required = {
        "game start entry": "function on_game_start()",
        "startup diagnostic": "startup self-test",
        "hook installation": "install_hooks()",
        "sortie spawner wrapper": "raid_anomalys.spawner_anomals_zones",
        "artifact spawner wrapper": "raid_anomalys.spawn_artefact_in_zone",
        "prepare diagnostic": 'release_log("prepare ',
        "artifact pool diagnostic": 'release_log("artifact_pool ',
        "capture diagnostic": 'log("captured raid artifact ',
        "artifact zone creation": "create_artifact_zone(",
        "decoy creation": "create_decoys(",
        "first-update callback": 'RegisterScriptCallback("actor_on_first_update"',
        "update callback": 'RegisterScriptCallback("actor_on_update"',
        "save callback": 'RegisterScriptCallback("save_state"',
        "load callback": 'RegisterScriptCallback("load_state"',
    }
    for label, needle in required.items():
        require(source, needle, label)

    negative = model(False)
    if negative != ["stock_sortie"]:
        raise AssertionError(f"negative control unexpectedly contains AER events: {negative}")
    positive = model(True)
    for event in ("startup", "prepare", "artifact_pool", "captured", "artifact_zone_created", "decoys_created"):
        if event not in positive:
            raise AssertionError(f"positive control missing {event}")

    print("Startup-to-generation path: OK (negative stock-only; positive AER lifecycle complete)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
