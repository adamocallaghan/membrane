pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/StableEngine.sol";

contract StableEngineScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("deployer");
        vm.startBroadcast(deployerPrivateKey);

        string memory OPTIMISM_LZ_ENDPOINT = "BASE_SEPOLIA_LZ_ENDPOINT";

        StableEngine oapp = new StableEngine(vm.envAddress(OPTIMISM_LZ_ENDPOINT));

        vm.stopBroadcast();
    }
}
