#!/usr/bin/env python3
"""
Omnibutton Shortcut Generator
==============================
Generates an Apple Shortcuts .shortcut file (gzip-compressed binary plist)
for the Omnibutton Action Button shortcut.

Flow:
  1. Action Button triggers shortcut
  2. "Ask for Input" prompt appears
  3. Single menu shows all available actions
  4. Selected action executes with the typed text

Actions:
  🤖 Ask Claude        — App Intent from the Claude iOS app
  📋 Copy to Clipboard — Copies typed text directly
  ✏️ Transform Text    — Submenu: Summarize / Rewrite / Bullet Points (via Claude)
  🔍 Search Web        — Opens Google in Safari
  ✉️ Send Message      — Opens Messages compose sheet
  📧 Send Email        — Opens Mail compose sheet
  ✅ Add to Things 3   — things:///add?title= URL scheme

NOTE: The "Ask Claude" App Intent identifier (com.anthropic.claude.SiriExtension.AskClaudeIntent)
may need to be updated to match the exact identifier used by the Claude iOS app on your device.
To discover it: export a shortcut that uses "Ask Claude", then run:
  plutil -convert json YourShortcut.shortcut -o - | python3 -m json.tool | grep Identifier
"""

import gzip
import os
import plistlib
import uuid


# ── Helpers ────────────────────────────────────────────────────────────────────

def uid() -> str:
    """Return a new uppercase UUID string."""
    return str(uuid.uuid4()).upper()


def token_attachment(output_uuid: str, output_name: str) -> dict:
    """Reference a previous action's magic-variable output as a token attachment."""
    return {
        "Value": {
            "OutputName": output_name,
            "OutputUUID": output_uuid,
            "Type": "ActionOutput",
        },
        "WFSerializationType": "WFTextTokenAttachment",
    }


def token_string(prefix: str, output_uuid: str, output_name: str) -> dict:
    """
    Build a WFTextTokenString: optional literal prefix followed by a
    magic-variable attachment (U+FFFC placeholder).

    The NSRange key is "{location, 1}" where location = len(prefix) in
    UTF-16 code units (fine for ASCII prefixes used here).
    """
    loc = len(prefix)
    return {
        "Value": {
            "attachmentsByRange": {
                f"{{{loc}, 1}}": {
                    "OutputName": output_name,
                    "OutputUUID": output_uuid,
                    "Type": "ActionOutput",
                }
            },
            "string": prefix + "\ufffc",
        },
        "WFSerializationType": "WFTextTokenString",
    }


def show_result(text_value) -> dict:
    return {
        "WFWorkflowActionIdentifier": "is.workflow.actions.showresult",
        "WFWorkflowActionParameters": {"Text": text_value},
    }


def text_action(action_uuid: str, output_name: str, text_value) -> dict:
    """Text action — builds a text value that can be referenced downstream."""
    return {
        "WFWorkflowActionIdentifier": "is.workflow.actions.gettext",
        "WFWorkflowActionParameters": {
            "UUID": action_uuid,
            "CustomOutputName": output_name,
            "WFTextActionText": text_value,
        },
    }


def ask_claude_action(action_uuid: str, output_name: str, prompt_ref) -> dict:
    """
    App Intent action for 'Ask Claude' from the Claude iOS app.

    IMPORTANT: If this action appears as 'Unknown' after import, open the
    shortcut in the Shortcuts app, delete this step, search for 'Ask Claude',
    and re-add it — then wire the 'prompt' parameter to the preceding Text action.
    """
    return {
        # Replace with the exact identifier from the Claude app if different.
        # Common candidates:
        #   com.anthropic.claude.SiriExtension.AskClaudeIntent
        #   com.anthropic.claude.AskClaudeIntent
        "WFWorkflowActionIdentifier": "com.anthropic.claude.SiriExtension.AskClaudeIntent",
        "WFWorkflowActionParameters": {
            "UUID": action_uuid,
            "CustomOutputName": output_name,
            # The parameter name exposed by the Claude App Intent.
            # Verify / rename via plutil inspection of an exported Claude shortcut.
            "prompt": prompt_ref,
        },
    }


