#!/usr/bin/env bash

# *
# * If not stated otherwise in this file or this component's LICENSE file the
# * following copyright and licenses apply:
# *
# * Copyright 2023 RDK Management
# *
# * Licensed under the Apache License, Version 2.0 (the "License");
# * you may not use this file except in compliance with the License.
# * You may obtain a copy of the License at
# *
# * http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# *

# Abort on the first failure, on any unset variable, and on a failure anywhere
# in a pipeline. A documentation build that cannot fetch or verify its
# generator must stop with a non-zero status rather than carry on and publish an
# empty or wrong document set.
set -euo pipefail

SCRIPT_NAME="$(basename -- "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

log() { printf '%s: %s\n' "${SCRIPT_NAME}" "$*"; }
fail() { printf '%s: error: %s\n' "${SCRIPT_NAME}" "$*" >&2; exit 1; }

# Every git command in this script - including the clone - runs through this
# wrapper, because several git configuration settings name a program git then
# executes. git reads that configuration from six scopes, listed here in its
# own order of increasing precedence, because the scope that outranks all the
# file scopes is the one an earlier version of this wrapper did not address:
#   system       $(prefix)/etc/gitconfig  - excluded by GIT_CONFIG_NOSYSTEM=1
#   global       ~/.gitconfig and XDG     - replaced by GIT_CONFIG_GLOBAL=/dev/null
#   local        .git/config              - scanned and refused further down
#   worktree     .git/config.worktree     - scanned and refused further down
#   environment                           - unset here, per GIT_ENV_* below
#   command line                          - the -c overrides this wrapper passes
# A generator checkout that is already on disk gets to run code at the first git
# command that touches it, which is before any check below has established that
# the checkout is the reviewed one: 'fetch' can run reference-transaction hooks
# and the transport named by core.sshCommand, 'checkout' runs post-checkout and
# any smudge filter a .gitattributes entry routes a file to, 'clone' copies the
# hooks out of the directory GIT_TEMPLATE_DIR names and then runs them, and
# 'status' can spawn the program named by core.fsmonitor.
#
# GIT_ENV_REFUSED is the set of environment variables that inject configuration
# wholesale, name a program git executes, or move the repository, index or object
# store somewhere else. Every one is unset inside run_git() below, and every one
# is also refused outright before the first git command runs, because an
# environment carrying one is not the environment this scaffold was reviewed in
# and the operator is better told which variable stopped the build than left to
# wonder why the generator would not fetch.
#
# Each of these was measured against this script with the rest of the hardening
# already in place, on git 2.51.0, and each executed a caller-supplied command or
# defeated a control:
#   GIT_CONFIG_COUNT + GIT_CONFIG_KEY_0/VALUE_0 setting core.sshCommand ran it
#   GIT_CONFIG_PARAMETERS, the older spelling of the same thing, ran it
#   GIT_SSH_COMMAND ran it
#   GIT_TEMPLATE_DIR installed a post-checkout hook into the fresh clone and ran
#     it; note that -c init.templateDir= does NOT defeat the variable - it only
#     closes the configuration spelling - which is why the variable is refused
#   GIT_ALLOW_PROTOCOL=ext re-enabled the ext:: transport, whose "address" is a
#     shell command, in spite of -c protocol.ext.allow=never on the command line
# So the environment scope beats both the configuration files this script
# controls and the command line it builds, and taking it out of the picture is
# the only fix.
#
# Unset is the neutralisation, not an empty value, because git honours an empty
# value as a value for most of these and for two of them an empty value would
# disable this script's own checks. Measured on git 2.51.0:
#   GIT_INDEX_FILE=   'git status' read an empty index, reported every tracked
#                     file as deleted and left a stray '.lock' behind - which is
#                     the cleanliness scan below being blinded, not hardened
#   GIT_CONFIG=       'git config --get' read nothing and exited 1, so the
#                     configuration refusal scan below would have had no keys
#                     left to refuse
#   GIT_DIR=          fatal: not a git repository: ''
#   GIT_WORK_TREE=    fatal: The empty string is not a valid path
#   GIT_SSH_COMMAND=  error: cannot run : No such file or directory
# Only GIT_CONFIG_COUNT, GIT_CONFIG_PARAMETERS, GIT_NAMESPACE and
# GIT_ALTERNATE_OBJECT_DIRECTORIES treat an empty value as absent, so blanking
# the set would have broken the build in three places and silently disabled two
# checks in two more.
#
# One consequence to be aware of, because it is a deliberate trade: a caller who
# supplies a deploy key through GIT_SSH_COMMAND is refused, since nothing here
# can tell a key-bearing ssh command from a payload. ssh-agent and ~/.ssh/config
# both still work and are the supported way to authenticate the clone.
GIT_ENV_REFUSED="GIT_CONFIG
GIT_CONFIG_COUNT
GIT_CONFIG_PARAMETERS
GIT_CONFIG_SYSTEM
GIT_CONFIG_GLOBAL
GIT_SSH
GIT_SSH_COMMAND
GIT_PROXY_COMMAND
GIT_EXTERNAL_DIFF
GIT_TEMPLATE_DIR
GIT_EXEC_PATH
GIT_ALLOW_PROTOCOL
GIT_PROTOCOL_FROM_USER
GIT_DIR
GIT_WORK_TREE
GIT_COMMON_DIR
GIT_INDEX_FILE
GIT_OBJECT_DIRECTORY
GIT_ALTERNATE_OBJECT_DIRECTORIES
GIT_NAMESPACE
GIT_CEILING_DIRECTORIES
GIT_DISCOVERY_ACROSS_FILESYSTEM"
readonly GIT_ENV_REFUSED

