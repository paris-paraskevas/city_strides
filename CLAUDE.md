# City Strides

Personal project by Paris Paraskevas. Flutter app for walking/exploring city streets.

## Stack

- Flutter 3.x / Dart ^3.10.8
- State: Riverpod
- Maps: flutter_map + OpenStreetMap tiles
- Location: geolocator
- Data: Overpass API (OSM), Firestore
- Storage: shared_preferences, path_provider

## Architecture

```
lib/
  app.dart              # Root widget
  main.dart             # Entry point
  config/               # Constants, theme
  models/               # Data models (city, road_segment, user, etc.)
  providers/            # Riverpod providers (state management)
  screens/              # UI screens (auth, debug, home, map, onboarding, profile, stats)
  services/             # Business logic (auth, cache, firestore, location, overpass, road_matching)
  utils/                # Helpers
  widgets/              # Reusable widgets
```

## Brain Connection

This project is part of the Caduceus ecosystem. The Caduceus MCP server and Google Drive MCP are configured globally — they work here automatically.

- Session artifacts, decisions, and learnings get encoded to CLMEM via Caduceus MCP
- Knowledge lives in the caduceus repo (`C:\Dev\SKGT\caduceus\knowledge\`)
- This project's memory lives in `~/.claude/projects/C--Dev-Personal-city_strides/memory/`

## ESPA — Before Every Non-Trivial Action

1. **E — Evaluate** what is being asked
2. **S — Scrutinize** whether it's the best approach
3. **P — Present** concisely — conclusion + key steps
4. **A — Await** confirmation before executing

## Rules

- Git: branch before changes, never commit to main directly
- Git: stage specific files, never `git add -A`
- Never include "Co-Authored-By:" in commit messages
- Every user and Claude are equal partners
- Cleanup: never permanently delete — move to `.bin/` (30-day retention)
- Flutter: follow existing patterns (Riverpod providers, service layer separation)
- Keep `analysis_options.yaml` lints clean — no ignoring without reason
