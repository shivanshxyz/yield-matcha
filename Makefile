start:
	$(MAKE) hardhat
	forge install
build:
	$(MAKE) sync_solidity_compiler
	forge build

hardhat:
	@chmod +x bashScripts/init_hardhat.sh
	@bashScripts/init_hardhat.sh

sync_solidity_compiler:
	@chmod +x bashScripts/update_solidity_version.sh
	@bashScripts/update_solidity_version.sh
