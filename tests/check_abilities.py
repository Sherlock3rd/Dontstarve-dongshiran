"""Behavior regressions in Lua 5.1; native acceptance is a separate fixture."""
from pathlib import Path
import json
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(register_eval=False, register_builtins=False)
sources = lua.table()
for path in (root / 'scripts').rglob('*.lua'):
    sources[path.relative_to(root / 'scripts').with_suffix('').as_posix()] = path.read_text(encoding='utf8')
lua.globals().sources = sources
result = lua.execute((root / 'tests/ability_scenarios.lua').read_text(encoding='utf8'))
print(json.dumps({'passed': len(result), 'cases': list(result.values()), 'scope': 'isolated Lua 5.1'}, ensure_ascii=False))
