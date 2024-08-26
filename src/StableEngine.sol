// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {IStableCoin} from "./interfaces/IStableCoin.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract StableEngine is OApp, IERC721Receiver {
    string public data;
    mapping(address => uint256) public stablecoinsMinted;
    address public stableCoinContract;
    address[] public whitelistedNFTs;
    address[] public nftOracles;
    mapping(address nftAddress => mapping(uint256 tokenId => address supplier)) public
        nftCollectionTokenIdToSupplierAddress;
    mapping(address supplier => uint256 nftSupplied) public numberOfNftsUserHasSupplied;
    mapping(address user => uint256 stablecoinsMinted) public userAddressToNumberOfStablecoinsMinted;

    uint256 public COLLATERALISATION_RATIO = 5e17; // aka 50%
    uint256 public MIN_HEALTH_FACTOR = 1e18; // aka 1.0

    enum MintOnChain {
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
        // tokenIdToSupplierAddress[_tokenId] = msg.sender;

        // set mapping to true since they've deposited an nft to mint against
        // hasUserSuppliedAnNft[msg.sender] = true;
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

    function mint(uint256 amount, MintOnChain mintOnChain) public payable {
        // stablecoinContract.mint(msg.sender, amount);
        // has user supplied an nft as collateral
        if (numberOfNftsUserHasSupplied[msg.sender] == 0) {
            revert NoNftsCurrentlySupplied();
        }

        uint256 totalStablecoinValueOfUserCollateral = nftPriceInUsd() / COLLATERALISATION_RATIO;

        uint256 maxStablecoinCanBeMinted =
            totalStablecoinValueOfUserCollateral - userAddressToNumberOfStablecoinsMinted[msg.sender];

        // if the amount requested was < max value then mint the OFT to the user (on their requested chain?)
        if (amount <= maxStablecoinCanBeMinted) {
            if (mintOnChain == MintOnChain.Base) {
                // if they've requested to mint on Sepolia just mint on the OFT contract
                // stablecoinContract.mint(msg.sender, amount);
            }
            else if (mintOnChain == MintOnChain.Optimism) {
                // if they've requested to mint on Mumbai we must construct a lz message and call _lzSend() with it
                // _mintOnDestinationChain(amount);
            }
            else revert ChainNotSpecified();
        } else {
            revert mintFailed();
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

        // trigger function based on selection (crosschain split logic test)
        if (selection == 0) {
            mintStablecoins(recipient, numberOfCoins);
        } else if (selection == 1) {
            burnStablecoins(recipient, numberOfCoins);
        } else if (selection == 2) {
            callStableEngineContractAndMint(recipient, numberOfCoins);
        }
    }

    function mintStablecoins(address _recipient, uint256 _numberOfCoins) internal {
        stablecoinsMinted[_recipient] += _numberOfCoins;
    }

    function burnStablecoins(address _recipient, uint256 _numberOfCoins) internal {
        stablecoinsMinted[_recipient] -= _numberOfCoins;
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
