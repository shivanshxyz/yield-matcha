#!/bin/bash

# This script finds all .sol files in the current directory and its subdirectories,
# and replaces "pragma solidity =0.8.20;" with "pragma solidity ^0.8.20;"

find . -type f -name "*.sol" -exec sed -i 's/pragma solidity =0.8.20;/pragma solidity ^0.8.20;/g' {} +
        
echo "✅ Solidity pragmas updated to ^${TARGET_VERSION}"
