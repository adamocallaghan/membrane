// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {StableCoin} from "../src/StableCoin.sol";
import {StableEngine} from "../src/StableEngine.sol";
import {NFTMock} from "../src/NFTMock.sol";

contract StableEngineTest is Test {
    uint256 baseSepoliaFork;

    NFTMock public nft;
    StableEngine public oapp;
    StableCoin public oft;

    string BASE_SEPOLIA_RPC_URL = vm.envString("BASE_SEPOLIA_RPC");
    address BASE_SEPOLIA_LZ_ENDPOINT = vm.envAddress("BASE_SEPOLIA_LZ_ENDPOINT");

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 bobNftZero;
    uint256 bobNftOne;
    uint256 bobNftTwo;

    uint256 aliceNftZero;
    uint256 aliceNftOne;
    uint256 aliceNftTwo;

    function setUp() external {
        // fork arb sepolia & change to specific block for consistency
        baseSepoliaFork = vm.createFork(BASE_SEPOLIA_RPC_URL);
        vm.selectFork(baseSepoliaFork);
        // vm.rollFork(19742210);

        // mint eth to bob & alice
        vm.deal(bob, 1000e18);
        vm.deal(alice, 1000e18);

        // instantiate contracts
        nft = new NFTMock();
        oapp = new StableEngine(address(BASE_SEPOLIA_LZ_ENDPOINT));
        // oft = new StableCoin("Ominstable Test", "OMNIST", ARB_SEPOLIA_LZ_ENDPOINT);

        // set oft contract address on our oapp - so it knows what contract
        oapp.setNftAsCollateral(address(nft), 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1, 0);

        // transfer oft ownership to our oapp - so it can mint the stablecoins
        // oft.transferOwnership(address(oapp));

        // mint nfts to bob
        vm.prank(bob);
        bobNftZero = nft.mint();
        bobNftOne = nft.mint();
        bobNftTwo = nft.mint();

        // mint nfts to alice
        vm.prank(alice);
        aliceNftZero = nft.mint();
        aliceNftOne = nft.mint();
        aliceNftTwo = nft.mint();
    }

    function testSupplyNftIntoContract() public {
        // Bob supplies nft to contract
        supplyNftToProtocol();

        // does contract now have nft?
        address newNftOwner = IERC721(nft).ownerOf(bobNftZero); // tokenId 0 supplied to contract
        assertEq(newNftOwner, address(oapp)); // the oapp contract should own the nft now
    }

    function testWithdrawNftFromContract() public {
        // Bob supplies nft to contract
        supplyNftToProtocol();

        // Bob withdraws nft from contract
        withdrawNftFromProtocol();

        // does Bob own the nft once again?
        address newNftOwner = IERC721(nft).ownerOf(0); // tokenId 0 withdrawn to bob's account again
        assertEq(newNftOwner, bob);
    }

    // ===============
    // === HELPERS ===
    // ===============

    function supplyNftToProtocol() public {
        // Bob supplies nft to contract
        vm.startPrank(bob);
        IERC721(nft).approve(address(oapp), bobNftZero);
        oapp.supply(address(nft), bobNftZero);
        vm.stopPrank();
    }

    function withdrawNftFromProtocol() public {
        vm.startPrank(bob);
        oapp.withdraw(address(nft), bobNftZero);
        vm.stopPrank();
    }

    function getNftFloorPriceInUsd() public pure returns (uint256) {
        return 32000;
    }
}
