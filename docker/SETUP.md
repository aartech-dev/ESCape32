# Setup

One-time setup to get the build-and-release pipeline running in your firmware
fork repo (the repo with your own Makefile and the various Remora target configs).

## 1. Place these files in your firmware repo

```
your-firmware-repo/
├── docker/
│   ├── Dockerfile          <- from escape32-builder/Dockerfile
│   └── build.sh            <- from escape32-builder/build.sh (local use, optional in repo)
└── .github/
    └── workflows/
        ├── build-image.yml
        └── release.yml
```

The `docker/` path matters: `build-image.yml` builds from `context: ./docker`
and only re-triggers when `docker/Dockerfile` changes — so it stays decoupled
from how often you push firmware code.

## 2. Create the two release repos

Using the `gh` CLI (replace names with whatever you actually want to call them):

```bash
gh repo create YOUR_USER/remora-firmware-internal --private --description "Internal/test Remora firmware builds"
gh repo create YOUR_USER/remora-firmware --public --description "Remora firmware releases"
```

If you'd rather create them via the GitHub UI instead, that's equivalent — the
workflow only needs `owner/repo` strings to publish releases into.

## 3. Create a PAT for cross-repo releases

The default `GITHUB_TOKEN` a workflow gets can only act on the repo it's running
in, so creating releases in your two *other* repos needs a Personal Access Token.

- GitHub -> Settings -> Developer settings -> Personal access tokens -> Fine-grained tokens -> Generate new token
- Resource owner: yourself (or your org, if these live under one)
- Repository access: **Only select repositories** -> pick exactly the private and public release repos (not the firmware source repo)
- Permissions: **Contents: Read and write** (this alone covers creating releases)
- Generate, copy the token

Add it as a secret in your **firmware source repo**:
- Settings -> Secrets and variables -> Actions -> New repository secret
- Name: `RELEASE_PAT`
- Value: the token

## 4. Set up the public-release approval gate

- In the firmware source repo: Settings -> Environments -> New environment -> name it `public-release`
- Under "Deployment protection rules", add yourself (and Richard, if you want him able to approve too) as required reviewers

With this in place, every push to `main` builds and auto-publishes to the
private repo immediately, but the public-repo job pauses in the Actions tab
waiting for an approval click before anything goes out publicly.

## 5. Edit the placeholders

Three files have `OWNER`/repo-name placeholders to fill in with your actual values:

- `docker/build-image.yml` -> the `tags:` line (GHCR image name, must be lowercase)
- `docker/release.yml` -> `BUILDER_IMAGE`, `PRIVATE_REPO`, `PUBLIC_REPO` at the top
- `docker/release.yml` -> the artifact-collection glob in the "Collect artifacts" step. It currently grabs every `.bin`/`.hex` anywhere in the repo, mirroring upstream's layout — adjust if your own Makefile puts output somewhere specific (e.g. a single `out/` or `dist/` directory) so it doesn't accidentally pick up unrelated files.

## 6. First run

1. Push the `docker/Dockerfile` to `main` — this triggers `build-image.yml` and publishes the image to GHCR (check the repo's Packages tab to confirm it landed).
2. Push a firmware change to `main` — this triggers `release.yml`: builds via the now-published image, creates the private release immediately, and leaves the public release waiting in Actions for your approval.

## Upstream change notifications (no setup needed)

On `neoxic/ESCape32`: Watch (top right) -> Custom -> tick "Releases" only. You'll
get notified whenever a new tagged release lands upstream, without watching
every commit.
