from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "Contents/mods/KnoxCureProject/42"
MEDIA = MOD / "media"


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


expected_actions = {
    "placeCorpseOnGurney",
    "removeCorpseFromGurney",
    "cleanGurney",
    "autopsy",
    "extractSample",
    "examineMicroscope",
    "runCentrifuge",
    "calibrateAnalyzer",
    "analyzeViralFraction",
    "writeScientificRecord",
    "exportData",
    "importData",
    "runSynthesizer",
}

definitions = read(
    "Contents/mods/KnoxCureProject/42/media/lua/shared/KCP/Actions/KCPActionDefinitions.lua"
)
defined_actions = set(re.findall(r'^\s{4}([A-Za-z0-9_]+)\s*=\s*\{\s*$', definitions, re.MULTILINE))
require(expected_actions <= defined_actions, f"Missing action definitions: {expected_actions - defined_actions}")
require("schemaVersion = 1" in definitions, "Phase 3 schemaVersion is missing")

service = read(
    "Contents/mods/KnoxCureProject/42/media/lua/shared/KCP/Actions/KCPActionService.lua"
)
executors = set(re.findall(r"EXECUTORS\.([A-Za-z0-9_]+)\s*=", service))
require(expected_actions == executors, f"Executor mismatch: {expected_actions ^ executors}")
require("busyToken" in service and "busyUntil" in service, "Station locking is missing")
require("setDoGrappleLetGo" in service, "Vanilla corpse release is missing")
require("pickUpCorpse" in service, "Vanilla corpse retrieval is missing")
require("resolveCorpsePlacements" in service, "Corpse-to-gurney linking is missing")

utils = read(
    "Contents/mods/KnoxCureProject/42/media/lua/shared/KCP/Actions/KCPActionUtils.lua"
)
require("sendRemoveItemFromContainer" in utils, "Server inventory removal sync is missing")
require("sendAddItemToContainer" in utils, "Server inventory addition sync is missing")
require("isDraggingCorpse" in utils, "Vanilla corpse-dragging validation is missing")
require("getLinkedCorpse" in utils, "Gurney corpse linking is missing")

server = read(
    "Contents/mods/KnoxCureProject/42/media/lua/server/KCP/Actions/KCPActionServer.lua"
)
for command in ("beginAction", "cancelAction", "completeAction"):
    require(command in server, f"Server command {command} is missing")
for command in ("stationSoundStart", "stationSoundStop"):
    require(command in server, f"Network sound command {command} is missing")

timed_action = read(
    "Contents/mods/KnoxCureProject/42/media/lua/client/KCP/Actions/KCPTimedAction.lua"
)
require("setActionAnim" not in timed_action, "Phase 3 must not assign action animations")
for cancellation in ("stopOnWalk = true", "stopOnRun = true", "stopOnAim = true", "startHealth"):
    require(cancellation in timed_action, f"Cancellation guard missing: {cancellation}")

items_text = read("Contents/mods/KnoxCureProject/42/media/scripts/KCP_Items.txt")
item_ids = set(re.findall(r"^\s{4}item\s+([A-Za-z0-9_]+)\s*$", items_text, re.MULTILINE))
require("ProvisionalSampleContainer" in item_ids, "Provisional sample container is missing")
container_block = re.search(
    r"item ProvisionalSampleContainer\s*\{(?P<body>.*?)\n\s*\}", items_text, re.DOTALL
)
require(container_block is not None, "Cannot inspect provisional sample container")
require("StaticModel" not in container_block.group("body"), "A final sample-container model was added early")

for language in ("EN", "ES"):
    ui_path = MEDIA / f"lua/shared/Translate/{language}/IG_UI.json"
    item_path = MEDIA / f"lua/shared/Translate/{language}/ItemName.json"
    ui = json.loads(ui_path.read_text(encoding="utf-8"))
    item_names = json.loads(item_path.read_text(encoding="utf-8"))
    for action_id in expected_actions:
        label_match = re.search(
            rf"{action_id}\s*=\s*\{{.*?labelKey\s*=\s*\"([^\"]+)\"",
            definitions,
            re.DOTALL,
        )
        require(label_match and label_match.group(1) in ui, f"{language}: missing label for {action_id}")
    translated_items = {key.split(".", 1)[1] for key in item_names if key.startswith("KCP.")}
    require(item_ids <= translated_items, f"{language}: missing item names: {item_ids - translated_items}")

sounds = read("Contents/mods/KnoxCureProject/42/media/scripts/KCP_Sounds.txt")
for sound_name, filename in (
    ("KCP_KeyboardTyping", "KCP_KeyboardTyping.ogg"),
    ("KCP_SynthesizerRotor", "KCP_SynthesizerRotor.ogg"),
):
    require(sound_name in sounds, f"Sound definition missing: {sound_name}")
    require((MEDIA / "sound" / filename).is_file(), f"Sound asset missing: {filename}")

print(f"Phase 3 validation: PASS ({len(expected_actions)} actions, {len(item_ids)} provisional items)")
