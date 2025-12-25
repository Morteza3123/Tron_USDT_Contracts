// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract Tracker {
    struct Deposit {
        address user;
        address token;
        uint256 amount;
        uint256 timestamp;
        bool executed;
    }
    
    struct DepositInfo {
        address user;
        uint256 amount;
        uint256 nonce;
    }

    uint256 public nonce;

    mapping(uint256 => Deposit) public deposits;
    mapping(address => uint256[]) private _userNonces;

    event Deposited(
        uint256 indexed nonce,
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event Executed(
        uint256 indexed nonce,
        address indexed executor,
        address rewardToken,
        uint256 rewardAmount
    );

    /* ========== DEPOSIT ========== */

    function deposit(address token, uint256 amount) external {
        require(token != address(0), "Zero token");
        require(amount > 0, "Zero amount");

        uint256 currentNonce = ++nonce;

        bool success = IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        require(success, "Transfer failed");

        deposits[currentNonce] = Deposit({
            user: msg.sender,
            token: token,
            amount: amount,
            timestamp: block.timestamp,
            executed: false
        });

        _userNonces[msg.sender].push(currentNonce);

        emit Deposited(currentNonce, msg.sender, token, amount);
    }

    /* ========== EXECUTION ========== */

    /**
     * @notice Execute a deposit by paying 30% of the deposit amount
     *         in another ERC20 token to the depositor
     * @param depositNonce Global deposit nonce
     * @param rewardToken ERC20 token used for payment
     */
    function executeDeposit(uint256 depositNonce, address rewardToken) external {
        Deposit storage d = deposits[depositNonce];

        require(d.user != address(0), "Invalid nonce");
        require(!d.executed, "Already executed");
        require(rewardToken != address(0), "Zero reward token");

        uint256 rewardAmount = (d.amount * 30) / 100;

        // Mark executed BEFORE external call (important)
        d.executed = true;

        // Executor pays reward token to depositor
        bool success = IERC20(rewardToken).transferFrom(
            msg.sender,
            d.user,
            rewardAmount
        );
        require(success, "Reward transfer failed");

        emit Executed(
            depositNonce,
            msg.sender,
            rewardToken,
            rewardAmount
        );
    }

    /* ========== VIEW HELPERS ========== */

    function getUserNonces(address user)
        external
        view
        returns (uint256[] memory)
    {
        return _userNonces[user];
    }
    
    
    function getAllDeposits()
    external
    view
    returns (Deposit[] memory)
{
    uint256 total = nonce;
    Deposit[] memory result = new Deposit[](total);

    for (uint256 i = 1; i <= total; i++) {
        result[i - 1] = deposits[i];
    }

    return result;
}



function getPendingDeposits()
    external
    view
    returns (DepositInfo[] memory)
{
    uint256 total = nonce;
    uint256 count;

    // First pass: count pending
    for (uint256 i = 1; i <= total; i++) {
        if (!deposits[i].executed) {
            count++;
        }
    }

    DepositInfo[] memory result = new DepositInfo[](count);
    uint256 index;

    // Second pass: populate
    for (uint256 i = 1; i <= total; i++) {
        if (!deposits[i].executed) {
            Deposit storage d = deposits[i];

            result[index] = DepositInfo({
                user: d.user,
                amount: d.amount,
                nonce: i
            });

            index++;
        }
    }

    return result;
}



    
    
}
