-include .env

# DEPLOY OAPP CONTRACTS

deploy-to-base:
	forge create ./src/StableEngine.sol:StableEngine --rpc-url $(BASE_SEPOLIA_RPC) --constructor-args $(BASE_SEPOLIA_LZ_ENDPOINT) --account deployer

deploy-to-optimism:
	forge create ./src/StableEngine.sol:StableEngine --rpc-url $(OPTIMISM_SEPOLIA_RPC) --constructor-args $(OPTIMISM_SEPOLIA_LZ_ENDPOINT) --account deployer

# SET PEERS / WIRE UP

set-base-peer:
	cast send $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) "setPeer(uint32, bytes32)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) $(OPTIMISM_SEPOLIA_OAPP_BYTES32) --account deployer

set-optimism-peer:
	cast send $(OPTIMISM_SEPOLIA_OAPP_ADDRESS) --rpc-url $(OPTIMISM_SEPOLIA_RPC) "setPeer(uint32, bytes32)" $(BASE_SEPOLIA_LZ_ENDPOINT_ID) $(BASE_SEPOLIA_OAPP_BYTES32) --account deployer

# ESTIMATE GAS FEE

estimate-gas-fee-base-select-zero:
	cast call $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) "estimateFee(uint32, string, uint, uint, address, bytes)(uint,uint)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) "Hello World" 12345 0 $(DEPLOYER_PUBLIC_ADDRESS) $(MESSAGE_OPTIONS_BYTES) --account deployer

estimate-gas-fee-base-select-one:
	cast call $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) "estimateFee(uint32, string, uint, uint, address, bytes)(uint,uint)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) "Hello World" 12345 1 $(DEPLOYER_PUBLIC_ADDRESS) $(MESSAGE_OPTIONS_BYTES) --account deployer

estimate-gas-fee-base-select-two:
	cast call $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) "estimateFee(uint32, string, uint, uint, address, bytes)(uint,uint)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) "Hello World" 54321 2 $(DEPLOYER_PUBLIC_ADDRESS) $(MESSAGE_OPTIONS_BYTES) --account deployer

# SEND MESSAGE

send-message-from-base-to-optimism-select-zero:
	cast send $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) --value 0.01ether "sendMessage(uint32, string, uint, uint, address, bytes)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) "Hello World" 12345 0 $(DEPLOYER_PUBLIC_ADDRESS) $(MESSAGE_OPTIONS_BYTES) --account deployer

send-message-from-base-to-optimism-select-one:
	cast send $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) --value 0.01ether "sendMessage(uint32, string, uint, uint, address, bytes)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) "Hello World" 345 1 $(DEPLOYER_PUBLIC_ADDRESS) $(MESSAGE_OPTIONS_BYTES) --account deployer

send-message-from-base-to-optimism-select-two:
	cast send $(BASE_SEPOLIA_OAPP_ADDRESS) --rpc-url $(BASE_SEPOLIA_RPC) --value 0.01ether "sendMessage(uint32, string, uint, uint, address, bytes)" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT_ID) "Hello World" 54321 2 $(DEPLOYER_PUBLIC_ADDRESS) $(MESSAGE_OPTIONS_BYTES) --account deployer

# READ MESSSAGE ON OP

read-data-var-on-optimism:
	cast call $(OPTIMISM_SEPOLIA_OAPP_ADDRESS) --rpc-url $(OPTIMISM_SEPOLIA_RPC) "data()(string)" --account deployer

read-stablecoins-minted-on-optimism:
	cast call $(OPTIMISM_SEPOLIA_OAPP_ADDRESS) --rpc-url $(OPTIMISM_SEPOLIA_RPC) "stablecoinsMinted(address)(uint)" $(DEPLOYER_PUBLIC_ADDRESS) --account deployer

# DEPLOY OFT CONTRACTS

deploy-oft-to-optimism:
	forge create ./src/StableCoin.sol:StableCoin --rpc-url $(OPTIMISM_SEPOLIA_RPC) --constructor-args "Spectre USD" "spUSD" $(OPTIMISM_SEPOLIA_LZ_ENDPOINT) $(OPTIMISM_SEPOLIA_OAPP_ADDRESS) --account deployer

# SET STABLECOIN *on* STABLEENGINE *on* OPTIMISM

set-stablecoin-on-stableengine-sepolia:
	cast send $(OPTIMISM_SEPOLIA_OAPP_ADDRESS) --rpc-url $(OPTIMISM_SEPOLIA_RPC) "setStableCoin(address)" $(OPTIMISM_SEPOLIA_OFT_ADDRESS) --account deployer

# CHECK STABLECOIN CONTRACT FOR DEPLOYER BALANCE
check-balance-on-stablecoin-optimism:
	cast call $(OPTIMISM_SEPOLIA_OFT_ADDRESS) --rpc-url $(OPTIMISM_SEPOLIA_RPC) "balanceOf(address)(uint)" $(DEPLOYER_PUBLIC_ADDRESS) --account deployer