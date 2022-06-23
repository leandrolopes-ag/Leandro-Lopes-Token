// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "./IStake.sol";
import "./IERC20.sol";
import "./Ownable.sol";

contract Stake is IStake, Ownable {
    //
    // Storage
    //

    // Info of each pool.
    PoolInfo[] private _poolInfo;
    // [pool hash][user] = tokens in pool
    mapping(bytes32 => mapping(address => uint256)) private _userStake;

    // Info of each user that stakes.
    // [user]=UserInfo[]
    mapping(address => UserInfo[]) private _userInfo;

    address private immutable _tokenAddress;
    address private immutable _vestingAddress;

    uint256 private _stakedAndRewards;
    uint256 private _totalFreeRewards;

    string internal constant ERR_NOTHING = "Nothing to do";
    string internal constant ERR_NS4U = "No stakes for user";

    /**
        Contract constructor
        @param token address of ERC20 token used
        @param vesting address of Vesting contract
     */
    constructor(address token, address vesting) {
        require(
            token != ZERO_ADDRESS && vesting != ZERO_ADDRESS,
            "Need both addresses"
        );
        _tokenAddress = token;
        _vestingAddress = vesting;
    }

    //
    // Readers
    //

    /// Address of ERC20 token used for staking
    function tokenAddress() external view returns (address) {
        return _tokenAddress;
    }

    /// Address of Vesting contract that can call claim2stake
    function vestingAddress() external view returns (address) {
        return _vestingAddress;
    }

    /**
        Return the length of pool array.
    */
    function getPoolCount() external view returns (uint256) {
        return _poolInfo.length;
    }

    /**
        Return single PoolInfo on given index
        @param poolId index of staking pool
        @return PoolInfo struct
     */
    function poolInfo(uint256 poolId) external view returns (PoolInfo memory) {
        return _poolInfo[poolId];
    }

    /**
        All available staking pools
        @return PoolInfo[] struct
     */
    function getPools() external view returns (PoolInfo[] memory) {
        return _poolInfo;
    }

    /// Total number of tokens staked by users
    function totalStakedTokens() external view returns (uint256) {
        return _stakedAndRewards;
    }

    /// Current number of tokens available as staking rewards
    function rewardsAvailable() external view returns (uint256) {
        return _totalFreeRewards;
    }

    /**
        Get array of all user stakes
        @param user address to check
        @return UserInfo[] array
     */
    function getUserStakes(address user)
        external
        view
        returns (UserInfo[] memory)
    {
        return _userInfo[user];
    }

    /**
        How many stakes given user created
        @param user adddress to check
        @return number of stakes
     */
    function getUserStakeCount(address user) external view returns (uint256) {
        return _userInfo[user].length;
    }

    /**
        Read UserInfo at given index
        @param user address to check
        @param index of stake for user
        @return UserInfo struct
     */
    function userInfo(address user, uint256 index)
        external
        view
        returns (UserInfo memory)
    {
        return _userInfo[user][index];
    }

    /**
        Return claimable tokens for given user at current time
        @param user address to check
        @return amount of tokens claimable now
     */
    function claimable(address user) external view returns (uint256 amount) {
        uint256 len = _userInfo[user].length;
        if (len > 0) {
            uint256 timeNow = block.timestamp;
            uint256 i;
            for (i; i < len; i++) {
                UserInfo memory u = _userInfo[user][i];
                if (timeNow > u.endTime) {
                    amount += u.totalAmount;
                }
            }
        }
    }

    /**
        Return total balance of user in contract
        @param user address to check
        @return amount of tokens staked + rewards
     */
    function stakedWithRewards(address user)
        external
        view
        returns (uint256 amount)
    {
        uint256 len = _userInfo[user].length;
        if (len > 0) {
            uint256 i;
            for (i; i < len; i++) {
                UserInfo memory u = _userInfo[user][i];
                amount += u.totalAmount;
            }
        }
    }

    //
    // Deposit and claim functions
    //

    /**
        Transfer ERC-20 token from sender's account to staking contract.
        Allowance need to be set first!
        @param poolId chosen staking pool
        @param amount of tokens to stake
    */
    function deposit(uint256 poolId, uint256 amount) external {
        _deposit(msg.sender, poolId, amount);
        // pull tokens
        require(
            IERC20(_tokenAddress).transferFrom(
                address(msg.sender),
                address(this),
                amount
            ),
            "" // this will throw in token if no allowance or balance
        );
    }

    function _deposit(
        address user,
        uint256 poolId,
        uint256 amount
    ) internal {
        require(poolId < _poolInfo.length, "Wrong pool index");

        // prevent infinite loop for users - limit one address to 10 staking positions
        require(_userInfo[user].length < 10, "Too many stakes for user");

        // read storage
        PoolInfo memory pool = _poolInfo[poolId];
        uint256 newTotalAmt = _userStake[pool.poolHash][user] + amount;
        uint256 newTotalStaked = pool.totalStaked + amount;
        uint256 timeNow = block.timestamp;

        // check if selected Pool restrictions are met
        require(newTotalStaked <= pool.maxTotalStaked, "Pool is full");
        require(timeNow < pool.endTime, "Already closed");
        require(timeNow > pool.startTime, "Pool not yet open");
        require(newTotalAmt <= pool.maxStake, "Pool max stake per user");
        require(newTotalAmt >= pool.minStake, "Pool min stake per user");

        UserInfo memory newUI;

        newUI.endTime = timeNow + pool.lockPeriod;
        uint256 reward = (amount * pool.rewardPermill) / 1000;
        uint256 total = amount + reward;
        newUI.totalAmount = total;

        // update storage
        _userInfo[user].push(newUI);
        _poolInfo[poolId].totalStaked = newTotalStaked;
        _userStake[pool.poolHash][user] = newTotalAmt;
        _totalFreeRewards -= reward;
        _stakedAndRewards += total;

        // emit event
        emit Deposit(user, poolId, amount, newUI.endTime);
    }

    /**
        Returns full funded amount of ERC-20 token to requester if lock period is over.
        Looping and clearing all closed stakes for user.
        If it fails out-of-gas use claimStake() to claim one stake
    */
    function claim() external {
        // check if caller is a stakeholder
        uint256 len = _userInfo[msg.sender].length;
        require(len > 0, ERR_NS4U);

        uint256 totalWitdrawal;
        uint256 timeNow = block.timestamp;

        int256 i;
        for (i; i < int256(len); i++) {
            uint256 j = uint256(i);
            UserInfo memory u = _userInfo[msg.sender][j];
            if (timeNow > u.endTime) {
                totalWitdrawal += u.totalAmount;
                len--;
                _userInfo[msg.sender][j] = _userInfo[msg.sender][len];
                i--;
                _userInfo[msg.sender].pop();
            }
        }

        require(totalWitdrawal > 0, ERR_NOTHING);

        _stakedAndRewards -= totalWitdrawal;
        // emit proper event
        emit Withdraw(msg.sender, totalWitdrawal);
        // return funds
        require(
            IERC20(_tokenAddress).transfer(address(msg.sender), totalWitdrawal),
            "" //this will throw in token on error
        );
    }

    /**
        Claim only one stake slot.
        Can be useful in case global claim() fails out-of-gas.
        @param index of user stake to claim
     */
    function claimStake(uint256 index) external {
        // check if caller is a stakeholder
        uint256 len = _userInfo[msg.sender].length;
        require(len > 0, ERR_NS4U);

        uint256 totalWitdrawal;
        uint256 timeNow = block.timestamp;
        UserInfo memory u = _userInfo[msg.sender][index];
        if (timeNow > u.endTime) {
            totalWitdrawal = u.totalAmount;
            _userInfo[msg.sender][index] = _userInfo[msg.sender][len - 1];
            _userInfo[msg.sender].pop();
        }
        require(totalWitdrawal > 0, ERR_NOTHING);

        _stakedAndRewards -= totalWitdrawal;
        // emit proper event
        emit Withdraw(msg.sender, totalWitdrawal);
        // return funds
        require(
            IERC20(_tokenAddress).transfer(address(msg.sender), totalWitdrawal),
            "" //this will throw in token on error
        );
    }

    /**
        Calim2stake function to be used by Vesting contract
        @param user address of user that call claim2stake in vesting
        @param poolIndex index of stake pool to be used
        @param amount amount of tokens to be staked by user in pool
     */
    function claim2stake(
        address user,
        uint256 poolIndex,
        uint256 amount
    ) external returns (bool) {
        require(msg.sender == _vestingAddress, "Only for Vesting contract");
        _deposit(user, poolIndex, amount);
        // pull tokens from Vesting contract
        require(
            IERC20(_tokenAddress).transferFrom(
                address(_vestingAddress),
                address(this),
                amount
            ),
            "" // this will throw in token if no allowance or balance
        );
        return true;
    }

    //
    // Only owner functions
    //

    /**
        Open a new staking pool.
        Function is pulling from caller tokens needed for rewards.
        Allowance need to be set earlier by owner.
        @param minStake minimum tokens stake per user
        @param maxStake maximum stake per user
        @param startTime start of stake start window (unix timestamp)
        @param endTime  end of stake start window (unix timestamp)
        @param rewardPermill permill of reward (1permill of 1000 = 1, 20 will be 2%)
        @param lockPeriod required stake length in seconds
        @param maxTotalStaked maximum total tokens to be staked in this pool
    */
    function addStakePool(
        uint256 minStake,
        uint256 maxStake,
        uint256 startTime,
        uint256 endTime,
        uint256 rewardPermill,
        uint256 lockPeriod,
        uint256 maxTotalStaked
    ) external onlyOwner {
        require(minStake <= maxStake && maxStake > 0, "Min/Max missconfigured");
        require(
            endTime > startTime && startTime > block.timestamp,
            "Timestamps missconfigured"
        );
        require(lockPeriod > 0, "Lock period is zero");
        require(maxTotalStaked >= maxStake, "maxTotalStake too low");
        bytes32 poolHash = keccak256(
            abi.encodePacked(
                minStake,
                maxStake,
                startTime,
                endTime,
                rewardPermill,
                lockPeriod,
                maxTotalStaked
            )
        );
        _poolInfo.push(
            PoolInfo(
                minStake,
                maxStake,
                startTime,
                endTime,
                rewardPermill,
                lockPeriod,
                maxTotalStaked,
                0,
                poolHash
            )
        );

        uint256 totalRewards = (maxTotalStaked * rewardPermill) / 1000;
        _totalFreeRewards += totalRewards;

        // pull tokens for rewards
        require(
            IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                totalRewards
            ),
            "" // this will throw in token if no allowance or balance
        );
    }

    /**
        Reclaim not-reserved reward tokens, clean closed pools
     */
    function reclaimRewards() external onlyOwner {
        uint256 len = _poolInfo.length;
        require(len > 0, ERR_NOTHING);

        uint256 timeNow = block.timestamp;
        uint256 freeTokens;
        int256 i;
        for (i; i < int256(len); i++) {
            uint256 j = uint256(i);
            PoolInfo memory p = _poolInfo[j];
            if (p.endTime < timeNow) {
                freeTokens += (((p.maxTotalStaked - p.totalStaked) *
                    p.rewardPermill) / 1000);
                // clean storage
                len--;
                _poolInfo[j] = _poolInfo[len];
                _poolInfo.pop();
                i--;
            }
        }
        require(freeTokens > 0, ERR_NOTHING);

        _totalFreeRewards -= freeTokens;

        require(
            IERC20(_tokenAddress).transfer(owner, freeTokens),
            "" // will revert in token
        );
    }

    /**
        Recover function, can not touch reserved and user tokens
        @param token address of erc20 token to recover, 0x0 = coin
        @param amount amount of tokens/coins to recover, 0 = all
     */
    function recover(address token, uint256 amount) external onlyOwner {
        if (token == ZERO_ADDRESS) {
            // recover coin
            uint256 balance = address(this).balance;
            require(balance > 0, ERR_NOTHING);
            if (amount > 0 && amount < balance) balance = amount;
            payable(owner).transfer(balance);
        } else {
            // Recover erc20
            IERC20 t = IERC20(token);
            uint256 balance = t.balanceOf(address(this));
            require(balance > 0, ERR_NOTHING);
            if (token == _tokenAddress) {
                // do not touch stake and rewards
                uint256 counted = _totalFreeRewards + _stakedAndRewards;
                require(balance > counted, ERR_NOTHING);
                balance -= counted;
            }
            // needed for some "fee on transfer" tokens
            if (amount > 0 && balance > amount) {
                balance = amount;
            }

            t.transfer(owner, balance);
        }
    }
}
