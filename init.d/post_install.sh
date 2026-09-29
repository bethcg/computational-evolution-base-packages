#!/usr/bin/env bash
#
# post_install.sh
#
# Post-install steps for the Treponema_pallidum_in_early_modern_Europe
# environment (see environment.yml). Installs the two dependencies that
# cannot be expressed in environment.yml because they aren't on
# conda-forge or bioconda:
#
#   1. beastio  — custom R package (BEAST2 log parsing), GitHub-only,
#                 pinned to the commit the repo's README specifies.
#   2. treedater — CRAN package, used directly in reports/*.Rmd, but not
#                  currently packaged for conda.
#
# Usage:
#   conda env create -f environment.yml
#   ./post_install.sh                       # uses the default env name below
#   ./post_install.sh other-env-name        # or pass a different env name
#
set -euo pipefail

ENV_NAME="${1:-treponema-pallidum}"
BEASTIO_COMMIT="b18caa6"
BEASTIO_REPO="laduplessis/beastio"

echo "==> Post-install for conda environment: ${ENV_NAME}"

# --- Locate and activate the conda environment -----------------------------
if ! command -v conda >/dev/null 2>&1; then
  echo "ERROR: conda was not found on PATH. Activate/install conda first." >&2
  exit 1
fi

CONDA_BASE="$(conda info --base)"
# shellcheck source=/dev/null
source "${CONDA_BASE}/etc/profile.d/conda.sh"

if ! conda env list | awk '{print $1}' | grep -qx "${ENV_NAME}"; then
  echo "ERROR: conda environment '${ENV_NAME}' does not exist." >&2
  echo "       Create it first: conda env create -f environment.yml" >&2
  exit 1
fi

conda activate "${ENV_NAME}"
echo "==> Activated ${ENV_NAME} (R: $(R --version | head -n1))"

# --- 1. r-remotes (needed to install beastio from GitHub) ------------------
echo "==> Ensuring r-remotes is installed..."
if ! Rscript -e 'if (!requireNamespace("remotes", quietly = TRUE)) quit(status = 1)' >/dev/null 2>&1; then
  conda install -n "${ENV_NAME}" -y -c conda-forge r-remotes
fi

# --- 2. beastio, pinned to the commit the README specifies ------------------
echo "==> Installing beastio (${BEASTIO_REPO}@${BEASTIO_COMMIT})..."
Rscript -e "remotes::install_github('${BEASTIO_REPO}', ref = '${BEASTIO_COMMIT}', upgrade = 'never')"

# --- 3. treedater, from CRAN (not packaged for conda) -----------------------
echo "==> Installing treedater from CRAN..."
Rscript -e 'install.packages("treedater", repos = "https://cloud.r-project.org", dependencies = TRUE)'

# --- Verify both installed correctly ----------------------------------------
echo "==> Verifying installation..."
Rscript -e '
pkgs <- c("beastio", "treedater")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) {
  stop("Failed to install: ", paste(missing, collapse = ", "))
}
cat("OK: beastio", as.character(packageVersion("beastio")),
    "and treedater", as.character(packageVersion("treedater")),
    "are both installed.\n")
'

echo "==> Post-install complete. Environment '${ENV_NAME}' is ready."
