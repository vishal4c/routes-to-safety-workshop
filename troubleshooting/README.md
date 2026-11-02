# Troubleshooting

Start with the quick table in the main README, [If something is red](../README.md#if-something-is-red). The pages here
go further: what each symptom means, how to confirm it, and the fix.

| Page | When |
|---|---|
| [`phase4.md`](phase4.md) | adapting the workshop to another box (Phase 4): empty shelters, a stale routing graph, a broken tile archive, a pin in the wrong place |

## First, one command

Phase 4 has a checker that tests every output against the box in `versions.env` and names the step to redo:

```bash
scripts/check-phase4.sh
```
It runs in the container shell (option C: export `OSRM_URL` and `WEB_URL` first). Fix the first red line, run it again,
repeat until it ends with `All Phase 4 checks passed.`

## What to collect before asking for help

- Which option: A (Codespaces), B (Docker on the laptop) or C (native).
- The four `BBOX_*` lines of `versions.env`.
- The output of `scripts/check-phase4.sh` (or `python3 setup/check_setup.py` before Phase 4).
- The exact error text. For the map page, the browser console (F12) and, in the Network tab, the failing request's URL and status.
