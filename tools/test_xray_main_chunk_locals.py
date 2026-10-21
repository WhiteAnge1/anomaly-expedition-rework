from __future__ import annotations

from pathlib import Path
import re
import sys


# X-Ray accounts for hidden main-chunk state in addition to source locals. The
# field failure happened with 199 explicit locals; 198 is the last proven-safe
# source budget for this script layout.
MAX_EXPLICIT_MAIN_LOCALS = 198
LOCAL_FUNCTION = re.compile(r"^local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
LOCAL_ASSIGN = re.compile(r"^local\s+([^=\n]+?)(?:\s*=|\s*$)")
NAME = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def count_explicit_main_locals(source: str) -> tuple[int, list[str]]:
    """Count unindented locals; project style reserves column zero for chunk scope."""
    names: list[str] = []
    for line_no, line in enumerate(source.splitlines(), 1):
        function_match = LOCAL_FUNCTION.match(line)
        if function_match:
            names.append(f"{function_match.group(1)}@{line_no}")
            continue
        assign_match = LOCAL_ASSIGN.match(line)
        if not assign_match:
            continue
        candidates = [part.strip() for part in assign_match.group(1).split(",")]
        if not candidates or any(not NAME.match(candidate) for candidate in candidates):
            raise AssertionError(f"unrecognised main-chunk local declaration at line {line_no}: {line}")
        names.extend(f"{candidate}@{line_no}" for candidate in candidates)
    return len(names), names


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    path = root / "gamedata/scripts/zzz_rvm_sorties_rework.script"
    source = path.read_text(encoding="utf-8")
    count, names = count_explicit_main_locals(source)

    if "local PROACTIVE" in source:
        raise AssertionError("proactive namespace must not consume the X-Ray main-chunk local budget")
    if "RVM_SORTIES_PROACTIVE = RVM_SORTIES_PROACTIVE or {}" not in source:
        raise AssertionError("collision-resistant global proactive namespace is missing")
    if count > MAX_EXPLICIT_MAIN_LOCALS:
        tail = ", ".join(names[-8:])
        raise AssertionError(
            f"X-Ray main chunk local budget exceeded: {count}>{MAX_EXPLICIT_MAIN_LOCALS}; tail={tail}"
        )

    fixture = "\n".join(f"local fixture_{index} = {index}" for index in range(MAX_EXPLICIT_MAIN_LOCALS + 1))
    fixture_count, _ = count_explicit_main_locals(fixture)
    if fixture_count != MAX_EXPLICIT_MAIN_LOCALS + 1:
        raise AssertionError(f"negative fixture was not counted correctly: {fixture_count}")
    if fixture_count <= MAX_EXPLICIT_MAIN_LOCALS:
        raise AssertionError("negative fixture did not exceed the guarded X-Ray budget")

    print(f"X-Ray main-chunk locals: OK ({count}/{MAX_EXPLICIT_MAIN_LOCALS}; negative fixture={fixture_count})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
