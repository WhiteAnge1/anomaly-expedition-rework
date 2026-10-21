from __future__ import annotations

import argparse
import importlib
import xml.etree.ElementTree as ET
from pathlib import Path


def collect_options(root: Path):
    module = importlib.import_module("lupa.lua51")
    lua = module.LuaRuntime(unpack_returned_tuples=True)
    lua.execute((root / "gamedata/scripts/rvm_sorties_mcm.script").read_text(encoding="utf-8"))
    tree = lua.globals().on_mcm_load()
    controls: list[tuple[str, str, object, object]] = []
    support: list[str] = []
    lists: list[tuple[str, str]] = []

    def walk(node, prefix=""):
        node_id = str(node["id"])
        current = node_id if not prefix else f"{prefix}_{node_id}"
        group = node["gr"]
        if group is not None:
            if prefix:
                support.append(f"ui_mcm_{current}")
            for index in range(1, len(group) + 1):
                walk(group[index], current)
            return
        kind = str(node["type"])
        if node["val"] is not None:
            controls.append((f"ui_mcm_{current}", kind, node["def"], node))
            content = node["content"]
            if content is not None:
                for index in range(1, len(content) + 1):
                    lists.append((f"ui_mcm_{current}_lst_{content[index][2]}", current))
        elif node["text"] is not None:
            support.append(str(node["text"]))

    walk(tree)
    return controls, support, lists


def strings(path: Path) -> dict[str, str]:
    xml = ET.parse(path)
    return {item.attrib["id"]: "".join(item.find("text").itertext()).strip() for item in xml.getroot()}


def main() -> int:
    parser = argparse.ArgumentParser(description="Require complete bilingual MCM labels and tooltips.")
    parser.add_argument("mod_root", type=Path)
    args = parser.parse_args()
    controls, support, lists = collect_options(args.mod_root)
    languages = {
        "rus": ("По умолчанию:", "Применение:", "Диапазон:", "Варианты:", "Относитель"),
        "eng": ("Default:", "Applies:", "Range:", "Options:", "Relative"),
    }
    for language, markers in languages.items():
        table = strings(args.mod_root / f"gamedata/configs/text/{language}/st_rvm_sorties_mcm.xml")
        for key in support:
            assert table.get(key), f"{language}: missing support/tree label {key}"
        for key, _ in lists:
            assert table.get(key), f"{language}: missing list label {key}"
        for key, kind, _default, node in controls:
            desc = table.get(key + "_desc", "")
            assert table.get(key), f"{language}: missing control label {key}"
            assert desc, f"{language}: missing control tooltip {key}"
            assert markers[0] in desc and desc.split(markers[0], 1)[1].strip(), f"{language}: default missing {key}"
            assert markers[1] in desc and desc.split(markers[1], 1)[1].strip(), f"{language}: apply timing missing {key}"
            if isinstance(_default, bool):
                expected_default = ("включено" if _default else "выключено") if language == "rus" else ("enabled" if _default else "disabled")
            elif isinstance(_default, str):
                translated = {
                    ("rus", "scouting"): "разведывательная",
                    ("rus", "weighted"): "расширенный взвешенный",
                    ("rus", "proximity"): "при приближении",
                }
                expected_default = translated.get((language, _default), _default)
            else:
                expected_default = str(_default)
            default_clause = desc.split(markers[0], 1)[1].split(markers[1], 1)[0].lower()
            assert expected_default.lower() in default_clause, f"{language}: wrong default value {key}: expected {expected_default}"
            if kind == "track":
                assert markers[2] in desc, f"{language}: range missing {key}"
            if kind == "list":
                assert markers[3] in desc, f"{language}: options missing {key}"
            if "weight" in key or "_counts_" in key and kind == "track":
                assert markers[4] in desc, f"{language}: relative-weight explanation missing {key}"
                assert "LTX" in desc or "fallback" in desc, f"{language}: weight fallback missing {key}"
            dependency_words = ("игнор", "выключ", "LTX", "debug", "callbacks", "зависим", "не связан", "ignor", "off", "fallback", "debug", "callbacks", "parent", "independent")
            assert any(word in desc for word in dependency_words), f"{language}: dependency/disabled behavior missing {key}"
    print(f"MCM localization: OK ({len(controls)} controls; Russian + English labels, defaults, timing, ranges and dependencies)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
