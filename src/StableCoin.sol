// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract OFT_Sepolia is OFT {
    address public stableEngine;

    error Error__NotStableEngine();

    constructor(string memory oftName, string memory oftSymbol, address lzEndpoint, address _stableEngine)
        OFT(oftName, oftSymbol, lzEndpoint, msg.sender)
        Ownable()
    {
        // _mint(msg.sender, 100 ether);
        stableEngine = _stableEngine;
    }

    function mint(address _recipient, uint256 _amountToMint) external onlyStableEngine {
        _mint(_recipient, _amountToMint);
    }

    modifier onlyStableEngine() {
        if (msg.sender != stableEngine) {
            revert Error__NotStableEngine();
        }
        _;
    }
}
