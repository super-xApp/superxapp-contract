// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import "@pythnetwork/pyth-sdk-solidity/PythUtils.sol";

/// @title SuperxOracle Contract
/// @author Favour Aniogor (@SuperDevFavour).
/// @notice This contract acts as a simple AMM that holds the pool for Tokens available in the SuperxApp
/// @dev This contracts implements Pyth PriceFeeds
contract SuperxOracle {
    /////////////
    // ERRORs //
    ///////////
    error PriceFeedAndTokensLengthNotEqual();
    error TokenNotSwappable(address _baseToken, address _quoteToken);
    error AmountOutOfBounds();
    error NotEnoughBalance(uint256 _value);

    ////////////
    // ENUMs //
    //////////

    enum TokenType {
        others,
        native
    }

    //////////////////////
    // State Variables //
    ////////////////////

    // The Pyth Contract
    IPyth immutable i_pyth;

    // This amount of percent that can be swapped from the contract balance at a time.
    // NOTE: This is just for the testnet and not going to be part of the mainnet code.
    uint8 private s_quotePercent = 20;

    // maps token address that can be swappable to a boolean value
    mapping(address => bool) public s_isSwappable;

    // stores the pricefeed for all token pairs e.g eth/usd
    mapping(address => TokenData) public s_tokenDatas;

    // stores the address of all tokens
    address[] public s_tokens;

    /////////////
    // EVENTs //
    ///////////

    // Event Emitted when a token is successfully swapped
    event TokenSwapped(
        string indexed _from,
        string indexed _to,
        uint256 _amount
    );

    //////////////
    // STRUCTs //
    ////////////

    struct TokenData {
        bytes32 priceFeed;
        string symbol;
    }

    //////////////////
    // Constructor //
    ////////////////

    /// @notice Constructor initializes the contract with the pyth address.
    /// @param _pyth The address of the pyth contract.
    /// @param _tokenDatas an array of TokenData struct which contains the pricefeed and symbol.
    /// @param _tokens an array of acceptable swappable tokens.
    constructor(
        address _pyth,
        TokenData[] memory _tokenDatas,
        address[] memory _tokens
    ) {
        i_pyth = IPyth(_pyth);

        if (_tokenDatas.length != _tokens.length) {
            revert PriceFeedAndTokensLengthNotEqual();
        }
        for (uint i = 0; i < _tokenDatas.length; i++) {
            if (_tokens[i] != address(0)) {
                s_isSwappable[_tokens[i]] = true;
                s_tokens.push(_tokens[i]);
                s_tokenDatas[_tokens[i]] = _tokenDatas[i];
            }
        }
    }

    ////////////////
    // Modifiers //
    //////////////
    modifier onlySwappableToken(address _baseToken, address _quoteToken) {
        if (!s_isSwappable[_baseToken] || !s_isSwappable[_quoteToken]) {
            revert TokenNotSwappable(_baseToken, _quoteToken);
        }
        _;
    }

    ////////////////
    // Externals //
    //////////////

    /// @notice swap carries out the swapping functionality using pyth pricefeed
    /// @param _baseToken the address of the token you to swap from.
    /// @param _quoteToken the address of the token you to swap to.
    /// @param _amount the amount you want to swap.
    /// @param _outputType the type of token you are swapping to.
    /// @param _pythUpdateData the data gotten from the frontend to update the pricefeed.
    function swap(
        address _baseToken,
        address _quoteToken,
        uint256 _amount,
        TokenType _outputType,
        bytes[] calldata _pythUpdateData
    ) external payable onlySwappableToken(_baseToken, _quoteToken) {
        if (_baseToken == address(0) && _amount > msg.value) {
            revert NotEnoughBalance(msg.value);
        }

        uint256 updateFee = i_pyth.getUpdateFee(_pythUpdateData);
        i_pyth.updatePriceFeeds{value: updateFee}(_pythUpdateData);

        PythStructs.Price memory currentBasePrice = i_pyth.getPrice(
            s_tokenDatas[_baseToken].priceFeed
        );
        PythStructs.Price memory currentQuotePrice = i_pyth.getPrice(
            s_tokenDatas[_quoteToken].priceFeed
        );

        uint256 basePrice = PythUtils.convertToUint(
            currentBasePrice.price,
            currentBasePrice.expo,
            18
        );
        uint256 quotePrice = PythUtils.convertToUint(
            currentQuotePrice.price,
            currentQuotePrice.expo,
            18
        );

        // This computation loses precision. The infinite-precision result is between [quoteSize, quoteSize + 1]
        uint256 quoteSize = (_amount * basePrice) / quotePrice;

        if (!_notLargerThanPercent(_quoteToken, quoteSize))
            revert AmountOutOfBounds();

        if (_baseToken != address(0))
            IERC20(_baseToken).transferFrom(msg.sender, address(this), _amount);

        bool success;

        if (_outputType != TokenType.native && _quoteToken != address(0)) {
            success = IERC20(_quoteToken).transfer(msg.sender, quoteSize);
        } else {
            (success, ) = payable(msg.sender).call{value: quoteSize}("");
        }

        TokenData memory _from = s_tokenDatas[_baseToken];
        TokenData memory _to = s_tokenDatas[_quoteToken];

        if (success) {
            emit TokenSwapped(_from.symbol, _to.symbol, _amount);
        }
    }

    receive() external payable {}

    ////////////////
    // Internals //
    //////////////

    /// @notice This function checks if the amount of token to be swapped is <= the s_qoutePercent * the contract balance
    /// @param _token the address of the token the contract is sending.
    /// @param _amount the quantity of the token the user will get.
    function _notLargerThanPercent(
        address _token,
        uint256 _amount
    ) internal view returns (bool) {
        uint256 percentAmount = s_quotePercent *
            (IERC20(_token).balanceOf(address(this)) / 100);
        if (_amount > percentAmount) {
            return false;
        }
        return true;
    }
}
