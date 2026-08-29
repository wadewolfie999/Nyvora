# Nyvora architectural baseline adoption

## Authority

On 30 August 2026, the owner directed that the newly authored
`Nyvora-Architectural-Baseline-v1.0.docx` be treated as the authoritative
architectural baseline, with its versioning and stale metadata interpreted
forgivingly. The corrected repository edition is:

`architecture/NYVORA-Architectural-Baseline-v1.0.1-corrected.docx`

This DOCX has higher architectural authority than pre-existing repository
files. Those files are preserved as implementation and historical context;
they are not silently treated as current when they conflict with the DOCX.

## Corrected semantic points

- GitHub is the durable desired-state plane and sole forge; Radicle is removed
  from the required control path and retained only as historical context.
- The owner identity is normalized to Vahid (`vahid`); `wade` remains an
  observed host/account alias where it appears in historical evidence.
- ASUS is the normal execution coordinator for assigned environments and the
  compute host; VPS provides edge and continuity functions; Mac is the
  high-trust owner plane and is not a routine runtime dependency.
- Runtime writer authority is distinct from owner authority, GitHub desired
  state, PostgreSQL runtime state, NATS transport, and evidence storage.
- Handoffs require predeclared policy plus fencing or proven lease expiry; no
  node may self-elect during ambiguity.
- GitHub-outage continuity is limited to verified, signed, unexpired cached
  material and already issued valid action envelopes. It cannot accept new
  intent or desired state.
- Emergency safety stops and identity revocations are explicit break-glass
  exceptions to forward-action envelopes; they cannot authorize resumption.
- Architecture adoption is separate from AB-0–AB-8 implementation evidence.

## Scope boundary

This record and the corrected DOCX authorize baseline adoption and planning
only. They do not authorize live deployment, credential rotation, network or
firewall changes, service changes, production mutation, Radicle operations, or
operational qualification. AB-0 is the next stage; no AB stage is claimed
complete by this record.

## Evidence

- Original source: `/Users/vaheedgorgeen/Downloads/Nyvora-Architectural-Baseline-v1.0.docx`
- Original SHA-256: `e7804e1523e3623835dab2805b3fce5c5a7e7e27312b3964ebcd3efd897caeb5`
- Corrected SHA-256: `f454cae6d5a94ff61c5fdee1b6ea1411cf5b27a6dd596e22ed249d306cf49e4b`
- Original source file was not modified.
