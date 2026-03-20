# Thunder MVP Release Checklist

- `dune build`
- `dune runtest`
- `bash scripts/check_mli.sh`
- docs reviewed (`README.md`, architecture/deployment/features)
- `KICKSTART.md` reviewed against the actual first-app flow
- `scripts/install_thunder.sh` validated
- `.github/workflows/release-artifacts.yml` validated
- `thunder doctor` validated after install
- examples compile and smoke tests pass
- preview publish flow validated (changed + unchanged artifact paths)
- preview smoke run validated for the default JS runtime path
- preview smoke run validated for the explicit Wasm runtime path
- production deploy confirmation guard verified
- installed-binary generated app flow validated (`thunder new`, `dune build @worker-build`, `THUNDER_COMPILE_TARGET=wasm dune build @worker-build`, plain `dune build`)
- release assets published with binaries, framework bundle, and `checksums.txt`
