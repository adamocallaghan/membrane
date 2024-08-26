// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract StableCoin is OFT {
    address public stableEngine;

    error Error__NotStableEngine();

    event Mint(address recipient, uint256 amount);

    constructor(string memory oftName, string memory oftSymbol, address lzEndpoint, address _stableEngine)
        OFT(oftName, oftSymbol, lzEndpoint, msg.sender)
        Ownable()
    {
        // _mint(msg.sender, 100 ether);
        stableEngine = _stableEngine;
    }

    function mint(address _recipient, uint256 _amountToMint) external onlyStableEngine {
        _mint(_recipient, _amountToMint);
        emit Mint(_recipient, _amountToMint);
    }

    modifier onlyStableEngine() {
        if (msg.sender != stableEngine) {
            revert Error__NotStableEngine();
        }
        _;
    }
}