# The second set is unset for every git command but is not a refusal, because a
# developer's shell legitimately exports these and turning an ordinary profile
# into a failed documentation build would be a poor trade for no gain: each one
# only names a program git launches to display, edit or prompt for something,
# and unsetting it removes the exposure completely. The matching -c overrides in
# the wrapper pin the corresponding configuration keys, which is what closes the
# non-GIT_ spellings (PAGER, EDITOR, VISUAL) that git also consults - verified:
# with -c core.pager=cat a hostile PAGER is never executed. GIT_SSH_VARIANT
# names no program of its own; it only changes how git builds the ssh command
# line, and with GIT_SSH and GIT_SSH_COMMAND refused there is nothing left for
# it to shape.
GIT_ENV_CLEARED="GIT_PAGER
GIT_EDITOR
GIT_SEQUENCE_EDITOR
GIT_ASKPASS
GIT_SSH_VARIANT"
readonly GIT_ENV_CLEARED

# Refuse the hazardous environment before the first git command runs. A variable
# that is set to the empty string is still set, which is what ${!name+set}
# reports; the indexed GIT_CONFIG_KEY_<n>/GIT_CONFIG_VALUE_<n> families are found
# by prefix rather than by name, because n is unbounded.
GIT_ENV_PRESENT=""
for git_env_name in ${GIT_ENV_REFUSED}; do
    if [ -n "${!git_env_name+set}" ]; then
        GIT_ENV_PRESENT="${GIT_ENV_PRESENT} ${git_env_name}"
    fi
done
for git_env_name in ${!GIT_CONFIG_KEY_@} ${!GIT_CONFIG_VALUE_@}; do
    GIT_ENV_PRESENT="${GIT_ENV_PRESENT} ${git_env_name}"
done
if [ -n "${GIT_ENV_PRESENT}" ]; then
    fail "the environment sets git variables that inject configuration, name a program git would run, or relocate the repository, index or object store (${GIT_ENV_PRESENT# }); git's environment scope outranks both the configuration files this build controls and the -c overrides it passes, so the build stops here - unset them and re-run, and authenticate the generator clone through ssh-agent or ~/.ssh/config rather than GIT_SSH_COMMAND"
fi
unset git_env_name

# The wrapper. The unsets are made in a subshell so that neutralising the
# environment for git does not change the environment of this script or of the
# make that follows it. Nothing in either list contains a glob character or
# whitespace, so the loops need neither 'set -f' nor an IFS of their own.
#
# The per-invocation -c overrides disable the repository-level settings that
# would otherwise run a program during clone, fetch, checkout or status:
#   core.hooksPath=/dev/null      hooks live inside the repository, so clearing
#                                 the environment does not disable them - only
#                                 pointing git at a directory that contains no
#                                 hooks does.
#   core.fsmonitor=               an empty value disables the file-system monitor
#                                 git would otherwise spawn while reading status.
#   core.attributesFile=/dev/null keeps an attributes file outside the checkout
#                                 from routing a path to a filter driver.
#   core.pager=cat                outranks a PAGER inherited from the caller.
#   core.editor=true              outranks EDITOR and VISUAL.
#   init.templateDir=             closes the configuration spelling of the
#                                 template-hook path used at clone time.
#   protocol.ext.allow=never      refuses ext:: URLs, whose "address" is a shell
#                                 command git runs as the transport.
# This wrapper is defence in depth, not the decision: a checkout that ships any
# of those settings is refused outright further down, before the first fetch.
run_git() {
    (
        for run_git_env_name in ${GIT_ENV_REFUSED} ${GIT_ENV_CLEARED} \
                                ${!GIT_CONFIG_KEY_@} ${!GIT_CONFIG_VALUE_@}; do
            unset "${run_git_env_name}"
        done
        unset run_git_env_name
        GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL=/dev/null \
        GIT_ATTR_NOSYSTEM=1 \
        GIT_TERMINAL_PROMPT=0 \
        GIT_ASKPASS=true \
        git -c core.hooksPath=/dev/null \
            -c core.fsmonitor= \
            -c core.attributesFile=/dev/null \
            -c core.pager=cat \
            -c core.editor=true \
            -c init.templateDir= \
            -c protocol.ext.allow=never \
            "$@"
    )
}

# Work from this script's own directory rather than from the caller's. The
# generator's Doxyfile expresses every INPUT path relative to this docs/
# directory, so the build only resolves its inputs when it runs here.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
cd -- "${SCRIPT_DIR}"

# The repository this documentation describes, one level up from docs/.
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
readonly REPO_ROOT

# The same two directories with every symlink resolved. SCRIPT_DIR and REPO_ROOT
# are the logical paths - what the caller walked through - and they are the right
# thing to print in a message and to cd into. They are the wrong thing to compare
# a resolved path against: 'cd X && pwd -P' and realpath both answer with the
# physical path, so a checkout reached through a symlinked parent (a bind-style
# /repo -> /mnt/work/repo, say) would make every containment test below fail on a
# perfectly ordinary layout. Comparing physical against physical keeps the test
# fail-closed for a build/ or output/ that genuinely resolves elsewhere, while
# letting a legitimate checkout build wherever it is reached from.
SCRIPT_DIR_REAL="$(cd -- "${SCRIPT_DIR}" && pwd -P)"
readonly SCRIPT_DIR_REAL
REPO_ROOT_REAL="$(cd -- "${REPO_ROOT}" && pwd -P)"
readonly REPO_ROOT_REAL

