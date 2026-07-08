# Recording the hero demo

The README's opening transcript should exist as a real GIF before launch. Two ways:

## Option A: vhs (reproducible)
Install [vhs](https://github.com/charmbracelet/vhs) (`brew install vhs`), prepare a
demo scope, then `vhs demo/hero.tape`. Edit the tape's sleeps to taste.

## Option B: real recording (more honest, recommended)
Record an actual terminal (QuickTime or `asciinema rec`), then convert to GIF
(`agg` for asciinema casts). Script to follow, two takes:

Take 1 (Monday):
  grandma demo-acme
  > we use pnpm here, never yarn. and never push to main directly.
  wait for the ✓ noted line, exit.

Take 2 (Thursday, fresh session):
  grandma demo-acme
  > set up the new billing service
  capture the moment it says pnpm + PR on its own.

Trim to 30 seconds max. The ✓ noted line and the Thursday callback are the money shots.
Keep the mascot splash in frame at the start of take 2.
