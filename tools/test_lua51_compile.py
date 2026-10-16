from __future__ import annotations

import argparse
import importlib
from pathlib import Path

X_RAY_SCRIPT_PREFIX = "local __xray_script_slot\n"


def load_chunk(module_name: str, source: str, chunk_name: str):
    module = importlib.import_module(f"lupa.{module_name}")
    runtime = module.LuaRuntime(unpack_returned_tuples=True)
    loader = runtime.eval(
        "function(source, chunk_name) "
        "local fn, err = loadstring(source, chunk_name); return fn, err end"
    )
    return loader(source, chunk_name)


def compile_chunk(module_name: str, source: str, path: Path) -> None:
    # X-Ray's script-module loader consumes one local slot around the module
    # chunk. Commit 1661ffd sat exactly on stock Lua's boundary: bare loadstring
    # accepted it, while X-Ray rejected it. Prefixing one inert local reproduces
    # that observed loader budget without executing any game code.
    function, error = load_chunk(
        module_name, X_RAY_SCRIPT_PREFIX + source, f"@{path.as_posix()}"
    )
    if function is None:
        raise RuntimeError(f"{module_name} rejected {path}: {error}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Compile mod scripts with real Lua 5.1/LuaJIT frontends."
    )
    parser.add_argument("mod_root", type=Path)
    args = parser.parse_args()

    scripts = sorted((args.mod_root / "gamedata" / "scripts").glob("*.script"))
    if not scripts:
        raise RuntimeError("no runtime scripts found")

    variants = ("lua51", "luajit20", "luajit21")
    boundary = "local " + ",".join(f"v{index}" for index in range(1, 201))
    for path in scripts:
        source = path.read_text(encoding="utf-8")
        for variant in variants:
            rejected, overflow_error = load_chunk(
                variant,
                X_RAY_SCRIPT_PREFIX + boundary,
                "@synthetic-xray-200-local-boundary.script",
            )
            if rejected is not None or "200 local" not in str(overflow_error):
                raise RuntimeError(
                    f"{variant} did not enforce the X-Ray wrapped 200-local limit: "
                    f"{overflow_error}"
                )
            compile_chunk(variant, source, path)

    print(
        "Lua 5.1/LuaJIT compile: OK "
        f"({len(scripts)} scripts; {', '.join(variants)})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
