// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SuperxApp Contract
/// @author Favour Aniogor (@SuperDevFavour).
/// @notice This contract implements cross contract interactions regarding transfering, swapping and Staking Tokens.
/// @dev This contracts implements chainlink CCIP
contract SuperxApp is OwnerIsCreator, CCIPReceiver, ReentrancyGuard {
    using SafeERC20 for IERC20;

    ////////////
    // ENUMS //
    //////////

    //custom type to know what the user has decided to pay fees in
    enum PayFeesIn {
        Native,
        LINK
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

    //////////////////////
    // State Variables //
    ////////////////////

    // Interface for the LINK token contract
    IERC20 internal immutable i_linkToken;

    // storing the current chain ChainSelector
    uint64 private immutable i_currentChainSelector;

    // Mapping to keep track of allowlisted destination chains.
    mapping(uint64 => bool) public allowlistedDestinationChains;

    // Mapping to keep track of allowlisted source chains.
    mapping(uint64 => bool) public allowlistedSourceChains;

    // Mapping to keep track of allowlisted senders.
    mapping(address => bool) public allowlistedSenders;

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

    //////////////////
    // Constructor //
    ////////////////

    /// @notice Constructor initializes the contract with the router address.
    /// @param _router The address of the router contract.
    /// @param _link The address of the link contract.
    constructor(
        address _router,
        address _link,
        uint64 _chainSelector
    ) CCIPReceiver(_router) {
        if (_router == address(0)) revert InvalidRouter(_router);
        i_linkToken = IERC20(_link);
        i_currentChainSelector = _chainSelector;
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
        PayFeesIn _payFeesIn
    )
        external
        onlyAllowlistedDestinationChain(_destinationChainSelector)
        validateReceiver(_receiver)
        returns (bytes32 messageId)
    {
        Client.EVM2AnyMessage memory message = _buildCCIPMessage(
            _receiver,
            msg.sender,
            _to,
            _token,
            _amount,
            _payFeesIn == PayFeesIn.LINK ? address(i_linkToken) : address(0)
        );

        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fees = router.getFee(_destinationChainSelector, message);

        if (_payFeesIn == PayFeesIn.LINK) {
            if (fees > i_linkToken.balanceOf(address(this)))
                revert NotEnoughBalanceForFees(
                    i_linkToken.balanceOf(address(this)),
                    fees
                );

            i_linkToken.approve(address(router), fees);

            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
            IERC20(_token).approve(address(router), _amount);

            messageId = router.ccipSend(_destinationChainSelector, message);
        } else {
            if (fees > address(this).balance)
                revert NotEnoughBalanceForFees(address(this).balance, fees);

            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
            IERC20(_token).approve(address(router), _amount);

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

    ////////////////
    // Internals //
    //////////////

    /// @notice handle a received message
    /// @dev inherited from the CCIPReceiver
    /// @param _message the message recieved
    /// @inheritdoc	CCIPReceiver.sol
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
        (address to, address from) = abi.decode(
            _message.data,
            (address, address)
        );
        address token = _message.destTokenAmounts[0].token;
        uint256 tokenAmount = _message.destTokenAmounts[0].amount;

        IERC20(token).transfer(to, tokenAmount);

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
        address _feeTokenAddress
    ) private pure returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: _token,
            amount: _amount
        });

        return
            Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver),
                data: abi.encode(_to, _from),
                tokenAmounts: tokenAmounts,
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({gasLimit: 200_000})
                ),
                feeToken: _feeTokenAddress
            });
    }
}
