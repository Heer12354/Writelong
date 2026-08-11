# Writelong - Privacy & Permissions

Writelong is a local macOS typing assistant. Its model inference runs on the Mac; the app does not
send captured writing to a Writelong server.

## Permissions

| Permission | Why Writelong requests it | Optional? | What happens without it |
| --- | --- | --- | --- |
| Accessibility | Reads the focused text field and caret position so a local model can prepare a completion. | No for system-wide completions. | Writelong cannot offer live completion in other apps. |
| Input Monitoring | Detects the configured acceptance shortcut, such as Tab. | No for global shortcut acceptance. | A completion cannot be accepted through Writelong's global shortcut. |
| Screen Recording | Reads visible on-screen text for OCR context and can calibrate the overlay. | Yes; both features are off by default. | Normal focused-field completion continues without OCR or screenshot calibration. |

Accessibility is a system-wide macOS grant, not a per-app grant. Writelong limits its own use of
that access to the completion pipeline and suppresses completion in secure/password fields and
configured unsupported targets. The macOS grant itself cannot be narrowed by Writelong.

## Local data controls

- **Writing history:** Optional personalization data is encrypted locally. It is enabled on new
  installs and can be disabled in Settings.
- **Clipboard context:** Optional prompt context, read locally. It is enabled on new installs and
  can be disabled in Settings.
- **OCR and screenshots:** Both are opt-in and require Screen Recording.
- **Developer prompt log:** Disabled by default. When enabled for debugging, it can contain prompt
  and completion content; do not enable it with sensitive text.
- **Context diagnostics:** The normal macOS diagnostic log records only structural metadata such as
  text lengths, geometry availability, and detected flags - never field text, labels, window title,
  or domain.

Use **Settings > Privacy > Clear all personal data** to delete stored writing history and local
telemetry. Disabling a switch stops that source from being included in future prompts.

## Limits and honest comparisons

Local inference does not remove the sensitivity of Accessibility access. Users who do not want to
grant it should not enable system-wide completion. Writelong does not currently provide a
reduced-functionality mode without Accessibility.

This document intentionally does not claim that Writelong needs fewer permissions than another
product. Permission requirements change; any product comparison should be verified against the
other product's current official documentation before publication.
