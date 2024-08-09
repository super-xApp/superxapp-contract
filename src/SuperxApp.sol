// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {IWrappedNative} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IWrappedNative.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/utils/structs/EnumerableMap.sol";
import {SuperxOracle} from "./SuperxOracle.sol";

/// @title SuperxApp Contract
/// @author Favour Aniogor (@SuperDevFavour).
/// @notice This contract implements cross contract interactions regarding transfering, swapping and Staking Tokens.
/// @dev This contracts implements chainlink CCIP
contract SuperxApp is OwnerIsCreator, CCIPReceiver, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.Bytes32ToUintMap;

    ////////////
    // ENUMS //
    //////////

    //custom type to know what the user has decided to pay fees in
    enum PayFeesIn {
        Native,
        LINK
    }

    // For ERROR CODE
    enum ErrorCode {
        RESOLVED,
        FAILED
    }

    // To Know the type of token the user is sending
    enum TokenType {
        SUPPORTED,
        NOTSUPPORTED,
        WRAPPED,
        NATIVE
    }

    /////////////
    // ERRORS //
    ///////////

    // Custom errors to provide more descriptive revert messages.
    error NotEnoughBalanceForFees(
        uint256 currentBalance,
        uint256 calculatedFees
    ); // Used to make sure contract has enough balance to cover the fees.
    error NothingToWithdraw(); // Used when trying to withdraw Ether but there's nothing to withdraw.
    error FailedToWithdrawEth(address owner, address target, uint256 value); // Used when the withdrawal of Ether fails.
    error DestinationChainNotAllowed(uint64 destinationChainSelector); // Used when the destination chain has not been allowlisted by the contract owner.
    error SourceChainNotAllowed(uint64 sourceChainSelector); // Used when the source chain has not been allowlisted by the contract owner.
    error SenderNotAllowed(address sender); // Used when the sender has not been allowlisted by the contract owner.
    error InvalidReceiverAddress(); // Used when the receiver address is 0.
    error OnlySelf(); // Used when a function is called outside of the contract itself.

    //////////////////////
    // State Variables //
    ////////////////////

    // Interface for the LINK token contract
    IERC20 public immutable i_linkToken;

    /// @notice The wrapped native token address.
    /// @dev If the wrapped native token address changes on the router, this contract will need to be redeployed.
    IWrappedNative public immutable i_weth;

    /// Oracle contract address
    address payable public immutable i_oracle;

    // storing the current chain ChainSelector
    uint64 private immutable i_currentChainSelector;

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 => bool) public allowlistedDestinationChains;

    // Mapping to keep track of allowlisted source chains.
    mapping(uint64 => bool) public allowlistedSourceChains;

    // Mapping to keep track of allowlisted senders.
    mapping(address => bool) public allowlistedSenders;

    // Mapping to keep track of all supportedChains
    mapping(uint64 => bool) public supportedChain;

    // Mapping asset symbols to address
    mapping(string => address) public assetAddress;

    // The message contents of failed messages are stored here.
    mapping(bytes32 messageId => Client.Any2EVMMessage contents)
        public s_messageContents;

    // Contains failed messages and their state.
    EnumerableMap.Bytes32ToUintMap internal s_failedMessages;

    /////////////
    // Events //
    ///////////

    // Event emitted when a message is sent to another chain.
    event TokenSent(
        bytes32 indexed _messageId, // The unique ID of the CCIP message.
        uint64 indexed _destinationChainSelector, // The chain selector of the destination chain.
        address indexed _sender, // The address of the sender.
        address _to, // The address of the receiver.
        address _token, // The token address that was transferred.
        uint256 _tokenAmount, // The token amount that was transferred.
        address _feeToken, // the token address used to pay CCIP fees.
        uint256 _fees // The fees paid for sending the message.
    );

    // Event emitted when a message is received from another chain.
    event TokenReceived(
        bytes32 indexed _messageId, // The unique ID of the CCIP message.
        uint64 indexed _sourceChainSelector, // The chain selector of the source chain.
        address _sender, // The address of the sender from the source chain.
        address indexed _to, // The address of the reciever.
        address token, // The token address that was transferred.
        uint256 tokenAmount // The token amount that was transferred.
    );

    // Event emitted when token transfer failed
    event TokenTransferFailed(bytes32 indexed messageId, bytes reason);

    //////////////////
    // Constructor //
    ////////////////

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    /// @param _link The address of the link contract.
    constructor(
        address _router,
        address _link,
        uint64 _chainSelector,
        uint64[] memory _supportedChain,
        address _oracle
    ) CCIPReceiver(_router) {
        if (_router == address(0)) revert InvalidRouter(_router);
        i_linkToken = IERC20(_link);
        i_currentChainSelector = _chainSelector;
        i_weth = IWrappedNative(CCIPRouter(_router).getWrappedNative());
        i_weth.approve(_router, type(uint256).max);
        i_oracle = payable(_oracle);
        i_weth.approve(_oracle, type(uint256).max);

        for (uint8 i; i < _supportedChain.length; i++) {
            supportedChain[_supportedChain[i]] = true;
        }
    }

    ////////////////
    // Modifiers //
    //////////////

    /// @dev Modifier that checks if the chain with the given sourceChainSelector is allowlisted and if the sender is allowlisted.
    /// @param _sourceChainSelector The selector of the destination chain.
    /// @param _sender The address of the sender.
    modifier onlyAllowlisted(uint64 _sourceChainSelector, address _sender) {
        if (!allowlistedSourceChains[_sourceChainSelector])
            revert SourceChainNotAllowed(_sourceChainSelector);
        if (!allowlistedSenders[_sender]) revert SenderNotAllowed(_sender);
        _;
    }

    /// @dev Modifier that checks if the chain with the given destinationChainSelector is allowlisted.
    /// @param _destinationChainSelector The selector of the destination chain.
    modifier onlyAllowlistedDestinationChain(uint64 _destinationChainSelector) {
        if (!allowlistedDestinationChains[_destinationChainSelector])
            revert DestinationChainNotAllowed(_destinationChainSelector);
        _;
    }

    /// @dev Modifier that checks the receiver address is not 0.
    /// @param _receiver The receiver address.
    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }

    /// @dev Modifier to allow only the contract itself to execute a function.
    /// Throws an exception if called by any account other than the contract itself.
    modifier onlySelf() {
        if (msg.sender != address(this)) revert OnlySelf();
        _;
    }

    ////////////////
    // Externals //
    //////////////

    /// @dev Updates the allowlist status of a destination chain for transactions.
    /// @notice This function can only be called by the owner.
    /// @param _destinationChainSelector The selector of the destination chain to be updated.
    /// @param _allowed The allowlist status to be set for the destination chain.
    function allowlistDestinationChain(
        uint64 _destinationChainSelector,
        bool _allowed
    ) external onlyOwner {
        allowlistedDestinationChains[_destinationChainSelector] = _allowed;
    }

    /// @dev Updates the allowlist status of a source chain
    /// @notice This function can only be called by the owner.
    /// @param _sourceChainSelector The selector of the source chain to be updated.
    /// @param _allowed The allowlist status to be set for the source chain.
    function allowlistSourceChain(
        uint64 _sourceChainSelector,
        bool _allowed
    ) external onlyOwner {
        allowlistedSourceChains[_sourceChainSelector] = _allowed;
    }

    /// @dev Updates the allowlist status of a sender for transactions.
    /// @notice This function can only be called by the owner.
    /// @param _sender The address of the sender to be updated.
    /// @param _allowed The allowlist status to be set for the sender.
    function allowlistSender(
        address _sender,
        bool _allowed
    ) external onlyOwner {
        allowlistedSenders[_sender] = _allowed;
    }

    /// @notice Transfer tokens to receiver on the destination chain.
    /// @notice Pay for fees in LINK/ETH.
    /// @param _destinationChainSelector The identifier (aka selector) for the destination blockchain.
    /// @param _receiver The address of the recipient on the destination blockchain.
    /// @param _to The address to be paid on the recipient chain.
    /// @param _token token address.
    /// @param _amount token amount.
    /// @return messageId The ID of the CCIP message that was sent.
    function sendToken(
        uint64 _destinationChainSelector,
        address _receiver,
        address _to,
        address _token,
        uint256 _amount,
        TokenType _tokenType,
        PayFeesIn _payFeesIn,
        string calldata _descSymbol,
        bytes[] calldata _pythUpdateData
    )
        external
        payable
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        if (_tokenType == TokenType.NATIVE) {
            i_weth.deposit{value: _amount}();
        }

        if (_tokenType == TokenType.NOTSUPPORTED) {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
            (bool success, uint256 swapAmount) = SuperxOracle(i_oracle).swap(
                _token,
                address(i_linkToken),
                _amount,
                _pythUpdateData
            );
            _token = address(i_linkToken);
            _amount = swapAmount;
        }

        if (_tokenType == TokenType.SUPPORTED) {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        }

        Client.EVM2AnyMessage memory message = _buildCCIPMessage(
            _receiver,
            msg.sender,
            _to,
            _token,
            _amount,
            _tokenType,
            _descSymbol,
            _pythUpdateData,
            _payFeesIn == PayFeesIn.LINK ? address(i_linkToken) : address(0)
        );

        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fees = router.getFee(_destinationChainSelector, message);

        IERC20(_token).approve(address(router), _amount);

        if (_payFeesIn == PayFeesIn.LINK) {
            if (fees > i_linkToken.balanceOf(address(this)))
                revert NotEnoughBalanceForFees(
                    i_linkToken.balanceOf(address(this)),
                    fees
                );

            i_linkToken.approve(address(router), fees);

            i_linkToken.safeTransferFrom(msg.sender, address(this), _amount);

            messageId = router.ccipSend(_destinationChainSelector, message);
        } else {
            if (fees > address(this).balance)
                revert NotEnoughBalanceForFees(address(this).balance, fees);

            messageId = router.ccipSend{value: fees}(
                _destinationChainSelector,
                message
            );
        }

        emit TokenSent(
            messageId,
            _destinationChainSelector,
            msg.sender,
            _to,
            _token,
            _amount,
            _payFeesIn == PayFeesIn.LINK ? address(i_linkToken) : address(0),
            fees
        );
    }

    /// @notice The entrypoint for the CCIP router to call. This function should
    /// never revert, all errors should be handled internally in this contract.
    /// @param _message The message to process.
    /// @dev Extremely important to ensure only router calls this.
    function ccipReceive(
        Client.Any2EVMMessage calldata _message
    )
        external
        override
        onlyRouter
        onlyAllowlisted(
            _message.sourceChainSelector,
            abi.decode(_message.sender, (address))
        ) // Make sure the source chain and sender are allowlisted
    {
        /* solhint-disable no-empty-blocks */
        try this.processMessage(_message) {
            // Intentionally empty in this example; no action needed if processMessage succeeds
        } catch (bytes memory err) {
            // Could set different error codes based on the caught error. Each could be
            // handled differently.
            s_failedMessages.set(_message.messageId, uint256(ErrorCode.FAILED));
            s_messageContents[_message.messageId] = _message;
            // Don't revert so CCIP doesn't revert. Emit event instead.
            // The message can be retried later without having to do manual execution of CCIP.
            emit TokenTransferFailed(_message.messageId, err);
            return;
        }
    }

    /// @notice Serves as the entry point for this contract to process incoming messages.
    /// @param _message Received CCIP message.
    /// @dev Transfers specified token amounts to the owner of this contract. This function
    /// must be external because of the  try/catch for error handling.
    /// It uses the `onlySelf`: can only be called from the contract.
    function processMessage(
        Client.Any2EVMMessage calldata _message
    )
        external
        onlySelf
        onlyAllowlisted(
            _message.sourceChainSelector,
            abi.decode(_message.sender, (address))
        ) // Make sure the source chain and sender are allowlisted
    {
        _ccipReceive(_message); // process the message
    }

    /// @notice for setting the token address
    /// @param _tokenSymbol the symbol of the token
    /// @param _tokenAddress the Address of the token
    function setAssetToken(
        string calldata _tokenSymbol,
        address _tokenAddress
    ) external onlyOwner {
        assetAddress[_tokenSymbol] = _tokenAddress;
    }

    receive() external payable {}

    ////////////////
    // Internals //
    //////////////

    /// @notice handle a received message
    /// @dev inherited from the CCIPReceiver
    /// @param _message the message recieved
    /// @inheritdoc	CCIPReceiver
    function _ccipReceive(
        Client.Any2EVMMessage memory _message
    )
        internal
        override
        onlyAllowlisted(
            _message.sourceChainSelector,
            abi.decode(_message.sender, (address))
        )
    {
        bytes32 messageId = _message.messageId;
        uint64 sourceChainSelector = _message.sourceChainSelector;
        (
            address to,
            address from,
            TokenType tokenType,
            string memory descSymbol,
            bytes[] memory pythUpdateData
        ) = abi.decode(
                _message.data,
                (address, address, TokenType, string, bytes[])
            );
        address token = _message.destTokenAmounts[0].token;
        uint256 tokenAmount = _message.destTokenAmounts[0].amount;

        address destAddress = assetAddress[descSymbol];

        if (
            (TokenType.NATIVE == tokenType || TokenType.WRAPPED == tokenType) &&
            destAddress == address(1)
        ) {
            i_weth.withdraw(tokenAmount);
            (bool success, ) = payable(to).call{value: tokenAmount}("");
            if (!success) {
                i_weth.deposit{value: tokenAmount}();
                i_weth.transfer(to, tokenAmount);
            }
        }

        if (
            (TokenType.SUPPORTED == tokenType ||
                TokenType.NOTSUPPORTED == tokenType) &&
            destAddress == address(1)
        ) {
            (bool success, uint256 swapAmount) = SuperxOracle(i_oracle).swap(
                token,
                destAddress,
                tokenAmount,
                pythUpdateData
            );
            (bool _success, ) = payable(to).call{value: tokenAmount}("");
            if (!_success) {
                i_weth.deposit{value: tokenAmount}();
                i_weth.transfer(to, tokenAmount);
            }
        }

        if (
            (TokenType.SUPPORTED == tokenType ||
                TokenType.NOTSUPPORTED == tokenType) && destAddress != token
        ) {
            (bool success, uint256 swapAmount) = SuperxOracle(i_oracle).swap(
                token,
                destAddress,
                tokenAmount,
                pythUpdateData
            );
            IERC20(destAddress).transfer(to, tokenAmount);
        } else {
            IERC20(token).transfer(to, tokenAmount);
        }

        emit TokenReceived(
            messageId,
            sourceChainSelector,
            from,
            to,
            token,
            tokenAmount
        );
    }

    ///////////////
    // Privates //
    /////////////

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for programmable tokens transfer.
    /// @param _receiver The address of the receiver.
    /// @param _from The address to be paid on the recipient chain.
    /// @param _to The address to be paid on the recipient chain.
    /// @param _token The token to be transferred.
    /// @param _amount The amount of the token to be transferred.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(
        address _receiver,
        address _from,
        address _to,
        address _token,
        uint256 _amount,
        TokenType _tokenType,
        string calldata _descSymbol,
        bytes[] calldata _pythUpdateData,
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(_token),
            amount: _amount
        });

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver),
                data: abi.encode(
                    _to,
                    _from,
                    _tokenType,
                    _descSymbol,
                    _pythUpdateData
                ),
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: 300_000})
                ),
                feeToken: _feeTokenAddress
            });
    }
}

interface CCIPRouter {
    function getWrappedNative() external view returns (address);
}