# The documentation generator, pinned to an immutable upstream tag. 1.2.0 is the
# pin every scaffold in this corpus uses, and it is deliberate: it is the
# release whose USE_MDFILE_AS_MAINPAGE value ("../pages/halSpec.md") resolves
# against a specification page named halSpec.md, so the generated site gets a
# main page. Later generator releases point that setting at README.md, which a
# root symlink into docs/pages/ does not satisfy. Do not advance this pin
# without re-testing that index.html carries the specification.
readonly HAL_GENERATOR_VERSION="1.2.0"
readonly HAL_GENERATOR_URL="git@github.com:rdkcentral/hal-doxygen.git"
readonly HAL_GENERATOR_DIR="build"

# Where the generated site is written. This is not a choice this script makes:
# the pinned generator's Doxyfile.cfg sets OUTPUT_DIRECTORY to ../output relative
# to build/, and HTML_OUTPUT to html, so the site lands in this docs/output/html
# whatever this name says. It is named here because the block before make has to
# contain that path, and a literal repeated in three places is a literal that
# eventually disagrees with itself.
readonly HAL_OUTPUT_DIR="output"

# The exact commit tag 1.2.0 names upstream. The tag is recorded as well as the
# commit because a tag is a movable reference: a lightweight tag can be deleted
# and recreated on different content, and a checkout whose HEAD matches a
# re-pointed tag is not the reviewed generator. Both must agree before anything
# is executed. Update this only together with HAL_GENERATOR_VERSION, and only
# after re-verifying the new commit against the upstream repository.
readonly HAL_GENERATOR_COMMIT="cfd03653d1bbdb88efa6cf47277aa9eeba4f5fae"

# The complete set of origin URLs a generator checkout is allowed to declare:
# the ssh form the fourteen pre-existing sibling scripts clone with, the https
# form of the same repository, and each of those written without the .git
# suffix. This is an exact allowlist rather than a pattern on purpose. Matching
# a normalised suffix such as */rdkcentral/hal-doxygen accepts
# 'https://evil.example/rdkcentral/hal-doxygen.git', because stripping the
# scheme, any user@ and any host: leaves 'evil.example/rdkcentral/hal-doxygen',
# whose tail is the expected owner/repository - and it accepts a local
# directory such as /tmp/anything/rdkcentral/hal-doxygen for the same reason.
# The host, the transport and the owner/repository must all match exactly, so
# each permitted spelling is written out in full and nothing else is accepted.
readonly HAL_GENERATOR_ORIGIN_SSH="git@github.com:rdkcentral/hal-doxygen.git"
readonly HAL_GENERATOR_ORIGIN_SSH_PLAIN="git@github.com:rdkcentral/hal-doxygen"
readonly HAL_GENERATOR_ORIGIN_HTTPS="https://github.com/rdkcentral/hal-doxygen.git"
readonly HAL_GENERATOR_ORIGIN_HTTPS_PLAIN="https://github.com/rdkcentral/hal-doxygen"

# The generated site's title, which the generator renders as PROJECT_NAME.
readonly PROJECT_NAME="RDK-B GPON HAL"

# The generated site's version string, taken from the last tag in this
# repository. A repository that has no tag yet must still be able to build its
# documentation, so fall back to the exact short commit rather than passing an
# empty version to the generator: a site labelled with nothing at all is a
# silently wrong build, whereas a commit hash is accurate and traceable.
PROJECT_VERSION="$(run_git -C "${REPO_ROOT}" describe --tags 2>/dev/null | head -n1 || true)"
if [ -z "${PROJECT_VERSION}" ]; then
    PROJECT_VERSION="$(run_git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || true)"
fi
if [ -z "${PROJECT_VERSION}" ]; then
    fail "cannot determine a project version: '${REPO_ROOT}' has no reachable tag and no HEAD commit"
fi
readonly PROJECT_VERSION

# Refuse a build/ directory that is not a generator checkout. Testing only for
# the directory lets an empty or half-created build/ pass for a usable
# generator, and the build then runs against nothing.
if [ -L "${HAL_GENERATOR_DIR}" ]; then
    fail "'${SCRIPT_DIR}/${HAL_GENERATOR_DIR}' is a symlink; the generator must be a real directory inside ${SCRIPT_DIR} so that what is verified is what is executed"
