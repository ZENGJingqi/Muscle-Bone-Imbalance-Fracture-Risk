# Snapshot and citation status

The 23 October 2026 submission sync uses metadata version `0.3.2-dev`. It is a Git development snapshot, not a tagged version, formal GitHub Release or archived DOI.

The four canonical R entry points and all 18 aggregate CSVs are unchanged from the reviewed 21 October snapshot. This sync updates the study-design PDF to the frozen submission figure, documents the scope of the historical Chinese subgroup summaries, corrects an unsupported legacy data-license statement, and records file-level provenance. Earlier PNGs are historical previews. No fresh model fitting, manuscript files or participant-level records are included.

## Citation

In the manuscript, cite the exact containing commit rather than the moving `main` branch. Record its full SHA and access date. The reference should identify this as analysis code and aggregate results in a GitHub development snapshot; do not describe it as a journal article or assign a DOI that does not exist. CITATION.cff identifies the known maintainer, not a confirmed manuscript author list.

The previous public snapshot was commit `92133749393c199440334a256fc1fd8b02184da0`, which added the reviewed October 10 validation extension to `288cf99ae2526c1253b63fe0819a327e47556738`. All 18 CSVs and four R entry points retain those reviewed bytes. The containing commit, rather than the descriptive metadata version, is the reproducible citation target.

## Before a future formal release

Confirm contributor names, rights and any software license with the authors and rights holders. Source-data access terms remain with the original providers. A formal Release, tag or DOI requires a separate action; none is implied by this update. Do not mix legacy component definitions or older threshold results with the canonical `code/Publication` entries.
