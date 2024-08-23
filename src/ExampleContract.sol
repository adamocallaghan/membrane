// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OApp, Origin, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

contract ExampleContract is OApp {
    string public data;
    // uint256 public numberToMint;
    // address public recipient;
    // uint256 public selection;

    mapping(address => uint256) public stablecoinsMinted;

    constructor(address _endpoint) OApp(_endpoint, msg.sender) {}

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
        }
    }

    function mintStablecoins(address _recipient, uint256 _numberOfCoins) internal {
        stablecoinsMinted[_recipient] += _numberOfCoins;
    }

    function burnStablecoins(address _recipient, uint256 _numberOfCoins) internal {
        stablecoinsMinted[_recipient] -= _numberOfCoins;
    }
}
