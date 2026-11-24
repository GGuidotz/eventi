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
