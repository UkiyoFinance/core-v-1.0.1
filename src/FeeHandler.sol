//SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import {IERC20} from "oz/contracts/token/ERC20/IERC20.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";
import {IFraxMinter} from "./interfaces/IFraxMinter.sol";
import {IUkiyoTreasury} from "./interfaces/IUkiyoTreasury.sol";
import {IUkiyoPoolManager} from "./interfaces/IUkiyoPoolManager.sol";
import {PRBMathSD59x18} from "./libraries/PRBMathSD59x18.sol";

contract FeeHandler {
    using PRBMathSD59x18 for int256;

    WETH private constant WETH9 = WETH(payable(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)));
    IFraxMinter private constant FRAX_MINTER = IFraxMinter(0xbAFA44EFE7901E04E39Dad13167D089C559c1138);
    address private treasury;
    address private poolManager;
    address private immutable ukiyo;
    address private owner;
    bool private underGoingRebalance;
    bool private approved;

    int256 private initialPrice;
    int256 private decayConstant;
    int256 private emissionRate;
    int256 private lastAvailableAuctionStartTime;
    uint256 private amountForSell;


    error OnlyOwner();
    error OnlyManager();
    error Rebalancing();
    error InsufficientAvailableTokens();
    error InsufficientPayment();
    error UnableToRefund();
    error TransferFromFailed();
    error InsufficentRemaining();

    event FeesBurned(address indexed caller, address token, uint256 shares, uint256 blockTimestamp);
    event TreasurySet(address indexed caller, address _treasury);
    event AuctionInitialized(int256 initialPrice, int256 decayConstant, int256 emissionRate, int256 timestamp);
    event Purchase(address indexed sender, address indexed to, uint256 numTokens, uint256 paidAmount, uint256 refund);

    constructor(address _ukiyo) {
        ukiyo = _ukiyo;
        owner = msg.sender;
    }

    function inititalizeAuction(
        int256 _initialPrice,
        int256 _decayConstant,
        int256 _emissionRate,
        uint256 _amountForSell
    ) external {
        if (msg.sender != owner) revert OnlyOwner();
        initialPrice = _initialPrice;
        decayConstant = _decayConstant;
        emissionRate = _emissionRate;
        lastAvailableAuctionStartTime = int256(block.timestamp).fromInt();
        amountForSell = _amountForSell;
        emit AuctionInitialized(_initialPrice, _decayConstant, _emissionRate, lastAvailableAuctionStartTime);
    }

    function purchaseTokens(uint256 numTokens, uint256 paidAmount, address to) external {
        if (numTokens > amountForSell) revert InsufficentRemaining();
        bool success = IERC20(ukiyo).transferFrom(msg.sender, address(this), paidAmount);
        if (!success) revert TransferFromFailed();
        //number of seconds of token emissions that are available to be purchased
        int256 secondsOfEmissionsAvaiable = int256(block.timestamp).fromInt() - lastAvailableAuctionStartTime;
        //number of seconds of emissions are being purchased
        int256 secondsOfEmissionsToPurchase = int256(numTokens).fromInt().div(emissionRate);
        //ensure there's been sufficient emissions to allow purchase
        if (secondsOfEmissionsToPurchase > secondsOfEmissionsAvaiable) {
            revert InsufficientAvailableTokens();
        }

        uint256 cost = purchasePrice(numTokens);
        if (paidAmount < cost) {
            revert InsufficientPayment();
        }

        //update last available auction
        lastAvailableAuctionStartTime += secondsOfEmissionsToPurchase;

        //refund extra payment
        uint256 refund = paidAmount - cost;
        amountForSell -= numTokens;
        bool sent = IERC20(ukiyo).transfer(to, refund);
        if (!sent) {
            revert UnableToRefund();
        }
        WETH9.transfer(msg.sender, numTokens);
        emit Purchase(msg.sender, to, numTokens, paidAmount, refund);
    }

    function purchasePrice(uint256 numTokens) public view returns (uint256) {
        int256 quantity = int256(numTokens).fromInt();
        int256 timeSinceLastAuctionStart = int256(block.timestamp).fromInt() - lastAvailableAuctionStartTime;
        int256 num1 = initialPrice.div(decayConstant);
        int256 num2 = decayConstant.mul(quantity).div(emissionRate).exp() - PRBMathSD59x18.fromInt(1);
        int256 den = decayConstant.mul(timeSinceLastAuctionStart).exp();
        int256 totalCost = num1.mul(num2).div(den);
        //total cost is already in terms of wei so no need to scale down before
        //conversion to uint. This is due to the fact that the original formula gives
        //price in terms of ether but we scale up by 10^18 during computation
        //in order to do fixed point math.
        return uint256(totalCost);
    }

    function setTreasuryAndPoolManager(address _treasury, address _poolManager) external {
        if (msg.sender != owner) revert OnlyOwner();
        treasury = _treasury;
        poolManager = _poolManager;
        emit TreasurySet(msg.sender, _treasury);
    }

    function distributeWeth() external {
        if (underGoingRebalance) revert Rebalancing();
        uint256 wethBalance = WETH9.balanceOf(address(this));
        WETH9.withdraw(wethBalance);
        uint256 amount1 = FRAX_MINTER.submitAndDeposit{value: wethBalance}(treasury);
        emit FeesBurned(msg.sender, address(WETH9), amount1, block.timestamp);
    }

    function distributeUkiyo() external {
        if (underGoingRebalance) revert Rebalancing();
        uint256 amount0 = IERC20(ukiyo).balanceOf(address(this));
        IUkiyoTreasury(treasury).burnFees(amount0);
        emit FeesBurned(msg.sender, ukiyo, amount0, block.timestamp);
    }

    function rebalancing() external {
        if (msg.sender != poolManager) revert OnlyManager();
        underGoingRebalance = true;
    }

    function doneRebalancing() external {
        if (msg.sender != poolManager) revert OnlyManager();
        underGoingRebalance = false;
    }

    function rebalancePool(int24 lower, int24 upper, uint256 amount0, uint256 amount1, bool initial, bool finished) external {
        if (msg.sender != owner) revert OnlyOwner();
        IUkiyoPoolManager(poolManager).handlerRebalance(lower, upper, amount0, amount1, initial, finished);
    }

    function approvals() external {
        if (approved == true || msg.sender != owner) revert OnlyOwner();
        IERC20(ukiyo).approve(poolManager, type(uint256).max);
        WETH9.approve(poolManager, type(uint256).max);
        approved = true;
    }

    function currentlyRebalancing() external view returns(bool) {
        return underGoingRebalance;
    }

    receive() external payable {}
}
