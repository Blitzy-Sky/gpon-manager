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

# In the future this should moved to a fixed verison
HAL_GENERATOR_VERSION=1.2.0

# This will look up the last tag in the git repo, depending on the project this may require modification
PROJECT_VERSION=$(git describe --tags | head -n1)

# The version string comes from a git tag, which is data rather than a trusted
# constant: git accepts a tag name containing ';', '`', '$(', '|' or '&', and make
# expands a command-line variable recursively and exports it into every recipe's
# shell, so such a tag would be executed rather than printed. Accept only the
# characters a version string needs, and refuse to build otherwise rather than
# label the site with something unusable.
case "${PROJECT_VERSION}" in
    "" | *[!A-Za-z0-9._+-]*)
        echo "generate_docs.sh: refusing to build: 'git describe --tags' produced an unusable version string" >&2
        exit 1
        ;;
esac

# WHAT THIS SCRIPT DOES NOT VERIFY, stated because a developer running it should know.
# The flow below is the corpus form used by all eighteen RDK-B HAL repositories, and it
# reuses whatever `./build` already contains, does not prove that checkout's origin, pinned
# commit or cleanliness, and continues past a failed clone, cd or checkout. So the pin above
# names what a first clone fetches, not necessarily what a later run executes. Delete
# `docs/build` to force a fresh clone if that matters. The reviewed build path
# (/opt/halspec-gates/gate1.sh) performs those checks and refuses rather than warns; this
# script deliberately does not, because AAP 0.8.2 excludes the documentation toolchain from
# this change and AAP 0.9.1 holds these four scripts to the fourteen frozen siblings' form.

# Check if the common document configuration is present, if not clone it
if [ -d "./build" ]; then
    make -C ./build PROJECT_NAME="RDK-B GPON HAL" PROJECT_VERSION=${PROJECT_VERSION}
else
    echo "Cloning Common documentation generation"
    git clone git@github.com:rdkcentral/hal-doxygen.git build
    cd ./build
    git checkout ${HAL_GENERATOR_VERSION}
    cd ..
    ./${0}
fi