# Menu control-flow helpers

def menu_begin(grouping_id: str, items: list, prompt: str = "Choose an action") -> dict:
    return {
        "WFWorkflowActionIdentifier": "is.workflow.actions.choosefrommenu",
        "WFWorkflowActionParameters": {
            "GroupingIdentifier": grouping_id,
            "WFControlFlowMode": 0,          # begin
            "WFMenuItems": items,
            "WFMenuPrompt": prompt,
        },
    }


def menu_case(grouping_id: str, title: str) -> dict:
    return {
        "WFWorkflowActionIdentifier": "is.workflow.actions.choosefrommenu",
        "WFWorkflowActionParameters": {
            "GroupingIdentifier": grouping_id,
            "WFControlFlowMode": 1,          # case
            "WFMenuItemTitle": title,
        },
    }


def menu_end(grouping_id: str) -> dict:
    return {
        "WFWorkflowActionIdentifier": "is.workflow.actions.choosefrommenu",
        "WFWorkflowActionParameters": {
            "GroupingIdentifier": grouping_id,
            "WFControlFlowMode": 2,          # end
        },
    }


# ── UUID allocation ────────────────────────────────────────────────────────────

ASK_INPUT_UUID      = uid()   # "Ask for Input" action
MAIN_MENU_UUID      = uid()   # Top-level Choose from Menu

# Ask Claude case
ASK_CLAUDE_UUID     = uid()

# Transform Text submenu
TRANSFORM_MENU_UUID = uid()

SUMMARIZE_TEXT_UUID = uid()
SUMMARIZE_OUT_UUID  = uid()

REWRITE_TEXT_UUID   = uid()
REWRITE_OUT_UUID    = uid()

BULLETS_TEXT_UUID   = uid()
BULLETS_OUT_UUID    = uid()

# Search Web case
SEARCH_TEXT_UUID    = uid()

# Things 3 case
ENCODED_INPUT_UUID  = uid()
THINGS_URL_UUID     = uid()


# ── Build action list ──────────────────────────────────────────────────────────

actions = []

# ── Step 1: Ask for Input ──────────────────────────────────────────────────────
actions.append({
    "WFWorkflowActionIdentifier": "is.workflow.actions.ask",
    "WFWorkflowActionParameters": {
        "UUID": ASK_INPUT_UUID,
        "CustomOutputName": "User Input",
        "WFAskActionPrompt": "What's on your mind?",
        "WFInputType": "Text",
    },
})

# ── Step 2: Main menu ──────────────────────────────────────────────────────────
MAIN_MENU_ITEMS = [
    "🤖 Ask Claude",
    "📋 Copy to Clipboard",
    "✏️ Transform Text",
    "🔍 Search Web",
    "✉️ Send Message",
    "📧 Send Email",
    "✅ Add to Things 3",
]
actions.append(menu_begin(MAIN_MENU_UUID, MAIN_MENU_ITEMS, "Choose an action"))


# ────────────────────────────────────────────────────────────────────────────────
# Case: 🤖 Ask Claude
# ────────────────────────────────────────────────────────────────────────────────
actions.append(menu_case(MAIN_MENU_UUID, "🤖 Ask Claude"))

actions.append(ask_claude_action(
    ASK_CLAUDE_UUID,
    "Claude Response",
    token_attachment(ASK_INPUT_UUID, "User Input"),
))

actions.append(show_result(token_attachment(ASK_CLAUDE_UUID, "Claude Response")))


# ────────────────────────────────────────────────────────────────────────────────
# Case: 📋 Copy to Clipboard
# ────────────────────────────────────────────────────────────────────────────────
actions.append(menu_case(MAIN_MENU_UUID, "📋 Copy to Clipboard"))

