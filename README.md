# Healthy Mind Living — Calm Space

A single-file, mobile-first web app for a solo psychology practice: a private "calm space" between sessions for clients (daily check-ins, guided worksheets, messaging, appointment requests) and a dashboard for the clinician (client list, progress charts, messaging, scheduling, client reports).

## Status: prototype

This is a **demo/prototype**, not a production clinical system. In demo mode all data is stored only in the visitor's own browser (`localStorage`) — nothing is shared between devices or visible to anyone else. There is no real login and no real database yet.

A separate architecture doc (not in this repo) covers the full architecture, security, and launch-readiness plan this prototype is based on — including what's required before any real patient data can be used (Supabase backend, real authentication, backups, privacy review, etc).

## Running locally

It's a single static HTML file with no build step. Open `index.html` directly in a browser, or serve the folder with any static file server.

## Deployment

Deployed for free via GitHub Pages from this repository.
