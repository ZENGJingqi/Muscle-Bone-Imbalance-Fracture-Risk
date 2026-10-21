# Snapshot and citation status

The 21 October 2026 update uses metadata version `0.3.1-dev`. It is a Git development snapshot, not a tagged version, formal GitHub Release or archived DOI.

It adds the reviewed validation code, four aggregate validation tables, statistical environment and provenance. Together with the unchanged original outputs, `public_data/` contains 18 CSVs. The updated study-design PDF matches the retained native figure; earlier PNGs are historical previews. Manuscripts and participant-level data are not published here.

## Citation

In the manuscript, cite the exact containing commit rather than the moving `main` branch. Record its full SHA and access date. The reference should identify this as analysis code and aggregate results in a GitHub development snapshot; do not describe it as a journal article or assign a DOI that does not exist. CITATION.cff identifies the known maintainer, not a confirmed manuscript author list.

The previous source snapshot was commit `288cf99ae2526c1253b63fe0819a327e47556738`. Original statistical estimates and 14 aggregate CSVs remain byte-identical. The new code and four CSVs retain the reviewed October 10 extension bytes.

## Before a future formal release

Confirm contributor names, rights and any software license with the authors and rights holders. Source-data access terms remain with the original providers. A formal Release, tag or DOI requires a separate action; none is implied by this update. Do not mix legacy component definitions or older threshold results with the canonical `code/Publication` entries.
