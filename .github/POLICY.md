# `.github/` — CI, ownership, and repository policy for QSOC

> This file is **`POLICY.md`, not `README.md`, on purpose.** GitHub prefers
> `.github/README.md` over the one at the repository root, so naming it README
> made the landing page show the CI policy instead of what QSOC is. The root
> [`README.md`](../README.md) describes the chip; this file describes how the
> repository is governed.

This directory holds everything about *how the repo is governed*, not what it
builds. It is owned by `@quynhonsemiconductor/vlsi-maintainers` (see
[`CODEOWNERS`](CODEOWNERS)) because a change here can weaken a required check or
a review rule for every block at once.

## What is here

| File | Purpose |
|------|---------|
| `CODEOWNERS` | Per-directory review requirements. Enforced by the `main-protection` ruleset. |
| `labels.yml` | Source of truth for the label set. |
| `labeler.yml` | Maps file paths to labels. Every label it names must exist in `labels.yml`. |
| `workflows/pr-title.yml` | PR title must be a Conventional Commit. Its own workflow — see the header comment for why. |
| `workflows/rtl-ci.yml` | The RTL checks: lint, filelist paths, generated wrappers, naming, hardcoded values, contract, vendor guard, docs. Every step calls a target of the root `Makefile`. |
| `workflows/labeler.yml` | Applies path labels via the org's shared CI. |
| `workflows/security.yml` | Pins/audits the GitHub Actions this repo calls. |

The scripts the RTL workflow calls live in [`../flow/`](../flow) and
[`../util/`](../util); `make help` lists them.

## Bootstrap (run once, by a maintainer)

These are not applied by committing a file — labels and rulesets live in
GitHub's own state, so they are created with the CLI. Run from the repo root.

### 1. Create the labels

Labels must exist before the labeler can apply them. Using
[`github-label-sync`](https://github.com/Financial-Times/github-label-sync):

```bash
npx github-label-sync --access-token "$GH_TOKEN" \
  --labels .github/labels.yml \
  quynhonsemiconductor/vlsi_deep_training
```

`--dry-run` first to see the diff. Re-run this whenever `labels.yml` changes;
it reconciles the repo to the file (including deletes, so review the dry run).

### 2. Confirm the two teams have access

CODEOWNERS entries that name a team without repo access match nothing, which
makes the required review *unsatisfiable* — the PR blocks with no way to
proceed. Confirm both teams are added:

```bash
gh api orgs/quynhonsemiconductor/teams/vlsi-maintainers/repos/quynhonsemiconductor/vlsi_deep_training
gh api orgs/quynhonsemiconductor/teams/vlsi-devs/repos/quynhonsemiconductor/vlsi_deep_training
```

`vlsi-maintainers` needs at least `push` (write) to be a valid code owner;
`vlsi-devs` needs `push` to open branches. To grant:

```bash
gh api -X PUT orgs/quynhonsemiconductor/teams/vlsi-maintainers/repos/quynhonsemiconductor/vlsi_deep_training -f permission=maintain
gh api -X PUT orgs/quynhonsemiconductor/teams/vlsi-devs/repos/quynhonsemiconductor/vlsi_deep_training         -f permission=push
```

### 3. Create the `main-protection` ruleset

Same model as rova: PRs required, no direct push to `main`, code-owner review
required, and the CI checks required. Rulesets are the newer replacement for
classic branch protection and are what the org already uses.

Save this as `main-protection.json`. This mirrors rova's `main-protection`
ruleset (the org standard) field for field; only the `required_status_checks`
contexts differ, because this repository runs RTL checks rather than rova's
web/backend checks.

```json
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "require_code_owner_review": true,
        "dismiss_stale_reviews_on_push": true,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "require_extra_approval_for_unattributed_changes": true,
        "allowed_merge_methods": ["squash", "rebase"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "do_not_enforce_on_create": true,
        "required_status_checks": [
          { "context": "PR title (conventional commits)" },
          { "context": "Verilator lint" },
          { "context": "Vendor tree unmodified" },
          { "context": "Specifications build and check" },
          { "context": "actions-security / Workflow lint (actionlint)" },
          { "context": "actions-security / Actions security (zizmor)" },
          { "context": "RTL naming rule" },
          { "context": "Inter-block contract" },
          { "context": "No hardcoded shared values" },
          { "context": "Filelist paths" },
          { "context": "Generated wrappers" }
        ]
      }
    }
  ],
  "bypass_actors": [
    { "actor_type": "RepositoryRole", "actor_id": 5, "bypass_mode": "always" }
  ]
}
```

Then:

```bash
gh api -X POST repos/quynhonsemiconductor/vlsi_deep_training/rulesets \
  --input main-protection.json
```

Notes:
- The `context` strings **must** byte-match how each check reports. Direct jobs
  report as their `name:` (`Verilator lint`). A job that calls a reusable
  workflow reports as `<caller job id> / <inner job name>` — which is why
  `security.yml`'s job is deliberately named `actions-security`, so its checks
  read the same as every other repo in the org.
- `~DEFAULT_BRANCH` tracks whatever the default branch is, rather than pinning
  the literal `main` — matches rova.
- `allowed_merge_methods: ["squash", "rebase"]` forbids merge commits, keeping a
  linear history — matches rova.
- `actor_id: 5` is the built-in **Admin** role. rova uses `bypass_mode: always`;
  for the strictest setup use `pull_request` (bypass only via a PR) or drop the
  `bypass_actors` block entirely.
- To require a maintainer specifically on `design/**`, that is already handled
  by CODEOWNERS + `require_code_owner_review`, not by the ruleset.

Verify:

```bash
gh api repos/quynhonsemiconductor/vlsi_deep_training/rulesets | jq '.[].name'
gh ruleset check --repo quynhonsemiconductor/vlsi_deep_training   # if gh version supports it
```

## Keeping the ruleset in step with CI

A new CI job is not a gate until its name is added to `required_status_checks`.
The live ruleset requires all eleven contexts above (checked 2026-09-25). When a
job is added to or renamed in a workflow, update the list here and in the ruleset
in the same change:

```bash
gh api repos/quynhonsemiconductor/vlsi_deep_training/rulesets --jq '.[] | "\(.id) \(.name)"'
gh api -X PUT repos/quynhonsemiconductor/vlsi_deep_training/rulesets/<id> --input main-protection.json
```
