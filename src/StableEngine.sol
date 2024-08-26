// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {IStableCoin} from "./interfaces/IStableCoin.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract StableEngine is OApp, IERC721Receiver {
    // ====================
    // === STORAGE VARS ===
    // ====================

    string public data;

    // Stablecoin vars
    mapping(address => uint256) public stablecoinsMinted;
    address public stableCoinContract;

    // NFT vars
    address[] public whitelistedNFTs;
    address[] public nftOracles;
    mapping(address nftAddress => mapping(uint256 tokenId => address supplier)) public
        nftCollectionTokenIdToSupplierAddress;
    mapping(address user => mapping(address nftAddress => uint256 count)) public userAddressToNftCollectionSuppliedCount;
    mapping(address supplier => uint256 nftSupplied) public numberOfNftsUserHasSupplied;
    mapping(address user => uint256 stablecoinsMinted) public userAddressToNumberOfStablecoinsMinted;

    // CR and Health Factor vars
    uint256 public COLLATERALISATION_RATIO = 5e17; // aka 50%
    uint256 public MIN_HEALTH_FACTOR = 1e18; // aka 1.0

    enum ChainSelection {
        Base,
        Optimism
    }

    // ==============
    // === ERRORS ===
    // ==============

    error UserDidNotSupplyTheNFTOriginally(uint256 tokenId);
    error UserHasOutstandingDebt(uint256 outstandingDebt);
    error mintFailed();
    error ChainNotSpecified();
    error NoNftsCurrentlySupplied();
    error Error__NftIsNotAcceptedCollateral();

    // ==============
    // === EVENTS ===
    // ==============

    event NftSuppliedToContract(address indexed _nftAddress, uint256 indexed _tokenId);
    event NftWithdrawnByUser(address indexed user, uint256 indexed tokenId);
    event MintOnChainFunctionSuccessful();

    constructor(address _endpoint) OApp(_endpoint, msg.sender) Ownable() {}

    // ================================
    // === SUPPLY NFT AS COLLATERAL ===
    // ================================

    // @todo MAKE NON-REENTRANT
    function supply(address _nftAddress, uint256 _tokenId) public {
        // *** EOA has to call approve() on the NFT contract to allow this contract to take control of the NFT id number ***

        // check if nft is acceptable collateral
        for (uint256 i = 0; i < whitelistedNFTs.length; i++) {
            if (whitelistedNFTs[i] == _nftAddress) {
                break;
            } else {
                revert Error__NftIsNotAcceptedCollateral();
            }
        }

        // accept NFT into the contract
        IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);

        // update mapping to account for who can withdraw a specific NFT tokenId
        nftCollectionTokenIdToSupplierAddress[_nftAddress][_tokenId] = msg.sender;

        // we always liquidate at floor price, so just need to count how many of each collection they've supplied
        userAddressToNftCollectionSuppliedCount[msg.sender][_nftAddress]++;

        numberOfNftsUserHasSupplied[msg.sender]++;

        emit NftSuppliedToContract(_nftAddress, _tokenId);
    }

    // ====================
    // === WITHDRAW NFT ===
    // ====================

    function withdraw(address _nftAddress, uint256 _tokenId) public {
        // check that the requested tokenId is the one the user supplied initially
        if (msg.sender == nftCollectionTokenIdToSupplierAddress[_nftAddress][_tokenId]) {
            // check if a user has an outstanding loan (stablecoin minted) balance
            if (userAddressToNumberOfStablecoinsMinted[msg.sender] == 0) {
                // if both are ok, transfer the NFT to them
                IERC721(_nftAddress).transferFrom(address(this), msg.sender, _tokenId);

                nftCollectionTokenIdToSupplierAddress[_nftAddress][_tokenId] = address(0x0); // zero out address that supplied this NFT token id
                userAddressToNftCollectionSuppliedCount[msg.sender][_nftAddress]--;
                numberOfNftsUserHasSupplied[msg.sender]--;

                emit NftWithdrawnByUser(msg.sender, _tokenId);
            } else {
                revert UserHasOutstandingDebt(userAddressToNumberOfStablecoinsMinted[msg.sender]);
            }
        } else {
            revert UserDidNotSupplyTheNFTOriginally(_tokenId);
        }
    }

    // =========================
    // === MINT OMNI-STABLES ===
    // =========================

    function mintOnDestination(
        uint32 _dstEid,
        string memory _message,
        uint256 _numberToMint,
        uint256 _selection,
        address _recipient,
        bytes calldata _options
    ) external payable {
        // has user supplied an nft as collateral
        if (numberOfNftsUserHasSupplied[msg.sender] == 0) {
            revert NoNftsCurrentlySupplied();
        }

        // calculate amount of stables that user can mint against their entire collateral
        uint256 totalValueOfAllCollateral = nftPriceInUsd() * numberOfNftsUserHasSupplied[msg.sender]; // @todo change to account of different collections and prices
        uint256 availableToBorrowAtMaxCR = (totalValueOfAllCollateral * COLLATERALISATION_RATIO) / 1e18; // 50% of nft price
        uint256 maxStablecoinCanBeMinted = availableToBorrowAtMaxCR - userAddressToNumberOfStablecoinsMinted[msg.sender];

        //
        if (_numberToMint <= maxStablecoinCanBeMinted) {
            bytes memory _payload = abi.encode(_message, _numberToMint, _selection, _recipient); // Encode the message as bytes
            _lzSend(
                _dstEid,
                _payload,
                _options,
                MessagingFee(msg.value, 0), // Fee for the message (nativeFee, lzTokenFee)
                payable(msg.sender) // The refund address in case the send call reverts
            );
        }
    }

    function externalMintToInternalMint(
        uint32 _dstEid,
        string memory _message,
        uint256 _numberToMint,
        uint256 _selection,
        address _recipient,
        bytes calldata _options
    ) external payable {
        _internalMintOnOptimism(_dstEid, _message, _numberToMint, _selection, _recipient, _options);
    }

    function _internalMintOnOptimism(
        uint32 _dstEid,
        string memory _message,
        uint256 _numberToMint,
        uint256 _selection,
        address _recipient,
        bytes calldata _options
    ) internal {
        // has user supplied an nft as collateral
        if (numberOfNftsUserHasSupplied[msg.sender] == 0) {
            revert NoNftsCurrentlySupplied();
        }

        uint256 totalValueOfAllCollateral = nftPriceInUsd() * numberOfNftsUserHasSupplied[msg.sender];
        uint256 availableToBorrowAtMaxCR = (totalValueOfAllCollateral * COLLATERALISATION_RATIO) / 1e18; // 50% of nft price

        uint256 maxStablecoinCanBeMinted = availableToBorrowAtMaxCR - userAddressToNumberOfStablecoinsMinted[msg.sender];

        if (_numberToMint <= maxStablecoinCanBeMinted) {
            bytes memory _payload = abi.encode(_message, _numberToMint, _selection, _recipient); // Encode the message as bytes
            _lzSend(
                _dstEid,
                _payload,
                _options,
                MessagingFee(msg.value, 0), // Fee for the message (nativeFee, lzTokenFee)
                payable(msg.sender) // The refund address in case the send call reverts
            );
        }
    }

    // ======================
    // === NFT PRICE FEED ===
    // ======================

    function nftPriceInUsd() internal view returns (uint256) {
        return 36000e18;
    }

    // ===============================
    // === LAYERZERO FUNCTIONALITY ===
    // ===============================

    /// @notice Sends a message from the source chain to the destination chain.
    /// @param _dstEid The endpoint ID of the destination chain.
    /// @param _message The message to be sent.
    /// @param _options The message execution options (e.g. gas to use on destination).
    function sendMessage(
        uint32 _dstEid,
        string memory _message,
        uint256 _numberToMint,
        uint256 _selection,
        address _recipient,
        bytes calldata _options
    ) external payable {
        bytes memory _payload = abi.encode(_message, _numberToMint, _selection, _recipient); // Encode the message as bytes
        _lzSend(
            _dstEid,
            _payload,
            _options,
            MessagingFee(msg.value, 0), // Fee for the message (nativeFee, lzTokenFee)
            payable(msg.sender) // The refund address in case the send call reverts
        );
    }

    /// @notice Estimates the gas associated with sending a message.
    /// @param _dstEid The endpoint ID of the destination chain.
    /// @param _message The message to be sent.
    /// @param _options The message execution options (e.g. gas to use on destination).
    /// @return nativeFee Estimated gas fee in native gas.
    /// @return lzTokenFee Estimated gas fee in ZRO token.
    function estimateFee(
        uint32 _dstEid,
        string memory _message,
        uint256 _numberToMint,
        uint256 _selection,
        address _recipient,
        bytes calldata _options
    ) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
        bytes memory _payload = abi.encode(_message, _numberToMint, _selection, _recipient);
        MessagingFee memory fee = _quote(_dstEid, _payload, _options, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }

    /// @notice Entry point for receiving messages.
    /// @param _origin The origin information containing the source endpoint and sender address.
    ///  - srcEid: The source chain endpoint ID.
    ///  - sender: The sender address on the src chain.
    ///  - nonce: The nonce of the message.
    /// @param _guid The unique identifier for the received LayerZero message.
    /// @param payload The payload of the received message.
    /// @param _executor The address of the executor for the received message.
    /// @param _extraData Additional arbitrary data provided by the corresponding executor.
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address _executor,
        bytes calldata _extraData
    ) internal override {
        // decode our incoming payload
        (string memory _data, uint256 numberOfCoins, uint256 selection, address recipient) =
            abi.decode(payload, (string, uint256, uint256, address));
        // set storage var 'data' to the incoming string
        data = _data;
        callStableEngineContractAndMint(recipient, numberOfCoins);
    }

    function callStableEngineContractAndMint(address _recipient, uint256 _numberOfCoins) internal {
        IStableCoin(stableCoinContract).mint(_recipient, _numberOfCoins);
    }

    function setStableCoin(address _stableCoin) external onlyOwner {
        stableCoinContract = _stableCoin;
    }

    function setNftAsCollateral(address _nftAddress, address _nftOracle, uint256 _index) external onlyOwner {
        whitelistedNFTs.push(_nftAddress);
        nftOracles.push(_nftOracle);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
