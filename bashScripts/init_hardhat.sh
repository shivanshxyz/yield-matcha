#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Initializing npm project..."
npm init -y

echo "Installing Hardhat and dependencies..."
npm i --save-dev hardhat @nomicfoundation/hardhat-toolbox @nomicfoundation/hardhat-foundry

echo "Creating hardhat.config.ts..."
cat <<EOT > hardhat.config.ts
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
};

export default config;
EOT

echo "Creating project directories..."
mkdir -p contracts test scripts

echo "Hardhat project initialized successfully!"
echo "You can now run your hardhat commands."
