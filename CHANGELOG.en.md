## 0.2.1 · 2026-11-24

A new look: the shapes, colors and motion of Sguardo, the design system shared by our apps.

### New features
- **Accent color of your choice.** In Settings › Appearance: the Eventi violet, the macOS accent color, or your own.

### Improvements
- **Redesigned main window.** The text and the events sit on translucent cards with a thin outline; buttons are capsules and only one action stands out: "Extract events" first, "Save .ics…" once there are events. Each event has softer fields and switches instead of checkboxes.
- **Settings in the same style.** Grouped rows, capsule menus, engine status with a green or orange mark and a note below.
- **Builds from a clone.** Sguardo comes with `git clone --recursive`: building from source has everything it needs.

## 0.2.0 · 2026-11-16

Travel documents are read with rules: flights and hotels with correct local times.

### New features
- **Travel.** Flights (departure and arrival in each airport's time zone) and hotel check-in/check-out from tickets, itineraries and vouchers, with a description (PNR, ticket, passenger, baggage, voucher).
- **One file per event.** Save each event as a numbered .ics, besides the single file.
- **Description.** Events have an editable description field; the file includes status and availability.

### Bug fixes
- **Titles.** Removed leftover words about the end time.

## 0.1.0 · 2026-11-16

First version: drop a text or a document and get the events as an .ics file.

### New features
- **Event extraction.** Title, place, date, start and end time from text, PDF, images (OCR), Word, RTF, HTML and email.
- **Two on-device engines.** Apple Intelligence and Gemma 1B (the model already installed for Cotypist), with rules as a fallback and as a check on dates and times.
- **Export.** Save an .ics file or open it directly in Calendar; edit every event first.
