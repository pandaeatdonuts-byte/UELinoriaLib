# UELinoriaLib

Rebuilt [LinoriaLib](https://github.com/violin-suzutsuki/LinoriaLib) with the Unnamed Enhancements window chrome and control animations.

Visual style inspired by [cloudsense-pub/UELinoriaLib](https://github.com/cloudsense-pub/UELinoriaLib), rebuilt from the stable original instead of patching the buggy fork.

## Usage

```lua
local repo = 'https://raw.githubusercontent.com/pandaeatdonuts-byte/UELinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()
```

See [`Example.lua`](Example.lua) for a full demo menu.

## Credits

- Original LinoriaLib: Inori, Wally, and contributors
- UE visual direction: F3kel666 / c98j (Unnamed Enhancements)