actions.append({
    "WFWorkflowActionIdentifier": "is.workflow.actions.setclipboard",
    "WFWorkflowActionParameters": {
        "WFInput": token_attachment(ASK_INPUT_UUID, "User Input"),
    },
})

actions.append(show_result("✅ Copied to clipboard!"))


# ────────────────────────────────────────────────────────────────────────────────
# Case: ✏️ Transform Text  (nested submenu)
# ────────────────────────────────────────────────────────────────────────────────
actions.append(menu_case(MAIN_MENU_UUID, "✏️ Transform Text"))

TRANSFORM_ITEMS = ["📝 Summarize", "✍️ Rewrite", "• Bullet Points"]
actions.append(menu_begin(TRANSFORM_MENU_UUID, TRANSFORM_ITEMS, "Transform as…"))

# ── Sub-case: 📝 Summarize ─────────────────────────────────────────────────────
actions.append(menu_case(TRANSFORM_MENU_UUID, "📝 Summarize"))

actions.append(text_action(
    SUMMARIZE_TEXT_UUID,
    "Summarize Prompt",
    token_string(
        "Summarize the following text concisely:\n\n",
        ASK_INPUT_UUID, "User Input",
    ),
))

actions.append(ask_claude_action(
    SUMMARIZE_OUT_UUID,
    "Summary",
    token_attachment(SUMMARIZE_TEXT_UUID, "Summarize Prompt"),
))

actions.append(show_result(token_attachment(SUMMARIZE_OUT_UUID, "Summary")))

# ── Sub-case: ✍️ Rewrite ───────────────────────────────────────────────────────
actions.append(menu_case(TRANSFORM_MENU_UUID, "✍️ Rewrite"))

actions.append(text_action(
    REWRITE_TEXT_UUID,
    "Rewrite Prompt",
    token_string(
        "Rewrite the following text to be clearer and more polished:\n\n",
        ASK_INPUT_UUID, "User Input",
    ),
))

actions.append(ask_claude_action(
    REWRITE_OUT_UUID,
    "Rewritten Text",
    token_attachment(REWRITE_TEXT_UUID, "Rewrite Prompt"),
))

actions.append(show_result(token_attachment(REWRITE_OUT_UUID, "Rewritten Text")))

# ── Sub-case: • Bullet Points ──────────────────────────────────────────────────
actions.append(menu_case(TRANSFORM_MENU_UUID, "• Bullet Points"))

actions.append(text_action(
    BULLETS_TEXT_UUID,
    "Bullets Prompt",
    token_string(
        "Convert the following text into concise bullet points:\n\n",
        ASK_INPUT_UUID, "User Input",
    ),
))

actions.append(ask_claude_action(
    BULLETS_OUT_UUID,
    "Bullet Points",
    token_attachment(BULLETS_TEXT_UUID, "Bullets Prompt"),
))

actions.append(show_result(token_attachment(BULLETS_OUT_UUID, "Bullet Points")))

# End Transform submenu
actions.append(menu_end(TRANSFORM_MENU_UUID))


# ────────────────────────────────────────────────────────────────────────────────
# Case: 🔍 Search Web
# ────────────────────────────────────────────────────────────────────────────────
actions.append(menu_case(MAIN_MENU_UUID, "🔍 Search Web"))

actions.append(text_action(
    SEARCH_TEXT_UUID,
    "Search URL",
    token_string(
        "https://www.google.com/search?q=",
        ASK_INPUT_UUID, "User Input",
    ),
))

actions.append({
    "WFWorkflowActionIdentifier": "is.workflow.actions.openurl",
    "WFWorkflowActionParameters": {
        "WFInput": token_attachment(SEARCH_TEXT_UUID, "Search URL"),
    },
})


