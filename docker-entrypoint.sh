#!/bin/sh

# Copyright © 2021, PhotoStructure Inc.

# BY RUNNING THIS SOFTWARE YOU AGREE TO ALL THE TERMS OF THIS LICENSE:
# <https://photostructure.com/eula>

# See <https://photostructure.com/server> for instructions and
# <https://forum.photostructure.com/> for support.

# Propagate ctrl-c while we're still in this script:
trap 'exit 130' INT

# Tell PhotoStructure that we're running in a docker container:
export PS_IS_DOCKER="1"

# Tell node to run in production:
export NODE_ENV="production"

# Node was already installed into /usr/local/bin:
export PATH="${PATH}:/usr/local/bin:/ps/app:/ps/app/bin"

# Prior to v1.0, PhotoStructure for Docker defaulted to running as root. To
# prevent upgrades from failing due to permission issues, let's default the UID
# and GID to match the current owner of the system settings.toml file.

# This default value will be overridden if UID, GID, PUID, or PGID are set.

# If the file is missing, we default to 1000 for both the UID and GID, which are
# the default ids given to the first non-system user (at least in Ubuntu and
# Fedora).

DEFAULT_UID=$(stat -c %u /ps/config/settings.toml 2>/dev/null || echo 1000)
DEFAULT_GID=$(stat -c %g /ps/config/settings.toml 2>/dev/null || echo 1000)

# Accept either UID or PUID:
export UID=${UID:-${PUID:-${DEFAULT_UID}}}

# Accept either GID or PGID:
export GID=${GID:-${PGID:-${DEFAULT_GID}}}

# Accept UMASK:
umask "${UMASK:-0022}"

if [ -x "$PS_RUN_AT_STARTUP" ] ; then
  "$PS_RUN_AT_STARTUP"
fi

# Let the user shell into the container:
if [ "$*" = "sh" ] || [ "$*" = "dash" ] || [ "$*" = "bash" ]; then
  exec "$*"
elif [ "$UID" = "0" ] || [ "$(id --real --user)" != "0" ]; then
  # They either want to run as root, or started docker with --user, so we
  # shouldn't do any usermod/groupmod/su shenanigans.

  # We `exec` to replace the current shell so nothing is between tini and node:
  exec /usr/local/bin/node /ps/app/photostructure "$@"
else
  # Change the node user and group to match UID/GID.
  # (we don't care about "usermod: no changes"):
  usermod --non-unique --uid "$UID" node >/dev/null
  groupmod --non-unique --gid "$GID" node

  # Always make sure the settings, opened-by, and models directories are
  # read/writable by node:
  chown --silent --recursive node:node /ps/library/.photostructure/settings.toml /ps/library/.photostructure/opened-by /ps/library/.photostructure/models

  # Start photostructure as the user "node" instead of root.

  # We `exec` to replace the current shell so nothing is between tini and node:
  exec su --preserve-environment node --command "/usr/local/bin/node /ps/app/photostructure $*"
fi
