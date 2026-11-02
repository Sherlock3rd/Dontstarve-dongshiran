"""Run installed native Freezable code with a deterministic scheduler, not an engine test."""
from pathlib import Path
import argparse, json, zipfile
from lupa.lua51 import LuaRuntime

parser = argparse.ArgumentParser()
parser.add_argument('--scripts', type=Path, default=Path(r"D:\Program Files (x86)\Steam\steamapps\common\Don't Starve Together\data\databundles\scripts.zip"))
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(register_eval=False, register_builtins=False)
with zipfile.ZipFile(args.scripts) as archive:
    lua.globals().native_freezable = archive.read('scripts/components/freezable.lua').decode('utf8')
lua.globals().adapter_source = (root/'scripts/hitsugaya_freeze.lua').read_text(encoding='utf8')
lua.globals().haunt_source = (root/'scripts/hitsugaya_haunt.lua').read_text(encoding='utf8')
lua.globals().compat_source = (root/'scripts/components/hitsugaya_compat.lua').read_text(encoding='utf8')
results = lua.execute((root/'tests/haunt_timing.lua').read_text(encoding='utf8'))
print(json.dumps({'passed':len(results),'cases':list(results.values()),'scope':'installed native Freezable Lua with deterministic scheduler'},ensure_ascii=False))
