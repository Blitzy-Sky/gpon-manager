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

# WHAT THIS SCRIPT ENFORCES, stated because a developer running it should know.
# It fails closed. Before Make is invoked, './build' must be a git checkout of the official
# generator repository named below, sitting on the exact commit that the pin below names,
# with no local modifications; the project version must be a usable string; and every git
# operation must have succeeded. Anything else aborts with a message on stderr and a
# non-zero exit status, so the site is never generated from an unknown generator and a
# failure is never reported as success. Nothing is fetched or written when './build' is
# already the pinned generator, so an established checkout builds with no network access.

set -o pipefail

# Report the reason on stderr and exit non-zero. Every refusal below goes through here, so a
# caller - a developer or a CI job - always sees why the build did not happen.
die() {
    echo "generate_docs.sh: refusing to build: $*" >&2
    exit 1
}

# The generator repository. This is both what a first run clones and the provenance that
# every later run is checked against.
HAL_GENERATOR_URL="git@github.com:rdkcentral/hal-doxygen.git"

# In the future this should moved to a fixed verison
HAL_GENERATOR_VERSION=1.2.0

# The generator checkout, relative to this script's own directory.
HAL_GENERATOR_DIR="./build"

# This will look up the last tag in the git repo, depending on the project this may require modification
PROJECT_VERSION=$(git describe --tags | head -n1) ||
    die "'git describe --tags' failed, so this repository's version cannot be determined"

# The version string comes from a git tag, which is data rather than a trusted
# constant: git accepts a tag name containing ';', '`', '$(', '|' or '&', and make
# expands a command-line variable recursively and exports it into every recipe's
# shell, so such a tag would be executed rather than printed. Accept only the
# characters a version string needs, and refuse to build otherwise rather than
# label the site with something unusable.
case "${PROJECT_VERSION}" in
    "" | *[!A-Za-z0-9._+-]*)
        die "'git describe --tags' produced an unusable version string"
        ;;
esac

# Check if the common document configuration is present, if not clone it. A path that exists
# but is not a directory, or a directory that is not a checkout - what an interrupted or
# failed clone leaves behind - is refused rather than built from.
if [ -e "${HAL_GENERATOR_DIR}" ] && [ ! -d "${HAL_GENERATOR_DIR}" ]; then
    die "'${HAL_GENERATOR_DIR}' exists but is not a directory"
fi

if [ -d "${HAL_GENERATOR_DIR}" ]; then
    [ -e "${HAL_GENERATOR_DIR}/.git" ] ||
        die "'${HAL_GENERATOR_DIR}' exists but is not a git checkout; remove it and run this script again"
else
    echo "Cloning Common documentation generation"
    git clone "${HAL_GENERATOR_URL}" build ||
        die "cloning the documentation generator from ${HAL_GENERATOR_URL} failed"
    [ -e "${HAL_GENERATOR_DIR}/.git" ] ||
        die "cloning the documentation generator left no git checkout in '${HAL_GENERATOR_DIR}'"
fi

# Provenance: the checkout has to be the official generator, not another repository that
# happens to occupy this path.
hal_generator_origin=$(git -C "${HAL_GENERATOR_DIR}" config --get remote.origin.url) ||
    die "'${HAL_GENERATOR_DIR}' has no 'origin' remote, so it cannot be identified as the documentation generator"
[ "${hal_generator_origin}" = "${HAL_GENERATOR_URL}" ] ||
    die "'${HAL_GENERATOR_DIR}' has origin '${hal_generator_origin}' instead of ${HAL_GENERATOR_URL}"

# Resolve the pin to a commit. Tags are fetched only when the pin is not already known
# locally, which is what keeps an already-correct checkout free of network access.
hal_generator_pin_commit=$(git -C "${HAL_GENERATOR_DIR}" rev-parse --verify --quiet "${HAL_GENERATOR_VERSION}^{commit}")
if [ -z "${hal_generator_pin_commit}" ]; then
    git -C "${HAL_GENERATOR_DIR}" fetch --quiet --tags origin ||
        die "fetching tags from ${HAL_GENERATOR_URL} failed, so generator ${HAL_GENERATOR_VERSION} cannot be resolved"
    hal_generator_pin_commit=$(git -C "${HAL_GENERATOR_DIR}" rev-parse --verify --quiet "${HAL_GENERATOR_VERSION}^{commit}")
    [ -n "${hal_generator_pin_commit}" ] ||
        die "generator ${HAL_GENERATOR_VERSION} does not exist in ${HAL_GENERATOR_URL}"
fi

# Check the pin out only when the checkout is not already on it, then confirm the checkout
# actually moved: a checkout that reports success but leaves a different HEAD would build
# the site from the wrong generator.
hal_generator_head_commit=$(git -C "${HAL_GENERATOR_DIR}" rev-parse --verify HEAD) ||
    die "'${HAL_GENERATOR_DIR}' has no resolvable HEAD"
if [ "${hal_generator_head_commit}" != "${hal_generator_pin_commit}" ]; then
    git -C "${HAL_GENERATOR_DIR}" checkout --quiet "${HAL_GENERATOR_VERSION}" ||
        die "checking generator ${HAL_GENERATOR_VERSION} out in '${HAL_GENERATOR_DIR}' failed"
    hal_generator_head_commit=$(git -C "${HAL_GENERATOR_DIR}" rev-parse --verify HEAD) ||
        die "'${HAL_GENERATOR_DIR}' has no resolvable HEAD after checking out generator ${HAL_GENERATOR_VERSION}"
    [ "${hal_generator_head_commit}" = "${hal_generator_pin_commit}" ] ||
        die "'${HAL_GENERATOR_DIR}' is at ${hal_generator_head_commit}, not generator ${HAL_GENERATOR_VERSION} (${hal_generator_pin_commit})"
fi

# A modified generator is not the generator the pin names. Untracked files are ignored on
# purpose: the generator's own tooling writes some, and they change none of its tracked
# configuration.
hal_generator_local_changes=$(git -C "${HAL_GENERATOR_DIR}" status --porcelain --untracked-files=no) ||
    die "the state of '${HAL_GENERATOR_DIR}' could not be determined"
[ -z "${hal_generator_local_changes}" ] ||
    die "'${HAL_GENERATOR_DIR}' has local modifications; restore it to generator ${HAL_GENERATOR_VERSION} and run this script again"

# Generate the site. The Make invocation is kept in the corpus's literal form, matching the
# fourteen unchanged sibling scripts, and Make's own exit status is propagated so a caller
# sees the real failure rather than this script's.
make -C ./build PROJECT_NAME="RDK-B GPON HAL" PROJECT_VERSION="${PROJECT_VERSION}"
hal_generator_make_status=$?
if [ "${hal_generator_make_status}" -ne 0 ]; then
    echo "generate_docs.sh: documentation generation failed: make exited ${hal_generator_make_status}" >&2
    exit "${hal_generator_make_status}"
fi
