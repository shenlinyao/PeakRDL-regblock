#!/usr/bin/env bash
#
# Release peakrdl (with the fork's peakrdl-regblock, incl. the built-in full
# AXI4 cpuif) into a versioned, self-contained virtualenv plus an Environment
# Modules modulefile, so other users can:
#
#     module use /home/leons/releases/modulefiles
#     module load peakrdl            # default (latest) version
#     module load peakrdl/1.3.1-axi4.1   # pinned version
#     peakrdl --help
#
# The venv contains:
#   - peakrdl-regblock  installed from THIS LOCAL REPO at --ref (git archive,
#                       never fetched from GitHub/PyPI)
#   - peakrdl, peakrdl-uvm, peakrdl-docx  from PyPI
# It also ships hdl-src/regblock_udps.rdl as <prefix>/share/regblock_udps.rdl
# (needed as first input file when RDL uses buffer_writes/buffer_reads).
#
# Usage:
#     scripts/release.sh --version 1.3.1-axi4.1 [--ref HEAD] [--root ~/releases] \
#                        [--no-default] [--force]
#
# Requires: git, /usr/bin/python3.12 (or $PEAKRDL_RELEASE_PYTHON), network to PyPI.

set -euo pipefail

ROOT="${PEAKRDL_RELEASE_ROOT:-$HOME/releases}"
PYTHON="${PEAKRDL_RELEASE_PYTHON:-/usr/bin/python3.12}"
REF="HEAD"
VERSION=""
PROMOTE_DEFAULT=1
FORCE=0

usage() {
    cat >&2 <<'USAGE'
Usage: release.sh --version X.Y.Z[-suffix] [options]

Options:
  --version X.Y.Z   Release version (required; becomes the modulefile version).
                    Note: '+' is legal but '-' reads better in module names,
                    e.g. 1.3.1-axi4.1 for package version 1.3.1+axi4.1.
  --ref REF         Git ref to release (tag, branch, or SHA). Default: HEAD.
  --root PATH       Release root. Default: $HOME/releases.
  --no-default      Do not promote this release to the module default.
  --force           Rebuild if the version directory already exists.
  -h, --help        Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) VERSION="$2"; shift 2 ;;
        --ref)     REF="$2";     shift 2 ;;
        --root)    ROOT="$2";    shift 2 ;;
        --no-default) PROMOTE_DEFAULT=0; shift ;;
        --force)   FORCE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage; exit 2 ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    echo "error: --version is required" >&2
    usage
    exit 2
fi

