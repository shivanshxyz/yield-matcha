#!/usr/bin/env bash
set -euo pipefail

TARGET_VERSION="0.8.24"

# Only touch first-party sources
find contracts src test -type f -name "*.sol" | while read -r file; do
  # use portable sed
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/pragma solidity =${TARGET_VERSION};/pragma solidity ^${TARGET_VERSION};/g" "$file"
  else
    sed -i "s/pragma solidity =${TARGET_VERSION};/pragma solidity ^${TARGET_VERSION};/g" "$file"
  fi
done

echo "✅ Solidity pragmas updated to ^${TARGET_VERSION}"
