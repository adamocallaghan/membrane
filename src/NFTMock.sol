// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTMock is ERC721 {
    string _name = "Fuzzy Penguins";
    string _symbol = "FZYPNG";

    uint256 count = 0;

    constructor() ERC721(_name, _symbol) {}

    function mint() public returns (uint256 tokenId) {
        _mint(msg.sender, count);
        count++;
        return count - 1;
    }
}
