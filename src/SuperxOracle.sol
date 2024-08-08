// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/utils/structs/EnumerableMap.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";

/// @title SuperxOracle Contract
/// @author Favour Aniogor (@SuperDevFavour).
/// @notice This contract acts as a simple AMM that holds the pool for Tokens available in the SuperxApp
/// @dev This contracts implements Pyth PriceFeeds
contract SuperxOracle {
    /////////////
    // ERRORs //
    ///////////
    error PriceFeedAndTokensLengthNotEqual();

    //////////////////////
    // State Variables //
    ////////////////////

    // The Pyth Contract
    IPyth immutable i_pyth;

    // maps token address that can be swappable to a boolean value
    mapping(address => bool) public s_isSwappable;

    // stores the pricefeed for all token pairs e.g eth/usd
    mapping(address => bytes32) public s_priceFeeds;

    // stores the address of all tokens
    address[] public s_tokens;

    //////////////////
    // Constructor //
    ////////////////

    /// @notice Constructor initializes the contract with the pyth address.
    /// @param _pyth The address of the pyth contract.
    /// @param _pricefeed an array of pricefeeds for the token.
    /// @param _tokens an array of acceptable swappable tokens.
    constructor(
        address _pyth,
        bytes32[] memory _pricefeed,
        address[] memory _tokens
    ) {
        i_pyth = IPyth(_pyth);

        if (_pricefeed.length != _tokens.length) {
            revert PriceFeedAndTokensLengthNotEqual();
        }
        for (uint i = 0; i < _pricefeed.length; i++) {
            if (_tokens[i] != address(0)) {
                s_isSwappable[_tokens[i]] = true;
                s_tokens.push(_tokens[i]);
                s_priceFeeds[_tokens[i]] = _pricefeed[i];
            }
        }
    }
}
