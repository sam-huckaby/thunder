# Thunder MVP Release Checklist

- `dune build`
- `dune runtest`
- `bash scripts/check_mli.sh`
- docs reviewed (`README.md`, architecture/deployment/features)
- `KICKSTART.md` reviewed against the actual first-app flow
- examples compile and smoke tests pass
- preview publish flow validated (changed + unchanged artifact paths)
- preview smoke run validated for the single compiled-runtime path
- single compiled-runtime path verified in preview before release
- production deploy confirmation guard verified
