# Omnibutton — Apple Shortcut

A single Action Button shortcut that prompts for text, then routes to any of seven actions.

## Flow

```
Action Button press
       │
       ▼
┌──────────────────────┐
│  Ask for Input       │  "What's on your mind?"
└──────────────────────┘
       │
       ▼
┌──────────────────────────────────┐
│  Choose an action                │
│  ──────────────────────────────  │
│  🤖 Ask Claude                   │
│  📋 Copy to Clipboard            │
│  ✏️  Transform Text ──► submenu  │
│  🔍 Search Web                   │
│  ✉️  Send Message                │
│  📧 Send Email                   │
│  ✅ Add to Things 3              │
└──────────────────────────────────┘
```

### Transform Text submenu

```
  📝 Summarize      — "Summarize the following text concisely: …"
  ✍️  Rewrite        — "Rewrite the following text to be clearer …"
  •  Bullet Points  — "Convert the following text into bullet points …"
```
Each option builds a prompt, sends it to Claude, and displays the result.

---

## Installation

### 1. Transfer the file to your iPhone

- AirDrop `Omnibutton.shortcut` directly to your iPhone, **or**
- Add it to iCloud Drive and open it in the Files app

### 2. Import into Shortcuts

Tap the file — iOS will open Shortcuts and ask you to add it.

### 3. Wire up "Ask Claude" (required)

The Claude App Intent identifier may not match your device's installed version.
If the **🤖 Ask Claude** steps appear as "Unknown Action":

1. Open the shortcut in **Shortcuts** for editing.
2. Delete each red/unknown "Ask Claude" step (there are four — one in the main
   case and one in each Transform sub-case).
3. Tap **＋ Add Action**, search for **"Ask Claude"**, and add it.
4. Set its **Prompt** parameter to the preceding **Text** action's output.
5. Set the output of the Ask Claude step as the input to the following
   **Show Result** step.

### 4. Assign to the Action Button

**Settings → Action Button → Shortcut → Omnibutton**

---

## Technical details

| File | Purpose |
|------|---------|
| `Omnibutton.shortcut` | Ready-to-import shortcut (gzip-compressed binary plist) |
| `generate_omnibutton.py` | Reproducible generator — edit this to customize the shortcut |

### Regenerating the shortcut

```bash
python3 generate_omnibutton.py
```

Requires Python 3.6+ (stdlib only — `plistlib`, `gzip`, `uuid`).

### Inspecting / reverse-engineering shortcuts on macOS

```bash
# Decompress and convert to JSON
cp YourShortcut.shortcut /tmp/s.gz
gunzip /tmp/s.gz
plutil -convert json /tmp/s -o - | python3 -m json.tool | less

# Or in one pipeline
zcat YourShortcut.shortcut | plutil -convert json - -o - | python3 -m json.tool
```

### Finding the Claude App Intent identifier

Export any shortcut that uses **Ask Claude**, then:

```bash
zcat AskClaude.shortcut | plutil -convert json - -o - \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
for a in d['WFWorkflowActions']:
    print(a['WFWorkflowActionIdentifier'])
"
```

Update the identifier string in `generate_omnibutton.py` and re-run if needed.

---

## Customisation ideas

- Change the input prompt text in the `is.workflow.actions.ask` step
- Add a **📷 Scan Text** case using the camera OCR action
- Replace Google with DuckDuckGo: `https://duckduckgo.com/?q=`
- Add a **📓 Add to Notes** case using `is.workflow.actions.addnote`
- Add more Transform variants (e.g. "Translate", "Fix Grammar")
