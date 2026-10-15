# ADR 0005 — Regression tests on local Tart VMs, driven by shell and expect

- **Status:** Accepted (2026-10-15)
- **Date:** 2026-10-15

## Context

Provisioning can only really be tested on a clean Mac. Task 13 did that once by hand with Tart and some throwaway scripts. Changes will now come in batches, and each batch needs a regression pass over both profiles (`0.1.0_TEST_SUITE.md`). Part of the setup can't be automated: the GitHub device-code login, creating the push token, and checking how iTerm looks. Christopher is fine doing those in the VM's window as long as the suite guides each step and checks the result.

Constraints from the project: shell and YAML only (no Ruby), no secrets in the public repo, Apple Silicon.

## Options considered

| | **Tart VMs on this Mac** | GitHub Actions macOS runners | Temp `$HOME` on the host only | UTM / manual VMs |
|---|---|---|---|---|
| Clean machine | Yes, per run | Yes, but preloaded with Homebrew and CLT | No (host's Homebrew, Keychain, apps) | Yes |
| Scriptable | CLI: clone, run, ip, delete; OCI images pinned by digest | Yes | Yes | Mostly GUI |
| Guided GUI steps | VM window on the host | No GUI | n/a | Yes |
| Cost / setup | Already installed (task 13); ~30 GB image | Free minutes, but no nested VMs and no person in the loop | None | Manual image setup |

For answering the first-run questions: `expect` (preinstalled; already worked in task 13) vs `script` with FIFOs (fragile) vs non-interactive answers through `--promptString`/config fixtures (skips the real prompts, which are part of what's being tested).

## Decision

Tart VMs on this Mac, from a vanilla Sequoia image pinned by digest. Shell scripts under `test/`, with `expect` only where a real terminal conversation is needed: the first-run questions and the TTY cases of the script tests. Host checks with stubs cover what doesn't need a VM. Guided steps run in the VM's Terminal app, so the login Keychain is the real one.

## Consequences

- Runs only on an Apple Silicon Mac with Tart. Each run takes tens of minutes plus disk for the clones. `--fast` (a cached image with Homebrew) trades realism for speed.
- At most two VMs at once, a macOS virtualization limit.
- A guided run creates real GitHub credentials (a gh OAuth grant, a 1-day fine-grained token). The suite prints how to revoke them, but revoking is manual.
- Not covered: GitHub Enterprise, MDM, CrowdStrike, the corporate network. These stay on the work laptop checklist.
- Revisit if GitHub-hosted runners gain nested virtualization, or if the Tart license terms change for this use.
