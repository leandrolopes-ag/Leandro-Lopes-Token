// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "./IERC20.sol";
import "./Ownable.sol";
import "./IVesting.sol";
import "./IStake.sol";

contract Vesting is Ownable, IVesting {
    mapping(address => Vest[]) private _vestings;

    /// Amount of tokens inside vesting contract
    uint256 public vested;
    /// Address of ERC20 token contract
    address public immutable tokenAddress;

    /**
        Contract constructor
        @param token address of ERC20 token to be vested
     */
    constructor(address token) {
        tokenAddress = token;
        name = concat("vested ", IERC20(token).name());
        symbol = concat("v", IERC20(token).symbol());
    }

    /**
        Concat two strings
        @param a first string
        @param b second string
        @return concatenated strings
     */
    function concat(string memory a, string memory b)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(a, b));
    }

    // Internal add vesting function
    function _addVesting(
        address user,
        uint256 startDate,
        uint256 endDate,
        uint256 startTokens,
        uint256 totalTokens
    ) internal {
        require(user != ZERO_ADDRESS, "Address 0x0 is prohibited");
        require(user.code.length == 0, "Contracts are prohibited");
        require(startDate > block.timestamp, "Start date in past");
        require(endDate >= startDate, "Date setup mismatch");
        require(totalTokens > startTokens, "Token number mismatch");
        _vestings[user].push(
            Vest(startDate, endDate, startTokens, totalTokens, 0)
        );
        emit VestAdded(user, startDate, endDate, startTokens, totalTokens);
        vested += totalTokens;
    }

    /**
        Create single Vesting in contract
        @param user address of the user
        @param startDate timestamp on which user can start claiming
        @param endDate timestamp on which all tokens are freed
        @param startTokens amount of tokens on cliff startDate
        @param totalTokens total amount of tokens in this vesting
     */
    function createVest(
        address user,
        uint256 startDate,
        uint256 endDate,
        uint256 startTokens,
        uint256 totalTokens
    ) external onlyOwner {
        _addVesting(user, startDate, endDate, startTokens, totalTokens);
        require(
            IERC20(tokenAddress).transferFrom(
                msg.sender,
                address(this),
                totalTokens
            ),
            "" // this will revert in token if no allowance or balance
        );
    }

    /**
        Create many vestings in one call
        @param user array of user addresses
        @param startDate array of start timestamps
        @param endDate array of end timestamps
        @param startTokens array of tokens on cliff
        @param totalTokens array of total tokens vested
     */
    function massCreateVest(
        address[] calldata user,
        uint256[] calldata startDate,
        uint256[] calldata endDate,
        uint256[] calldata startTokens,
        uint256[] calldata totalTokens
    ) external onlyOwner {
        uint256 len = user.length;
        require(
            len == startTokens.length &&
                len == endDate.length &&
                len == startTokens.length &&
                len == totalTokens.length,
            "Data size mismatch"
        );
        uint256 total;
        uint256 i;
        for (i; i < len; i++) {
            uint256 tokens = totalTokens[i];
            total += tokens;
            _addVesting(
                user[i],
                startDate[i],
                endDate[i],
                startTokens[i],
                tokens
            );
        }
        require(
            IERC20(tokenAddress).transferFrom(msg.sender, address(this), total),
            "" // this will revert in token if no allowance or balance
        );
    }

    /**
        Get all vestings for given user
        @param user address to check
        @return array of Vest struct
     */
    function getVestings(address user) external view returns (Vest[] memory) {
        return _vestings[user];
    }

    /**
        Read number of vests created for given user
        @param user address to check
        @return number of vestings
     */
    function getVestingCount(address user) external view returns (uint256) {
        return _vestings[user].length;
    }

    /**
        Get singe vesting parameters for given user
        @param user address to check
        @param index index of vesting to read
        @return single Vest struct
     */
    function getVesting(address user, uint256 index)
        external
        view
        returns (Vest memory)
    {
        require(index < _vestings[user].length, "Index out out bounds");
        return _vestings[user][index];
    }

    /**
        How much tokens can be claimed now by given user
        @param user address to check
        @return sum of tokens available to claim
     */
    function claimable(address user) external view returns (uint256 sum) {
        uint256 len = _vestings[user].length;
        uint256 time = block.timestamp;
        if (len > 0) {
            uint256 i;
            for (i; i < len; i++) {
                sum += _claimable(_vestings[user][i], time);
            }
        }
    }

    /**
        Count number of tokens claimable from vesting at given time
        @param c Vesting struct data
        @param time timestamp to calculate
        @return amt number of tokens possible to claim
     */
    function _claimable(Vest memory c, uint256 time)
        internal
        pure
        returns (uint256 amt)
    {
        if (time > c.startDate) {
            if (time > c.endDate) {
                // all coins can be released
                amt = c.totalTokens;
            } else {
                // we need calculate how much can be released
                uint256 pct = ((time - c.startDate) * 1 gwei) /
                    (c.endDate - c.startDate);
                amt =
                    c.startTokens +
                    ((c.totalTokens - c.startTokens) * pct) /
                    1 gwei;
            }
            amt -= c.claimed; // some may be already claimed
        }
    }

    /**
        Claim all possible vested tokens by caller
     */
    function claim() external {
        uint256 sum = _claim(msg.sender, block.timestamp);
        require(
            IERC20(tokenAddress).transfer(msg.sender, sum),
            "" // will fail in token on transfer error
        );
    }

    /**
        Claim tokens for someone (pay network fees)
        @param user address of vested user to claim
     */
    function claimFor(address user) external {
        uint256 sum = _claim(user, block.timestamp);
        require(
            IERC20(tokenAddress).transfer(user, sum),
            "" // will fail in token on transfer error
        );
    }

    /**
        Claim one of vestings for given user.
        Can be handy if many vestings per account.
        @param user address to claim
        @param index index of vesting to be claimed
     */
    function claimOneFor(address user, uint256 index) external {
        require(index < _vestings[user].length, "Index out of bounds");
        Vest storage c = _vestings[user][index];
        uint256 amt = _claimable(c, block.timestamp);
        require(amt > 0, "Nothing to claim");
        c.claimed += amt;
        vested -= amt;
        require(
            IERC20(tokenAddress).transfer(user, amt),
            "" // will fail in token on transfer error
        );
        emit Claimed(user, amt);
    }

    /**
        Internal claim function
        @param user address to calculate
        @return sum number of tokens claimed
     */
    function _claim(address user, uint256 time) internal returns (uint256 sum) {
        uint256 len = _vestings[user].length;
        require(len > 0, "No locks for user");

        uint256 i;
        for (i; i < len; i++) {
            Vest storage c = _vestings[user][i];
            uint256 amt = _claimable(c, time);
            c.claimed += amt;
            sum += amt;
        }

        require(sum > 0, "Nothing to claim");
        vested -= sum;
        emit Claimed(user, sum);
    }

    //
    // Stake/Claim2stake
    //
    /// Address of stake contract
    address public stakeAddress;

    /**
        Set address of stake contract (once, only owner)
        @param stake contract address
     */
    function setStakeAddress(address stake) external onlyOwner {
        require(stakeAddress == ZERO_ADDRESS, "Contract already set");
        stakeAddress = stake;
        require(
            IStake(stake).vestingAddress() == address(this),
            "Wrong contract address"
        );
        require(
            IERC20(tokenAddress).approve(stake, type(uint256).max),
            "Token approval failed"
        );
    }

    /**
        Claim possible tokens and stake directly to stake pool
     */
    function claim2stake(uint256 index) external {
        require(stakeAddress != ZERO_ADDRESS, "Stake contract not set");
        uint256 sum = _claim(msg.sender, block.timestamp);
        require(
            IStake(stakeAddress).claim2stake(msg.sender, index, sum),
            "Claim2stake call failed"
        );
    }

    //
    // ETH/ERC20 recovery
    //
    string internal constant ERR_NTR = "Nothing to recover";

    /**
        Recover accidentally send ETH or ERC20 tokens
        @param token address of ERC20 token contract, 0x0 if ETH recovery
        @param amount amount of coins/tokens to recover, 0=all
     */
    function recover(address token, uint256 amount) external onlyOwner {
        if (token == ZERO_ADDRESS) {
            uint256 balance = address(this).balance;
            require(balance > 0, ERR_NTR);
            if (amount > 0 && amount < balance) balance = amount;
            payable(owner).transfer(balance);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            require(balance > 0, ERR_NTR);
            if (token == tokenAddress) {
                balance -= vested; // vested tokens can not be removed
            }
            if (amount > 0 && amount < balance) balance = amount;

            require(IERC20(token).transfer(owner, balance), "");
        }
    }

    //
    // Imitate ERC20 token, show unclaimed tokens
    //

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    /**
        Read total unclaimed balance for given user
        @param user address to check
        @return amount of unclaimed tokens locked in contract
     */
    function balanceOf(address user) external view returns (uint256 amount) {
        uint256 len = _vestings[user].length;
        if (len > 0) {
            uint256 i;
            for (i; i < len; i++) {
                Vest memory v = _vestings[user][i];
                amount += (v.totalTokens - v.claimed);
            }
        }
    }

    /**
        Imitation of ERC20 transfer() function to claim from wallet.
        Ignoring parameters, returns true if claim succeed.
     */
    function transfer(address, uint256) external returns (bool) {
        uint256 sum = _claim(msg.sender, block.timestamp);
        require(
            IERC20(tokenAddress).transfer(msg.sender, sum),
            "" // will throw in token contract on transfer fail
        );
        return true;
    }
}
