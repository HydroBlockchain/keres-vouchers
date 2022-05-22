// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {IERC20} from "oz/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "oz/contracts/access/Ownable.sol";
import "oz/contracts/security/ReentrancyGuard.sol";

contract KVSStaking is Ownable, ReentrancyGuard {
    error TransferFailed();
    error NotStaker();
    error InsufficientAmount();
    error PendingRequest();
    address immutable hydro;
    address immutable KVS;
    uint256 constant MAX_RATE = 4308750000000; //0.00000430875/min
    uint256 currentRate;
    uint256 totalStaked;
    bool stakeActive;

    struct Withdrawals {
        uint248 amount;
        bool pending;
        uint256 releaseAt;
    }
    struct User {
        uint184 amount;
        uint72 checkpoint;
        uint256 ratePerMin;
        Withdrawals requests;
    }

    event StakeInto(address indexed user, uint256 indexed amountStaked);
    event StakeRemoved(address indexed user, uint256 indexed amountRemoved);
    event KvsMint(address indexed user, uint256 kvsAmount);
    event RateUpdated(uint256 indexed newRate);
    event HydroRequest(address user, uint256 amount, uint256 releaseAt);
    event HydroClaimed(address user, uint256 amount);
    mapping(address => User) userStakeData;

    constructor(address _hydro, address _KVS) {
        KVS = _KVS;
        hydro = _hydro;
        currentRate = MAX_RATE;
    }

    modifier active() {
        require(stakeActive, "Not open to staking");
        _;
    }

    function toggleStake(bool val) public onlyOwner {
        stakeActive = val;
    }

    function stake(uint256 _amount) external active {
        if (!(IERC20(hydro).transferFrom(msg.sender, address(this), _amount)))
            revert TransferFailed();
        User storage u = userStakeData[msg.sender];
        uint256 toUse = currentRate;
        if (u.amount <= 0) {
            syncRate(false);
            u.ratePerMin = toUse;
        }
        u.amount += uint184(_amount);
        u.checkpoint = uint72(block.timestamp);
        totalStaked += _amount;
        emit StakeInto(msg.sender, _amount);
    }

    function checkCurrentRewards(address _user)
        public
        view
        returns (uint256 bonus)
    {
        User memory u = userStakeData[_user];
        assert(block.timestamp >= u.checkpoint);
        uint256 minPassed = (block.timestamp - u.checkpoint) / 60;
        uint256 minGen = u.ratePerMin * minPassed;
        bonus = (minGen * u.amount) / 1e18;
    }

    function syncRate(bool dir) internal {
        uint256 reductionPercentile = (10 * currentRate) / 1000000;
        if (dir) {
            currentRate += reductionPercentile;
        } else {
            currentRate -= reductionPercentile;
        }
        emit RateUpdated(currentRate);
    }

    function checkCurrentRate() public view returns (uint) {
        return currentRate;
    }

    function withdrawProfit(uint256 _amount) external {
        User storage u = userStakeData[msg.sender];
        if (u.amount <= 0) revert NotStaker();
        uint256 rewardDebt = checkCurrentRewards(msg.sender);
        if (rewardDebt < _amount) revert InsufficientAmount();
        //only update timestamp
        u.checkpoint = uint72(block.timestamp);
        IERC20(KVS).transfer(msg.sender, rewardDebt);
        emit KvsMint(msg.sender, rewardDebt);
    }

    function exit() external {
        User storage u = userStakeData[msg.sender];
        if (u.amount <= 0) revert NotStaker();
        uint toSend = u.amount;
        uint256 acc = checkCurrentRewards(msg.sender);
        u.checkpoint = uint72(block.timestamp);
        if (acc > 0) {
            require(IERC20(KVS).transfer(msg.sender, acc));
            emit KvsMint(msg.sender, acc);
        }
        u.amount = 0;
        placeReq(toSend, msg.sender);
        // require(IERC20(hydro).transfer(msg.sender, toSend));
        syncRate(true);
        totalStaked -= toSend;
        emit StakeRemoved(msg.sender, u.amount);
    }

    function viewUser(address _user) public view returns (User memory) {
        return userStakeData[_user];
    }

    function withdrawFunds(uint256 _amount) external nonReentrant {
        User storage u = userStakeData[msg.sender];
        if (u.amount <= 0) revert NotStaker();
        if (_amount > u.amount) revert InsufficientAmount();
        uint toSend = u.amount;
        placeReq(_amount, msg.sender);
        //send out debts
        //  require(IERC20(hydro).transfer(msg.sender, toSend));
        emit StakeRemoved(msg.sender, _amount);
        //send out bonus too
        if (checkCurrentRewards(msg.sender) > 0) {
            require(
                IERC20(KVS).transfer(
                    msg.sender,
                    checkCurrentRewards(msg.sender)
                )
            );
            emit KvsMint(msg.sender, checkCurrentRewards(msg.sender));
        }
        u.amount -= uint184(_amount);
        totalStaked -= _amount;
        if (u.amount == 0) {
            syncRate(true);
        }
        //reset checkpoint
        u.checkpoint = uint72(block.timestamp);
    }

    function placeReq(uint256 amount, address _user) internal {
        User storage u = userStakeData[msg.sender];
        if (u.requests.pending) revert PendingRequest();
        u.requests.pending = true;
        u.requests.amount = uint248(amount);
        u.requests.releaseAt = block.timestamp + 7 days;
        emit HydroRequest(msg.sender, amount, block.timestamp + 7 days);
    }

    function claimHydro() public {
        User storage u = userStakeData[msg.sender];
        require(block.timestamp >= u.requests.releaseAt, "Cannot release yet");
        require(IERC20(hydro).transfer(msg.sender, u.requests.amount));
        //reset vals
        u.requests.amount = 0;
        u.requests.pending = false;
        emit HydroClaimed(msg.sender, u.requests.amount);
    }

    function totalHydroStaked() public view returns (uint) {
        return totalStaked;
    }

    function transferOut(address token, uint256 amount) public onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }

    function modifyRate(uint256 _newRate) public onlyOwner {
        currentRate = _newRate;
    }
}
