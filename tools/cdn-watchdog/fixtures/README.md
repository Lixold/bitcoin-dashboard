# Captured payloads

What the CDN actually served, values untouched — a capture, not an
invention. Re-capture into a new dated directory rather than editing
these; a test that asserts on an age pins `now` to the capture instead.

`cdn-2026-09-13/` — fetched 2026-09-13 at 20:23 UTC:

```bash
for f in market history-1D history-1W history-1M history-3M history-1Y \
         fx-rates news-en news-de network-health; do
  curl -sS -o "$f.json" "https://data.bitcoin-dashboard.app/data/$f.json"
done
```

Nine of the ten pass every threshold in `../payloads.js`. `network-health.json`
does not, and that is why it was kept: it carries a `_meta.fetchedAt` well
inside its 26-hour window and a `fullNodes.count` of `null` — #29's
breakage, fixed in #101 but not yet deployed when the capture was taken.
It is the only real specimen of #43's second failure mode in the set.
