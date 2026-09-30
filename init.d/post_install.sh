#!/usr/bin/env bash
#
# post_install.sh
#
# Post-install steps for the Treponema_pallidum_in_early_modern_Europe
# environment (see environment.yml). Installs the two R dependencies that
# are not on conda-forge or bioconda:
#
#   1. beastio   — custom R package (BEAST2 log parsing), GitHub-only,
#                  pinned to the commit the repo's README specifies.
#   2. treedater — CRAN package, used in reports/*.Rmd.
#
# Works in three situations:
#   - a named conda env on a laptop:  ./post_install.sh treponema-pallidum
#   - an already-active env:          ./post_install.sh
#   - a RenkuLab session (any frontend: Python/Jupyter, RStudio, VS Code),
#     where the env is built by Renku, has no name, and `conda` may be absent.
#
set -eo pipefail   # no `set -u`: conda activation scripts reference unset variables
 
ENV_NAME="${1:-}"
BEASTIO_COMMIT="b18caa6"
BEASTIO_REPO="laduplessis/beastio"
CRAN="https://cloud.r-project.org"
 
log() { echo "==> $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }
 
# --- 1. Activate a named env only if one was requested and conda exists ----
if [[ -n "$ENV_NAME" ]]; then
  command -v conda >/dev/null 2>&1 || die "conda not found, but env '$ENV_NAME' was requested."
  # shellcheck source=/dev/null
  source "$(conda info --base)/etc/profile.d/conda.sh"
  conda activate "$ENV_NAME" || die "could not activate conda env '$ENV_NAME'."
fi
 
# --- 2. Find R (whatever is on PATH: conda env, Renku layer, or system) ----
command -v Rscript >/dev/null 2>&1 || die "Rscript not found on PATH.
       In RenkuLab, make sure environment.yml lists r-base (and r-essentials
       if you want the usual packages); the Python frontend does not add R."
log "Using R: $(command -v Rscript)  ($(R --version | head -n1))"
 
# --- 3. Make sure packages go into a writable library ----------------------
# Renku installs the environment into a read-only image layer at runtime,
# so fall back to a user library when the default one is not writable.
LIB="$(Rscript -e 'cat(.libPaths()[1])')"
if [[ ! -w "$LIB" ]]; then
  LIB="${RENKU_MOUNT_DIR:-$HOME}/R/library"
  mkdir -p "$LIB"
  export R_LIBS_USER="$LIB"
  log "Default R library is read-only; installing into $LIB"
  log "Add this line to ~/.Renviron so R finds it later:  R_LIBS_USER=$LIB"
  grep -qxF "R_LIBS_USER=$LIB" "$HOME/.Renviron" 2>/dev/null || echo "R_LIBS_USER=$LIB" >> "$HOME/.Renviron"
fi
export R_POST_LIB="$LIB"
 
# --- 4. Install remotes, beastio and treedater -----------------------------
log "Installing remotes, beastio@${BEASTIO_COMMIT} and treedater..."
Rscript - <<EOF
lib <- Sys.getenv("R_POST_LIB")
.libPaths(c(lib, .libPaths()))
options(repos = c(CRAN = "${CRAN}"))
 
if (!requireNamespace("remotes", quietly = TRUE))
  install.packages("remotes", lib = lib)
 
remotes::install_github("${BEASTIO_REPO}", ref = "${BEASTIO_COMMIT}",
                        upgrade = "never", dependencies = TRUE)
 
if (!requireNamespace("treedater", quietly = TRUE))
  install.packages("treedater", lib = lib, dependencies = TRUE)
 
pkgs <- c("beastio", "treedater")
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) stop("Failed to install: ", paste(missing, collapse = ", "))
cat("OK: beastio", as.character(packageVersion("beastio")),
    "and treedater", as.character(packageVersion("treedater")), "installed in", lib, "\n")
EOF
 
log "Post-install complete."
