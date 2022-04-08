// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IStake {
    // Info of each user in pool
    struct UserInfo {
        uint256 endTime; // timestamp when tokens can be released
        uint256 totalAmount; // total reward to be withdrawn
    }

    // Info about staking pool
    struct PoolInfo {
        uint256 minStake; // minimum stake per user
        uint256 maxStake; // maximum stake per user
        uint256 startTime; // start of stake start window
        uint256 endTime; // end of stake start windows
        uint256 rewardPermill; // permill of reward (1permill of 1000 = 1, 20 will be 2%)
        uint256 lockPeriod; // required stake length
        uint256 maxTotalStaked; // maximum total tokens stoked on this
        uint256 totalStaked; // total tokens already staked
        bytes32 poolHash; // unique pool id needed to keep track of user deposits
    }

    function getPools() external view returns (PoolInfo[] memory);

    function getPoolCount() external view returns (uint256);

    function poolInfo(uint256 poolId) external view returns (PoolInfo memory);

    function addStakePool(
        uint256 minStake,
        uint256 maxStake,
        uint256 startTime,
        uint256 endTime,
        uint256 rewardPermill,
        uint256 lockPeriod,
        uint256 maxTotalStaked
    ) external;

    /// Claim all possible tokens
    function claim() external;

    /// Claim tokens only from given user stake
    function claimStake(uint256 index) external;

    /// Address of Vesting contract for claim2stake
    function vestingAddress() external view returns (address);

    /// Address of ERC20 token used for staking
    function tokenAddress() external view returns (address);

    /**
        Total user staked tokens and rewards
     */
    function totalStakedTokens() external view returns (uint256);

    /**
        Free reward tokens available for staking
     */
    function rewardsAvailable() external view returns (uint256);

    /**
        Stake tokens directly from Vesting contract.
        Can be call only from Vesting contract.
        Can fail, if stake requirements are not met.
        @param user address of user that is calling claim2stake in Vesting
        @param poolIndex chosen pool index to stake
        @param amount of tokens claimed to stake
     */
    function claim2stake(
        address user,
        uint256 poolIndex,
        uint256 amount
    ) external returns (bool);

    /**
        Deposit tokens to given pool.
        @param poolId index of staking pool to deposit
        @param amount of tokens to be staked
     */
    function deposit(uint256 poolId, uint256 amount) external;

    /// Event emited on successful deposit.
    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        uint256 timeout
    );

    /// Event emited on successful claim
    event Withdraw(address indexed user, uint256 amount);
}
