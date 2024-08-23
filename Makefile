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

# ESTIMATE GAS FEE

estimate-gas-fee-base:
	cast call $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) "estimateFee(uint32, string, uint, address, bytes)(uint,uint)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) "Hello World" 12345 $(DEPLOYER_PUBLIC_ADDRESS) $(MESSAGE_OPTIONS_BYTES) --account deployer

# SEND MESSAGE

send-message-from-base-to-optimism:
	cast send $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) --value 0.01ether "sendMessage(uint32, string, uint, address, bytes)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) "Hello World" 12345 $(DEPLOYER_PUBLIC_ADDRESS) $(MESSAGE_OPTIONS_BYTES) --account deployer

# READ MESSSAGE ON OP

read-data-var-on-optimism:
	cast call $(OPTIMISM_SEPOLIA_OAPP_ADDRESS) --rpc-url $(OPTIMISM_SEPOLIA_RPC) "data()(string)" --account deployer

read-stablecoins-minted-on-optimism:
	cast call $(OPTIMISM_SEPOLIA_OAPP_ADDRESS) --rpc-url $(OPTIMISM_SEPOLIA_RPC) "stablecoinsMinted(address)(uint)" $(DEPLOYER_PUBLIC_ADDRESS) --account deployer