fi
if [ -e "${HAL_GENERATOR_DIR}" ]; then
    if [ ! -d "${HAL_GENERATOR_DIR}" ]; then
        fail "'${SCRIPT_DIR}/${HAL_GENERATOR_DIR}' exists but is not a directory; remove it and re-run"
    fi
    # Containment: a build/ that resolves outside this docs/ directory means the
    # verified checkout and the executed one need not be the same tree. The
    # comparison is physical-against-physical (see SCRIPT_DIR_REAL), which is what
    # extends this test to a symlinked ancestor: build/ itself is refused above if
    # it is a link, and any link further up is resolved by pwd -P on both sides,
    # so a docs/ that is itself a link out of the repository lands outside
    # SCRIPT_DIR_REAL and is refused here. Nothing inside build/ needs a separate
    # link scan, because a symlink there is either a type change to a tracked path
    # or an untracked entry, and the cleanliness scan before make refuses both.
    GENERATOR_REAL="$(cd -- "${HAL_GENERATOR_DIR}" && pwd -P)" \
        || fail "cannot enter '${SCRIPT_DIR}/${HAL_GENERATOR_DIR}'"
    case "${GENERATOR_REAL}" in
        "${SCRIPT_DIR_REAL}"/*) : ;;
        *) fail "'${HAL_GENERATOR_DIR}' resolves to ${GENERATOR_REAL}, which is outside ${SCRIPT_DIR_REAL}; refusing to build from an out-of-tree generator" ;;
    esac
    # An existing build/ must already be a git checkout; an empty or half-created
    # one would otherwise be built from as if it were the generator. Whether its
    # .git is real metadata for this directory, rather than a symlink or a
    # pointer file aimed elsewhere, is settled by the block after the clone, so
    # that the freshly cloned case is held to the same requirement.
    if [ ! -d "${HAL_GENERATOR_DIR}/.git" ]; then
        fail "'${SCRIPT_DIR}/${HAL_GENERATOR_DIR}' exists but is not a git checkout of ${HAL_GENERATOR_URL} holding its own .git directory; remove it and re-run"
    fi
fi

# Clone the generator if it is not already present. A clone that fails stops
# the script here, so no later git command can run against this repository
# instead of the generator's.
if [ ! -d "${HAL_GENERATOR_DIR}/.git" ]; then
    log "cloning the common documentation generator into ${SCRIPT_DIR}/${HAL_GENERATOR_DIR}"
    run_git clone --quiet "${HAL_GENERATOR_URL}" "${HAL_GENERATOR_DIR}" \
        || fail "cannot clone ${HAL_GENERATOR_URL}"
fi

# Whether the checkout was cloned just now or was already on disk, its git
# metadata must be a real directory inside it and git must agree that this
# directory is the whole of the repository. The two assertions that follow are
# both made because each one covers what the other misses:
#   - --show-toplevel catches a checkout whose work tree is somewhere else. A
#     real .git directory carrying core.worktree = /elsewhere makes the
#     checkout, the revision verification and the cleanliness scan below all
#     act on that other tree, while make still compiles what sits in build/.
#   - --absolute-git-dir catches build/ having no metadata of its own and being
#     governed by an enclosing repository's .git, where nothing this script
#     verifies describes build/'s contents at all.
if [ -L "${HAL_GENERATOR_DIR}/.git" ]; then
    fail "'${SCRIPT_DIR}/${HAL_GENERATOR_DIR}/.git' is a symlink; the generator's git metadata must be a real directory inside the checkout so that the revision verified below is the revision whose files are built"
fi
if [ ! -d "${HAL_GENERATOR_DIR}/.git" ]; then
    fail "'${SCRIPT_DIR}/${HAL_GENERATOR_DIR}/.git' is not a directory; the generator must be a self-contained git checkout, so a 'gitdir:' pointer file or a missing .git is refused"
fi
GENERATOR_REAL="$(cd -- "${HAL_GENERATOR_DIR}" && pwd -P)" \
    || fail "cannot enter '${SCRIPT_DIR}/${HAL_GENERATOR_DIR}'"
GENERATOR_TOPLEVEL="$(run_git -C "${HAL_GENERATOR_DIR}" rev-parse --show-toplevel)" \
    || fail "'${SCRIPT_DIR}/${HAL_GENERATOR_DIR}' is not a usable git work tree"
if [ "${GENERATOR_TOPLEVEL}" != "${GENERATOR_REAL}" ]; then
    fail "git reports the generator's work tree as ${GENERATOR_TOPLEVEL}, not ${GENERATOR_REAL}; the tree that would be verified is not the tree that would be built, so refusing to build"
fi
GENERATOR_GITDIR="$(run_git -C "${HAL_GENERATOR_DIR}" rev-parse --absolute-git-dir)" \
    || fail "cannot resolve the git directory of '${SCRIPT_DIR}/${HAL_GENERATOR_DIR}'"
if [ "${GENERATOR_GITDIR}" != "${GENERATOR_REAL}/.git" ]; then
    fail "git reports the generator's git directory as ${GENERATOR_GITDIR}, not ${GENERATOR_REAL}/.git; refusing to build from a checkout governed by metadata outside itself"
fi

# The key classifier, shared by both repository configuration scopes so neither
# can be held to a weaker standard than the other. It takes a newline-separated
# list of configuration key names and echoes the ones that name a program git
# would run, move the hook directory, or rewrite the URL a fetch contacts.
#
# git lower-cases section and variable names in its output, so every pattern is
# written in the form git reports (core.hookspath, not core.hooksPath).
generator_execution_capable_keys() {
    generator_bad_keys=""
    # Split the key list on newlines only, with pathname expansion off: a key
    # name such as url.https://x/.insteadof contains glob characters, and
    # unquoted splitting would otherwise try to expand them against the
    # filesystem. This runs inside a command substitution, so the option and IFS
    # changes cannot leak into the caller, and they are restored regardless.
    set -f
    generator_old_ifs="${IFS}"
    IFS='
'
    for generator_key in $1; do
        case "${generator_key}" in
            # core.hooksPath moves the hook directory, so a hook can be kept
            # anywhere on disk and still run on fetch or checkout.
            core.hookspath) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # A filter driver's clean/smudge/process command is run by checkout
            # for every path a .gitattributes entry routes to it.
            filter.*) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # core.fsmonitor names a program git spawns while reading status -
            # the very command that decides whether this checkout is clean.
            core.fsmonitor) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # core.sshCommand replaces the transport program the fetch runs.
            core.sshcommand) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # core.pager and core.editor name programs git launches to display or
            # edit its output, so any git command here can be turned into one.
            core.pager|core.editor) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # A credential helper is a program git runs while authenticating a
            # fetch, and a value beginning with ! is passed to the shell.
            credential.helper|credential.*.helper) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # uploadpack/receivepack name the program run on the other end of a
            # transfer, which for a local or ssh remote is a program run here.
            remote.*.uploadpack|remote.*.receivepack) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # protocol.*.allow re-enables transports the wrapper refuses,
            # including ext::, whose URL is a shell command.
            protocol.allow|protocol.*.allow) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # url.<base>.insteadOf silently rewrites the URL a fetch contacts, so
            # the origin verified below is not the origin actually reached.
            url.*) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # An alias can shadow a subcommand this script invokes - alias.status,
            # for instance - and an alias value beginning with ! is a shell
            # command.
            alias.*) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # An include pulls in another file's configuration wholesale, which
            # is how any of the above can be set without appearing in
            # .git/config.
            include.path|includeif.*) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
            # extensions.worktreeConfig switches on a whole configuration file
            # that 'git config --list --local' does not read: see the
            # config.worktree refusal below.
            extensions.worktreeconfig) generator_bad_keys="${generator_bad_keys} ${generator_key}" ;;
        esac
    done
    IFS="${generator_old_ifs}"
    set +f
    printf '%s' "${generator_bad_keys# }"
}

# Refuse a checkout that carries its own execution-capable git configuration or
# an installed hook. Everything this function uses is a read that cannot run
# anything from the checkout: 'git config --list --name-only' reports the names
# of the keys in a scope (and in any file it includes) without acting on them,
# and the hooks directory is examined with plain shell tests. The wrapper above
# already disables the worst settings per invocation, but a generator checkout
# that ships any of them is not the reviewed generator, so the build stops here
# rather than proceeding with them merely suppressed.
#
# Three scopes are covered, and the second is the one a single --local scan
# misses entirely. When extensions.worktreeConfig is true git also reads
# $GIT_DIR/config.worktree, and 'git config --list --local' does not: measured on
# git 2.51.0, a core.sshCommand placed in config.worktree was invisible to the
# --local listing, took effect for the fetch, and ran. So the extension key is
# refused by the classifier above, the file is refused if it exists at all, and
# the --worktree scope is listed and classified as well. Refusing the file
# outright is the simplest thing to reason about and costs nothing legitimate:
# git never creates config.worktree on clone - verified against a fresh clone of
# this generator - and this script only ever produces the checkout by cloning, so
# a config.worktree here was put there by something other than git.
#
# The --worktree listing is allowed to fail: with the extension off git returns
# the local list instead, and in an unusual layout it can refuse outright. A
# failure therefore adds nothing and removes nothing, because the local scope is
# scanned separately and the file itself is already refused.
#
# This function is called twice - see each call site - so it keeps its findings
# in variables it resets on entry.
refuse_generator_execution_paths() {
    generator_phase="$1"

    generator_worktree_config="${HAL_GENERATOR_DIR}/.git/config.worktree"
    if [ -e "${generator_worktree_config}" ] || [ -L "${generator_worktree_config}" ]; then
        fail "'${SCRIPT_DIR}/${generator_worktree_config}' exists (checked ${generator_phase}); git reads that file as a configuration scope of its own when extensions.worktreeConfig is set, and 'git config --list --local' does not report it, so a hook path, transport command or filter could sit there unseen - git never creates this file on clone, so refusing to fetch, check out or build from this checkout - remove ${SCRIPT_DIR}/${HAL_GENERATOR_DIR} and re-run to get a clean checkout"
    fi

    generator_config_keys="$(run_git -C "${HAL_GENERATOR_DIR}" config --list --local --name-only || true)"
    generator_bad_local="$(generator_execution_capable_keys "${generator_config_keys}")"
    if [ -n "${generator_bad_local}" ]; then
        fail "the generator checkout configures git settings that name a program git would run (${generator_bad_local}), found in its local configuration ${generator_phase}; refusing to fetch, check out or build from it - remove ${SCRIPT_DIR}/${HAL_GENERATOR_DIR} and re-run to get a clean checkout"
    fi

    generator_worktree_keys="$(run_git -C "${HAL_GENERATOR_DIR}" config --list --worktree --name-only 2>/dev/null || true)"
    generator_bad_worktree="$(generator_execution_capable_keys "${generator_worktree_keys}")"
    if [ -n "${generator_bad_worktree}" ]; then
        fail "the generator checkout configures git settings that name a program git would run (${generator_bad_worktree}), found in its per-worktree configuration ${generator_phase}; refusing to fetch, check out or build from it - remove ${SCRIPT_DIR}/${HAL_GENERATOR_DIR} and re-run to get a clean checkout"
    fi

    # An installed hook runs on the operations this script performs: post-checkout
    # on the checkout, and reference-transaction on the fetch. The samples git
    # writes into every new clone are executable but inert, because git only runs
    # a hook whose name has no .sample suffix, so they are skipped and anything
    # else executable is refused.
    generator_hooks_dir="${HAL_GENERATOR_DIR}/.git/hooks"
    generator_bad_hooks=""
    if [ -d "${generator_hooks_dir}" ]; then
        for generator_hook in "${generator_hooks_dir}"/*; do
            # The pattern itself when the directory is empty.
            [ -e "${generator_hook}" ] || continue
            case "${generator_hook}" in
                *.sample) continue ;;
            esac
            if [ -f "${generator_hook}" ] && [ -x "${generator_hook}" ]; then
                generator_bad_hooks="${generator_bad_hooks} ${generator_hook}"
            fi
        done
    fi
    if [ -n "${generator_bad_hooks}" ]; then
        fail "the generator checkout has executable git hooks installed (${generator_bad_hooks# }), found ${generator_phase}; refusing to fetch, check out or build from it - remove ${SCRIPT_DIR}/${HAL_GENERATOR_DIR} and re-run to get a clean checkout"
    fi
}

# First scan: before the first fetch or checkout, so nothing in the checkout has
# had a chance to run.
refuse_generator_execution_paths "before the first fetch or checkout"

# Verify the checkout belongs to the intended upstream project. A directory that
# is a valid git repository at the right commit is still the wrong input if it
# was cloned from somewhere else, so the remote is checked before any ref from
# it is trusted.
#
# Every configured value is read, not one of them. 'git config --get' returns the
# LAST value a repository configures for a multi-valued key, while a fetch
# addressed by remote name uses the FIRST. A checkout that configures two
# 'remote.origin.url' values can therefore have the trusted one inspected here
# and the other one dialled; if that other one embeds a credential, the
# credential reaches git and its transport diagnostics (CWE-532). So the key is
# read with --get-all, more than one value is a hard failure rather than
# something to choose between, each value is refused if it embeds a credential
# or names another repository, and the fetch below is addressed by the validated
# URL literally instead of by remote name, so git cannot select a URL other than
# the one inspected here. A value carrying an embedded newline is counted as two
# and rejected on the same rule.
GENERATOR_ORIGIN_VALUES="$(run_git -C "${HAL_GENERATOR_DIR}" config --get-all remote.origin.url || true)"
if [ -z "${GENERATOR_ORIGIN_VALUES}" ]; then
    fail "'${SCRIPT_DIR}/${HAL_GENERATOR_DIR}' has no remote.origin.url; refusing to build from a checkout of unknown provenance"
fi

GENERATOR_ORIGIN_COUNT=0
GENERATOR_ORIGIN=""
while IFS= read -r generator_origin_value; do
    [ -n "${generator_origin_value}" ] || continue
    GENERATOR_ORIGIN_COUNT=$((GENERATOR_ORIGIN_COUNT + 1))

    # A userinfo field other than the bare 'git' of an scp-like ssh URL is a
    # credential. Its text is never reported, because reporting it is the
    # disclosure the check exists to prevent.
    generator_origin_authority="${generator_origin_value#*://}"
    generator_origin_authority="${generator_origin_authority%%/*}"
    case "${generator_origin_authority}" in
        *@*)
            if [ "${generator_origin_authority%%@*}" != "git" ]; then
                fail "the 'origin' remote of '${SCRIPT_DIR}/${HAL_GENERATOR_DIR}' embeds a credential in a configured URL; its text is deliberately not reported so the credential cannot reach this log; point origin at ${HAL_GENERATOR_ORIGIN_SSH} and hold the credential in an ssh agent or a git credential helper, then re-run"
            fi
            ;;
    esac

    # The origin is compared literally against every permitted spelling. No
    # normalisation happens first: an origin that merely ends in the expected
    # owner/repository - 'https://evil.example/rdkcentral/hal-doxygen.git', or a
    # local directory laid out as .../rdkcentral/hal-doxygen - names a different
    # repository on a different host, and reaches this check indistinguishable
    # from the real one only if the comparison throws the host away.
    case "${generator_origin_value}" in
        "${HAL_GENERATOR_ORIGIN_SSH}"|"${HAL_GENERATOR_ORIGIN_SSH_PLAIN}"|"${HAL_GENERATOR_ORIGIN_HTTPS}"|"${HAL_GENERATOR_ORIGIN_HTTPS_PLAIN}") : ;;
        *) fail "'${HAL_GENERATOR_DIR}' has origin ${generator_origin_value}, which is not ${HAL_GENERATOR_ORIGIN_SSH} or ${HAL_GENERATOR_ORIGIN_HTTPS}; refusing to build from a checkout of another repository" ;;
    esac

    GENERATOR_ORIGIN="${generator_origin_value}"
done <<EOF
${GENERATOR_ORIGIN_VALUES}
EOF

if [ "${GENERATOR_ORIGIN_COUNT}" -ne 1 ]; then
    fail "the 'origin' remote of '${SCRIPT_DIR}/${HAL_GENERATOR_DIR}' configures ${GENERATOR_ORIGIN_COUNT} URLs; exactly one is required, because a fetch and an inspection of the configuration do not necessarily select the same one; remove ${SCRIPT_DIR}/${HAL_GENERATOR_DIR} and re-run to get a clean checkout"
fi
readonly GENERATOR_ORIGIN

# Refresh the generator's refs so a pin published after an earlier clone still
# resolves. The remote is addressed by the URL just validated rather than by the
# name 'origin', so no 'remote.origin.*' setting takes part in the fetch and git
# cannot dial a URL other than the inspected one. The refspec is forced so
# upstream's tag replaces a local tag of the same name instead of the fetch
# silently keeping the local one. A fetch failure is fatal only when the pin is
# not already present locally: rebuilding an already-cloned generator offline is
# legitimate, but building against an unresolvable pin never is.
if ! run_git -C "${HAL_GENERATOR_DIR}" fetch --quiet "${GENERATOR_ORIGIN}" "+refs/tags/*:refs/tags/*"; then
    log "warning: cannot reach ${HAL_GENERATOR_URL}; continuing only if ${HAL_GENERATOR_VERSION} is already present locally"
fi

# Resolve the pin to one exact commit before checking anything out, preferring
# the tag namespace so a branch that shares the pin's name cannot shadow it.
GENERATOR_COMMIT="$(run_git -C "${HAL_GENERATOR_DIR}" rev-parse --verify --quiet "refs/tags/${HAL_GENERATOR_VERSION}^{commit}" || true)"
if [ -z "${GENERATOR_COMMIT}" ]; then
    GENERATOR_COMMIT="$(run_git -C "${HAL_GENERATOR_DIR}" rev-parse --verify --quiet "${HAL_GENERATOR_VERSION}^{commit}" || true)"
fi
if [ -z "${GENERATOR_COMMIT}" ]; then
    fail "generator revision '${HAL_GENERATOR_VERSION}' does not exist in ${SCRIPT_DIR}/${HAL_GENERATOR_DIR}"
fi
readonly GENERATOR_COMMIT

# The tag must still name the commit this scaffold was reviewed against. If it
# does not, the tag has been moved or replaced upstream and the content behind
# the pin is not what anyone approved.
if [ "${GENERATOR_COMMIT}" != "${HAL_GENERATOR_COMMIT}" ]; then
    fail "generator tag ${HAL_GENERATOR_VERSION} resolves to ${GENERATOR_COMMIT}, but this scaffold pins ${HAL_GENERATOR_COMMIT}; the tag has moved, so refusing to build"
fi

# Check that commit out detached, then prove HEAD is it. A checkout can fail
# and leave HEAD on whatever was there before - the cloned default branch, for
# instance - and building from an unverified revision is exactly the outcome
# this check exists to prevent.
run_git -C "${HAL_GENERATOR_DIR}" checkout --quiet --detach "${GENERATOR_COMMIT}" \
    || fail "cannot check out generator revision ${HAL_GENERATOR_VERSION} (${GENERATOR_COMMIT})"

GENERATOR_HEAD="$(run_git -C "${HAL_GENERATOR_DIR}" rev-parse --verify HEAD)"
readonly GENERATOR_HEAD
if [ "${GENERATOR_HEAD}" != "${GENERATOR_COMMIT}" ]; then
    fail "generator HEAD is ${GENERATOR_HEAD}, expected ${HAL_GENERATOR_VERSION} (${GENERATOR_COMMIT}); refusing to build"
fi
# A matching HEAD does not mean the files about to run are the files at that
# commit. `git checkout --detach` keeps local modifications that do not conflict,
# so a tampered Makefile, Doxyfile.cfg or header.html survives the checkout and
# executes with HEAD still reporting the expected revision. Untracked files
# matter for the same reason: the generator's make includes what is on disk.
#
# --ignored=matching extends that to files the generator's own .gitignore hides.
# make builds its input list with `find` and doxygen reads whatever is on disk,
# so a file being ignored by git does not stop it being consumed by the build -
# and a path added under an ignored name is exactly how content is placed in the
# checkout without appearing in a default status.
#
# This runs after the checkout and immediately before make, so what is measured
# is the state of the tree that is about to be executed.
GENERATOR_DIRT="$(run_git -C "${HAL_GENERATOR_DIR}" status --porcelain --untracked-files=all --ignored=matching)"
if [ -n "${GENERATOR_DIRT}" ]; then
    printf '%s\n' "${GENERATOR_DIRT}" >&2
    fail "the generator checkout has local modifications, untracked files or ignored files (listed above); refusing to execute it - remove ${SCRIPT_DIR}/${HAL_GENERATOR_DIR} and re-run to get a clean checkout"
fi

# `git status` reports what the index tells it to. A single `git update-index`
# call sets a bit that makes status skip a tracked file however it has been
# modified on disk: --assume-unchanged, which ls-files tags with a lower-case
# letter, and --skip-worktree, which it tags S. Either one hides a tampered
# Makefile or Doxyfile.cfg from the scan above, so the flags themselves are read
# and any file carrying one is refused. A clean checkout tags every path H.
GENERATOR_INDEX="$(run_git -C "${HAL_GENERATOR_DIR}" ls-files -v)" \
    || fail "cannot read the index of '${SCRIPT_DIR}/${HAL_GENERATOR_DIR}'"
GENERATOR_INDEX_FLAGGED="$(printf '%s\n' "${GENERATOR_INDEX}" | grep -E '^([a-z]|S) ' || true)"
if [ -n "${GENERATOR_INDEX_FLAGGED}" ]; then
    printf '%s\n' "${GENERATOR_INDEX_FLAGGED}" >&2
    fail "the generator checkout has index entries marked assume-unchanged or skip-worktree (listed above), which hide a modified tracked file from the cleanliness scan; refusing to execute it - remove ${SCRIPT_DIR}/${HAL_GENERATOR_DIR} and re-run to get a clean checkout"
fi

# Second configuration and hook scan, and the reason there are two. The first
# scan measured the checkout before the first fetch; the fetch and the checkout
# that followed it both write to .git, and a fetch can bring down anything the
# remote offers, so a configuration key or a hook installed in that phase would
# have been examined by nothing at all. Repeating the scan here means every state
# this script relies on has been measured after the last write this script makes
# and before the only thing it executes. Nothing runs between this scan and make
# except the output-containment block below, which touches docs/output and never
# .git.
#
# What this does not close, stated plainly rather than glossed: check and use are
# separate opens by two different programs, so a process running as this user -
# or as root - can still replace a file between this scan and doxygen reading it,
# and no shell script can prevent that from outside the kernel. What has changed
# is the size of the window: it was the whole fetch-and-checkout phase, and it is
# now the few milliseconds between this scan and make.
refuse_generator_execution_paths "immediately before the build"

# Contain the generated site inside this repository before anything is executed.
# Every control above this point is about what the build runs; this one is about
# where the build writes. The generator writes to OUTPUT_DIRECTORY = ../output
# relative to build/, which is this docs/output, and docs/output is git-ignored -
# so nothing in git's own state, and nothing in the cleanliness scan above, stops
# output, output/html or a directory above them from being a symlink that sends
# doxygen's writes anywhere the invoking user can write. Measured before this
# block existed: with docs/output a link to a directory outside the repository the
# whole site was written there and the script exited 0, and with only
# docs/output/html a link, 48 files were written there and the script exited 0.
#
# A link is refused rather than followed or quietly replaced, at output itself
# and at every path beneath it, because the generator produces no symlinks at
# all: one here is either a mistake or a redirection, and an operator should be
# told which paths were involved rather than have them silently deleted. find is
# invoked without -H and without -L, so it never follows a link it is examining -
# including the top-level one, which is also tested directly for a clearer
# message.
#
# Containment is established before anything is created or removed, not after.
# Doing it the other way round means that a docs/ which is itself a link out of
# the repository gets an empty directory made outside the tree - and, worse, gets
# an out-of-tree directory removed - before the check that was supposed to
# prevent exactly that has run.
case "${SCRIPT_DIR_REAL}/${HAL_OUTPUT_DIR}" in
    "${REPO_ROOT_REAL}"/*) : ;;
    *) fail "the output directory would be ${SCRIPT_DIR_REAL}/${HAL_OUTPUT_DIR}, which is outside the repository at ${REPO_ROOT_REAL}; refusing to create, remove or write anything there" ;;
esac
if [ -L "${HAL_OUTPUT_DIR}" ]; then
    fail "'${SCRIPT_DIR}/${HAL_OUTPUT_DIR}' is a symlink to $(readlink -- "${HAL_OUTPUT_DIR}" 2>/dev/null || echo 'an unreadable target'); the generated site must be written to a real directory inside ${SCRIPT_DIR_REAL} - remove the link and re-run"
fi
if [ -e "${HAL_OUTPUT_DIR}" ] && [ ! -d "${HAL_OUTPUT_DIR}" ]; then
    fail "'${SCRIPT_DIR}/${HAL_OUTPUT_DIR}' exists but is not a directory; remove it and re-run"
fi
if [ -d "${HAL_OUTPUT_DIR}" ]; then
    OUTPUT_LINKS="$(find "${HAL_OUTPUT_DIR}" -type l -print 2>/dev/null || true)"
    if [ -n "${OUTPUT_LINKS}" ]; then
        printf '%s\n' "${OUTPUT_LINKS}" >&2
        fail "the output tree contains symlinks (listed above), any of which would redirect part of the generated site outside ${SCRIPT_DIR_REAL}; refusing to build - remove ${SCRIPT_DIR}/${HAL_OUTPUT_DIR} and re-run"
    fi
    # A directory cannot be hardlinked on Linux, so the only place an extra link
    # can hide is a regular file: one with a second name elsewhere on the same
    # filesystem is a file doxygen would overwrite in place, changing content the
    # other name reads. The removal below unlinks rather than follows, so finding
    # these is about telling the operator, not about safety.
    OUTPUT_HARDLINKS="$(find "${HAL_OUTPUT_DIR}" -type f -links +1 -print 2>/dev/null || true)"
    if [ -n "${OUTPUT_HARDLINKS}" ]; then
        printf '%s\n' "${OUTPUT_HARDLINKS}" >&2
        fail "the output tree contains files with more than one hard link (listed above), so a write into the generated site would also change content reachable under another name; refusing to build - remove ${SCRIPT_DIR}/${HAL_OUTPUT_DIR} and re-run"
    fi
    # Start from an empty tree, exactly as the generator's own `make clean` does,
    # so a stale page from an earlier build cannot survive alongside a new one.
    rm -rf -- "${HAL_OUTPUT_DIR}" \
        || fail "cannot remove '${SCRIPT_DIR}/${HAL_OUTPUT_DIR}'"
fi
mkdir -- "${HAL_OUTPUT_DIR}" \
    || fail "cannot create '${SCRIPT_DIR}/${HAL_OUTPUT_DIR}'"

# Now prove the directory that was just created is the one the build will write
# to and that it is inside this repository. realpath is the check the reviewer
# asked for and is used when it is present; the shell's own physical resolution
# is computed as well, both because it needs no external program on a minimal
# build host and because two independent answers that agree are worth more than
# either alone. A disagreement means the path changed under us between the two
# calls, which is a reason to stop rather than to pick one.
OUTPUT_REAL="$(cd -- "${HAL_OUTPUT_DIR}" && pwd -P)" \
    || fail "cannot enter '${SCRIPT_DIR}/${HAL_OUTPUT_DIR}' after creating it"
if command -v realpath >/dev/null 2>&1; then
    OUTPUT_REALPATH="$(realpath -- "${HAL_OUTPUT_DIR}")" \
        || fail "realpath cannot resolve '${SCRIPT_DIR}/${HAL_OUTPUT_DIR}'"
    if [ "${OUTPUT_REALPATH}" != "${OUTPUT_REAL}" ]; then
        fail "realpath resolves '${HAL_OUTPUT_DIR}' to ${OUTPUT_REALPATH} while the shell resolves it to ${OUTPUT_REAL}; the path changed while it was being checked, so refusing to build"
    fi
fi
if [ -L "${HAL_OUTPUT_DIR}" ] || [ ! -d "${HAL_OUTPUT_DIR}" ]; then
    fail "'${SCRIPT_DIR}/${HAL_OUTPUT_DIR}' is not a real directory immediately after being created; refusing to build"
fi
if [ "${OUTPUT_REAL}" != "${SCRIPT_DIR_REAL}/${HAL_OUTPUT_DIR}" ]; then
    fail "the output directory resolves to ${OUTPUT_REAL}, not ${SCRIPT_DIR_REAL}/${HAL_OUTPUT_DIR}; refusing to write the generated site through a redirected path"
fi
case "${OUTPUT_REAL}" in
    "${REPO_ROOT_REAL}"/*) : ;;
    *) fail "the output directory resolves to ${OUTPUT_REAL}, which is outside the repository at ${REPO_ROOT_REAL}; refusing to write the generated site outside the tree it documents" ;;
esac
readonly OUTPUT_REAL

log "generator ${HAL_GENERATOR_VERSION} verified at ${GENERATOR_COMMIT}: origin allowlisted, metadata self-contained, no execution-capable configuration or hook before or after the fetch, worktree and index clean, output contained at ${OUTPUT_REAL}"

# Build once, from the verified generator checkout.
log "generating '${PROJECT_NAME}' documentation at version ${PROJECT_VERSION}"
make -C "./${HAL_GENERATOR_DIR}" PROJECT_NAME="${PROJECT_NAME}" PROJECT_VERSION="${PROJECT_VERSION}" \
    || fail "documentation build failed for '${PROJECT_NAME}'"

log "documentation written to ${OUTPUT_REAL}/html"
