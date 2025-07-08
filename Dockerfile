
# Use a Node.js base image
FROM node:20-slim

# Set the working directory
WORKDIR /app

# Install Node.js dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Install solc globally for Hardhat
RUN npm install -g solc@0.8.20

# Copy the rest of the project files
COPY . .

# Install necessary packages for Foundry
RUN apt-get update && apt-get install -y curl git &&     curl -L https://foundry.paradigm.xyz | bash
RUN curl -L https://foundry.paradigm.xyz | bash &&     export PATH="/root/.foundry/bin:$PATH" &&     forge install

# Set the default command to run the 'start' target from the Makefile
CMD ["make", "start"]
