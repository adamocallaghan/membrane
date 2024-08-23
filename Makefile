-include .env

# DEPLOY CONTRACTS

deploy-to-base:
	forge create ./src/ExampleContract.sol:ExampleContract --rpc-url $(BASE_SEPOLIA_RPC) --constructor-args $(BASE_SEPOLIA_LZ_ENDPOINT) --account deployer

deploy-to-optimism:
	forge create ./src/ExampleContract.sol:ExampleContract --rpc-url $(OPTIMISM_SEPOLIA_RPC) --constructor-args $(OPTIMISM_SEPOLIA_LZ_ENDPOINT) --account deployer

# SET PEERS / WIRE UP

set-base-peer:
	cast send $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) "setPeer(uint32, bytes32)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) $(OPTIMISM_SEPOLIA_OAPP_BYTES32) --account deployer

set-optimism-peer:
	cast send $(OPTIMISM_SEPOLIA_OAPP_ADDRESS) --rpc-url $(OPTIMISM_SEPOLIA_RPC) "setPeer(uint32, bytes32)" $(BASE_SEPOLIA_LZ_ENDPOINT_ID) $(BASE_SEPOLIA_OAPP_BYTES32) --account deployer