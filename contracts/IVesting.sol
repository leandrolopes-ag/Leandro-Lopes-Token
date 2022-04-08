// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IVesting {
    struct Vest {
        uint256 startDate;
        uint256 endDate;
        uint256 startTokens;
        uint256 totalTokens;
        uint256 claimed;
    }

    /**
        Get all coins that can be claimed from contract
        @param user address of user to check
        @return sum number of tokens to be claimed
     */
    function claimable(address user) external view returns (uint256 sum);

    /// Event emited on claim
    event Claimed(address indexed user, uint256 amount);

    /**
        Claim tokens by msg.sender
        Emits Claimed event
     */
    function claim() external;

    /// Event emited on creating new vest
    event VestAdded(
        address indexed user,
        uint256 startDate,
        uint256 endDate,
        uint256 startTokens,
        uint256 totalTokens
    );

    /**
        Create vesting for user
        Function restricted
        Emits VestAdded event
        @param user address of user
        @param startDate strat timestamp of vesting (can not be in past)
        @param endDate end timestamp of vesting (must be higher than startDate)
        @param startTokens number of tokens to be released on start date (can be zero)
        @param totalTokens total number of tokens to be released on end date (must be greater than startTokens)
     */
    function createVest(
        address user,
        uint256 startDate,
        uint256 endDate,
        uint256 startTokens,
        uint256 totalTokens
    ) external;

    /// Mass create vestings
    function massCreateVest(
        address[] calldata user,
        uint256[] calldata startDate,
        uint256[] calldata endDate,
        uint256[] calldata startTokens,
        uint256[] calldata totalTokens
    ) external;

    /**
        Get all vestings for given user.
        Will return empty array if no vests configured.
        @param user address to list
        @return array of vests
     */
    function getVestings(address user) external view returns (Vest[] memory);

    /**
        Get one vesting for given user
        Will throw if user have no vestings configured
        @param user address to check
        @param index number of vesting to show
        @return single vest struct
     */
    function getVesting(address user, uint256 index)
        external
        view
        returns (Vest memory);
}
