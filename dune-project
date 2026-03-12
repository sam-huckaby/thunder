(lang dune 3.13)
(name thunder)
(generate_opam_files false)
(using directory-targets 0.1)

(package
 (name thunder_core)
 (synopsis "Thunder core primitives"))

(package
 (name thunder_http)
 (synopsis "Thunder HTTP primitives"))

(package
 (name thunder_router)
 (synopsis "Thunder router"))

(package
 (name thunder_worker)
 (synopsis "Thunder Cloudflare Worker adapter"))

(package
 (name thunder)
 (synopsis "Thunder top-level API"))

(package
 (name thunder_cli)
 (synopsis "Thunder deployment CLI"))