# ────────────────────────────────────────────────────────────────────────────────
# Case: ✉️ Send Message
# ────────────────────────────────────────────────────────────────────────────────
actions.append(menu_case(MAIN_MENU_UUID, "✉️ Send Message"))

actions.append({
    "WFWorkflowActionIdentifier": "is.workflow.actions.sendmessage",
    "WFWorkflowActionParameters": {
        "WFSendMessageContent": token_attachment(ASK_INPUT_UUID, "User Input"),
        # Show compose sheet so the user can pick the recipient interactively
        "WFSendMessageActionShowComposeSheet": True,
    },
})


# ────────────────────────────────────────────────────────────────────────────────
# Case: 📧 Send Email
# ────────────────────────────────────────────────────────────────────────────────
actions.append(menu_case(MAIN_MENU_UUID, "📧 Send Email"))

actions.append({
    "WFWorkflowActionIdentifier": "is.workflow.actions.sendemail",
    "WFWorkflowActionParameters": {
        "WFSendEmailActionBody": token_attachment(ASK_INPUT_UUID, "User Input"),
        "WFSendEmailActionShowComposeSheet": True,
    },
})


# ────────────────────────────────────────────────────────────────────────────────
# Case: ✅ Add to Things 3
# ────────────────────────────────────────────────────────────────────────────────
actions.append(menu_case(MAIN_MENU_UUID, "✅ Add to Things 3"))

# URL-encode the input so special characters don't break the URL scheme
actions.append({
    "WFWorkflowActionIdentifier": "is.workflow.actions.urlencode",
    "WFWorkflowActionParameters": {
        "UUID": ENCODED_INPUT_UUID,
        "CustomOutputName": "Encoded Input",
        "WFInput": token_attachment(ASK_INPUT_UUID, "User Input"),
        "WFEncodeURLActionMode": "Encode",
    },
})

# Assemble the Things 3 URL
actions.append(text_action(
    THINGS_URL_UUID,
    "Things URL",
    token_string(
        "things:///add?title=",
        ENCODED_INPUT_UUID, "Encoded Input",
    ),
))

actions.append({
    "WFWorkflowActionIdentifier": "is.workflow.actions.openurl",
    "WFWorkflowActionParameters": {
        "WFInput": token_attachment(THINGS_URL_UUID, "Things URL"),
    },
})


# End main menu
actions.append(menu_end(MAIN_MENU_UUID))


# ── Shortcut metadata ──────────────────────────────────────────────────────────
# Icon color: orange (RGBA 0xFF6B0080-ish range used by Shortcuts)
# Glyph 59511 = lightning bolt symbol (standard in Shortcuts)
SHORTCUT = {
    "WFWorkflowActions": actions,
    "WFWorkflowClientVersion": "1140.2",
    "WFWorkflowHasOutputFallback": False,
    "WFWorkflowIcon": {
        "WFWorkflowIconStartColor": 4251798271,   # orange
        "WFWorkflowIconGlyphNumber": 59511,        # lightning bolt
    },
    "WFWorkflowImportQuestions": [],
    "WFWorkflowInputContentItemClasses": [],
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowName": "Omnibutton",
    "WFWorkflowNoInputBehavior": {
        "Name": "WFWorkflowNoInputBehavior",
        "Parameters": {"Name": "WFWorkflowNoInputBehaviorAsk"},
    },
    "WFWorkflowOutputContentItemClasses": [],
    "WFWorkflowTypes": [],
}


# ── Write output ───────────────────────────────────────────────────────────────

def build_shortcut(output_path: str) -> None:
    plist_bytes = plistlib.dumps(SHORTCUT, fmt=plistlib.FMT_BINARY)
    with gzip.open(output_path, "wb") as fh:
        fh.write(plist_bytes)
    size = os.path.getsize(output_path)
    print(f"[OK] Written: {output_path}  ({size:,} bytes, {len(actions)} actions)")


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(__file__), "Omnibutton.shortcut")
    build_shortcut(out)