# Version may not contain characters that break a modulefile path.
if [[ ! "$VERSION" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
    echo "error: invalid version '$VERSION' (use letters, digits, '.', '_', '+', '-')" >&2
    exit 2
fi

if [[ ! -d .git ]]; then
    echo "error: run this from the repository root (the directory containing .git)" >&2
    exit 2
fi

if [[ ! -x "$PYTHON" ]]; then
    echo "error: python not found or not executable: $PYTHON" >&2
    exit 2
fi

GIT_SHA="$(git rev-parse "$REF^{commit}")" || {
    echo "error: cannot resolve --ref '$REF' to a commit" >&2
    exit 2
}

PREFIX="$ROOT/peakrdl/$VERSION"
MODULE_DIR="$ROOT/modulefiles/peakrdl"

if [[ -e "$PREFIX" && "$FORCE" -ne 1 ]]; then
    echo "error: $PREFIX already exists (use --force to rebuild, or pick a new --version)" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPL="$SCRIPT_DIR/peakrdl.module.tmpl"
[[ -f "$TMPL" ]] || { echo "error: modulefile template not found: $TMPL" >&2; exit 2; }

BUILDDIR="$(mktemp -d "${TMPDIR:-/tmp}/peakrdl_src.XXXXXX")"
trap 'rm -rf "$BUILDDIR"' EXIT

echo "==> Releasing peakrdl $VERSION (git $GIT_SHA)"
echo "==> Exporting source at $GIT_SHA (local repo)"
git archive "$GIT_SHA" | tar -x -C "$BUILDDIR"

if [[ "$FORCE" -eq 1 && -e "$PREFIX" ]]; then
    echo "==> Removing existing $PREFIX (--force)"
    rm -rf "$PREFIX"
fi

# Pin pip: pip>=26 (and the bundled 23.2.1) import pyexpat on their
# wheel-install path, which is broken on this RHEL8 box (python3.12.14 vs
# old libexpat: undefined XML_SetBillionLaughsAttackProtection*). pip 25.2
# avoids that chain. Override with $PEAKRDL_RELEASE_PIP_VERSION once the
# system expat is fixed.
PIP_VER="${PEAKRDL_RELEASE_PIP_VERSION:-25.2}"

echo "==> Creating virtualenv $PREFIX"
mkdir -p "$ROOT/peakrdl"
if ! "$PYTHON" -m venv "$PREFIX" 2>/dev/null || [[ ! -x "$PREFIX/bin/pip" ]]; then
    # ensurepip is broken on this box - create the venv without pip and
    # bootstrap pip by unzipping the wheel directly (no pip/pyexpat needed)
    echo "    (ensurepip failed; bootstrapping pip $PIP_VER from PyPI wheel)"
    rm -rf "$PREFIX"
    "$PYTHON" -m venv --without-pip "$PREFIX"
    PIP_URL="$("$PYTHON" -c "
import json, urllib.request
d = json.load(urllib.request.urlopen('https://pypi.org/pypi/pip/$PIP_VER/json'))
print(next(u['url'] for u in d['urls'] if u['filename'].endswith('py3-none-any.whl')))
")"
    PIP_WHL="$(mktemp "${TMPDIR:-/tmp}/pip-XXXXXX.whl")"
    curl -fsSL "$PIP_URL" -o "$PIP_WHL"
    SP="$("$PREFIX/bin/python" -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")"
    "$PREFIX/bin/python" -m zipfile -e "$PIP_WHL" "$SP"
    rm -f "$PIP_WHL"
    printf '#!/usr/bin/env bash\nexec "$(dirname "$(readlink -f "$0")")/python" -m pip "$@"\n' > "$PREFIX/bin/pip"
    chmod +x "$PREFIX/bin/pip"
    ln -sf pip "$PREFIX/bin/pip3"
else
    "$PREFIX/bin/pip" install --quiet --upgrade "pip==$PIP_VER"
fi

# Stock pip's vendored distlib imports xmlrpc -> pyexpat eagerly, which is
# broken on this box. Guard it (xmlrpc is only used by the defunct PyPI
# XMLRPC API, never by pip install). Remove once the system expat is fixed.
SP="$("$PREFIX/bin/python" -c "import sysconfig; print(sysconfig.get_paths()['purelib'])")"
"$PREFIX/bin/python" - "$SP" <<'PYEOF'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / "pip/_vendor/distlib/compat.py"
s = p.read_text()
old = "    import xmlrpc.client as xmlrpclib\n"
new = """    try:
        import xmlrpc.client as xmlrpclib
    except ImportError:
        # System pyexpat is broken (libexpat too old). xmlrpc is only used by
        # the defunct PyPI XMLRPC API, never by pip install - stub it out.
        class _XMLRPCStub(object):
            def __getattr__(self, name):
                if name in ('Transport', 'SafeTransport', 'ServerProxy'):
                    return object  # subclassable placeholder, never instantiated
                raise ImportError('xmlrpc unavailable: pyexpat is broken')
        xmlrpclib = _XMLRPCStub()
"""
if old in s:
    p.write_text(s.replace(old, new, 1))
    print("    (patched pip's distlib compat: guarded xmlrpc import)")
PYEOF

echo "==> Installing peakrdl-regblock from local source + PyPI companions"
"$PREFIX/bin/pip" install --quiet "$BUILDDIR" peakrdl peakrdl-uvm peakrdl-docx

echo "==> Smoke test: $PREFIX/bin/peakrdl regblock --help"
"$PREFIX/bin/peakrdl" regblock --help >/dev/null
if ! "$PREFIX/bin/peakrdl" regblock --help 2>&1 | grep -q '{[^}]*axi4[,}]'; then
    echo "error: released peakrdl does NOT list the built-in 'axi4' cpuif" >&2
    echo "       (wrong peakrdl-regblock installed?)" >&2
    exit 1
fi
echo "    OK: built-in 'axi4' cpuif present"
"$PREFIX/bin/pip" show peakrdl-regblock | grep -E "^(Name|Version)" | sed 's/^/    /'

echo "==> Publishing README.md + regblock_udps.rdl"
cp "$BUILDDIR/README.md" "$PREFIX/README.md"
mkdir -p "$PREFIX/share"
cp "$BUILDDIR/hdl-src/regblock_udps.rdl" "$PREFIX/share/regblock_udps.rdl"

echo "==> Writing modulefile $MODULE_DIR/$VERSION"
mkdir -p "$MODULE_DIR"
sed -e "s|@VERSION@|$VERSION|g" \
    -e "s|@PREFIX@|$PREFIX|g" \
    -e "s|@GIT_SHA@|$GIT_SHA|g" \
    "$TMPL" > "$MODULE_DIR/$VERSION"

if [[ "$PROMOTE_DEFAULT" -eq 1 ]]; then
    echo "==> Promoting default version to $VERSION"
    printf '#%%Module1.0\nset ModulesVersion "%s"\n' "$VERSION" > "$MODULE_DIR/.version"
else
    echo "==> Skipping default promotion (--no-default)"
fi

echo "==> Setting shared read permissions"
chmod -R a+rX "$ROOT/peakrdl/$VERSION" "$MODULE_DIR"

# Keep at most KEEP releases: prune oldest version dirs + modulefiles.
KEEP="${PEAKRDL_RELEASE_KEEP:-5}"
versions=($(ls -1 "$ROOT/peakrdl" | sort -V))
if (( ${#versions[@]} > KEEP )); then
    echo "==> Pruning old releases (keeping newest $KEEP)"
    for old in "${versions[@]:0:$((${#versions[@]} - KEEP))}"; do
        echo "    Removing $old"
        rm -rf "$ROOT/peakrdl/$old" "$MODULE_DIR/$old"
    done
    # If the module default pointed at a pruned version, re-point it to the
    # newest remaining one.
    default_ver="$(sed -n 's/.*ModulesVersion "\(.*\)".*/\1/p' "$MODULE_DIR/.version" 2>/dev/null || true)"
    if [[ -n "$default_ver" && ! -e "$MODULE_DIR/$default_ver" ]]; then
        newest="$(ls -1 "$MODULE_DIR" | sort -V | tail -1)"
        echo "    Default $default_ver was pruned; re-pointing default to $newest"
        printf '#%%Module1.0\nset ModulesVersion "%s"\n' "$newest" > "$MODULE_DIR/.version"
    fi
fi

echo "==> Verifying via tcsh (modulecmd + eval)"
resolved="$(
    MODULES_ROOT="$ROOT/modulefiles" tcsh -f -c \
        'eval `modulecmd tcsh use "$MODULES_ROOT"`; eval `modulecmd tcsh load peakrdl`; which peakrdl' \
        2>/dev/null || true
)"
if [[ "$resolved" == "$PREFIX/bin/peakrdl" ]]; then
    echo "    OK: module load peakrdl -> $resolved"
else
    echo "    WARNING: unexpected resolution: '${resolved:-<none>}' (expected $PREFIX/bin/peakrdl)" >&2
fi

cat <<EOF

Released peakrdl $VERSION (git $GIT_SHA)

For users (one-time, add to ~/.cshrc):
    module use $ROOT/modulefiles

Then load:
    module load peakrdl            # default version
    module load peakrdl/$VERSION   # this version

UDP definitions for buffer_writes/buffer_reads RDL:
    \$PEAKRDL_HOME/share/regblock_udps.rdl   (compile it before your RDL)
EOF
