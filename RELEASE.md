

A GitHub Actions workflow is an automated process that you add to your repository. It allows you to automatically build, test, package, release, or deploy your code whenever something happens in your repository (like a code push or a pull request).

Here is a breakdown of how the workflow architecture functions, followed by a practical example of how to invoke a standard `make` build.

---

## How a GitHub Workflow Works

GitHub Workflows are event-driven and configured using **YAML** files stored in a specific directory in your repository: `.github/workflows/`.

The architecture relies on four core concepts:

1. **Events (Triggers):** An event is a specific activity that triggers the workflow. Examples include pushing code to a branch, opening a pull request, or a manual trigger.
2. **Jobs:** A workflow is made up of one or more jobs. By default, multiple jobs run in parallel, though you can configure them to depend on one another. Crucially, each job runs inside its own fresh virtual machine (called a **Runner**), such as `ubuntu-latest` or `macos-latest`.
3. **Steps:** A job contains a sequence of tasks called steps. Steps are executed in order, one after the other, on the same runner.
4. **Actions / Commands:** A step can either run a pre-built **Action** (a reusable script, like checking out your repository or setting up a compiler) or run a standard **shell command** (like executing a script or running `make`).

---

## Invoking a Build from `make`

To run a `make` build, your workflow runner needs to do two things first: fetch your repository's files and ensure that `make` (along with any necessary compilers or toolchains) is installed. Because GitHub's default Linux runners (`ubuntu-latest`) come pre-installed with standard build essentials like `make`, `gcc`, and `g++`, you usually don't have to install them manually.

### The Workflow Configuration

Create a file named `.github/workflows/build.yml` in your repository and paste the following configuration:

```yaml
name: Build Project

# 1. Define when this workflow should run
on:
  push:
    branches: [ "main", "development" ]
  pull_request:
    branches: [ "main" ]
  workflow_dispatch: # Allows you to manually click a button in GitHub to run it

# 2. Define the execution jobs
jobs:
  compile:
    name: Execute Makefile Build
    runs-on: ubuntu-latest # Runs on a fresh Linux virtual machine

    steps:
      # Step 1: Clone the repository files onto the runner
      - name: Checkout Code
        uses: actions/checkout@v4

      # Step 2: (Optional) If your Makefile depends on specific tools, install them here
      # For standard C/C++ builds, ubuntu-latest already has make/gcc installed.

      # Step 3: Run the compile target
      - name: Run Makefile Build
        run: |
          make

      # Step 4: (Optional) Run your test target if you have one
      - name: Run Tests
        run: make test

```

### Breaking Down the `make` Invocation:

* **`uses: actions/checkout@v4`**: This is a critical first step. It clones your repository onto the virtual machine so the runner can actually see your `Makefile` and source code.
* **`run: make`**: The `run` keyword tells the runner to execute a command in its local shell. Because the runner starts in the root directory of your cloned repository, executing `make` will automatically look for your root `Makefile` and run the default target.
* **Target Specifics:** If your build target is named something specific (like `make build` or `make release`), you simply change the command line to match:
```yaml
run: make release

```

To handle the outputs generated inside your `build` directory (like compiled binaries, `.hex` files, libraries, or firmware), you have two distinct options depending on what you intend to do with them.

---

## Option 1: Store them as a "Workflow Artifact" (Best for Internal Testing)

If you just want to download the compiled outputs directly from the GitHub Actions run page to test them locally (without creating a formal, public-facing project release), use the official `actions/upload-artifact` action.

Add this step right after your `make` step:

```yaml
      - name: Run Makefile Build
        run: make

      # NEW: Upload everything inside the build folder
      - name: Save Build Outputs
        uses: actions/upload-artifact@v4
        with:
          name: compiled-build-artifacts
          path: build/ # Uploads the entire contents of your build directory
          retention-days: 5 # Optional: automatically deletes it after 5 days to save space

```

---

## Option 2: Create a Formal "GitHub Release" (Best for Public Distribution)

If you want to bundle those build outputs and attach them directly to a public GitHub Release (e.g., `v1.0.0`) whenever you push a new git tag, you can automate that using the popular `softprops/action-gh-release` action.

### 1. Give the Workflow Write Permissions

To let GitHub Actions create releases and attach files, you must explicitly grant write permissions at the top of your job.

### 2. The Complete Tag-Triggered Release Workflow

Update your workflow file to look like this. It is configured to run specifically when you push a version tag (like `v1.0.0` or `v2.1.4`):

```yaml
name: Build and Release

on:
  push:
    tags:
      - 'v*' # Triggers the workflow only when you push a tag starting with "v"

jobs:
  release-project:
    runs-on: ubuntu-latest
    
    # CRITICAL: Gives the runner permission to create a GitHub Release
    permissions:
      contents: write 

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Run Makefile Build
        run: make

      # Zip or Tar your build directory so it's a single clean download for users
      - name: Archive Build Directory
        run: |
          tar -czvf project-build-${{ github.ref_name }}.tar.gz -C build .

      # Create the official Release and upload the zipped outputs
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          name: Release ${{ github.ref_name }}
          draft: false
          prerelease: false
          files: |
            project-build-*.tar.gz

```

### How to trigger this release:

Once this YAML is committed to your repository, you trigger the release directly from your local terminal using standard Git commands:

```bash
git tag v1.0.0
git push origin v1.0.0

```

GitHub will instantly spin up the runner, execute your `Makefile`, compress your `build/` directory, create a formal release page, and attach the `.tar.gz` file as a downloadable asset.