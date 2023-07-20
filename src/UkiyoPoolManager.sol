//SPDX-License-Identifier: MIT

pragma solidity >=0.8.20;

import "oz/contracts/token/ERC721/IERC721Receiver.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "v3-core/contracts/libraries/TickMath.sol";
import {SqrtPriceMath} from "v3-core/contracts/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "./libraries/LiquidityAmounts.sol";

contract UkiyoPoolManager is IERC721Receiver {
    //============================================================\\
    //=================== FUNCTION SIGNATURES ====================\\
    //============================================================\\

    // 0x23b872dd transferFrom(address,address,uint256)
    // 0x095ea7b3 approve(address,uint256)
    // 0x88316456 mint(MintParams)
    // 0x70a08231 balanceOf(address)
    // 0xa9059cbb transfer(address,uint256)
    // 0x99fbab88 positions(uint256)
    // 0x3850c7bd slot0()
    // 0x219f5d17 increaseLiquidity(params)
    // 0x2e1a7d4d withdraw(uint256)
    // 0x57f767f4 liquidityBurnCallback(uint256)
    // 0xfc6f7865 collect(CollectParams)
    // 0x0c49ccbe decreaseLiquidity(LiquidityParams)

    //============================================================\\
    //===================== ERROR SIGNATURES =====================\\
    //============================================================\\

    // 0x112db0cd LiquidityIncreaseFailed()

    //============================================================\\

    address private constant nonfungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant FRAX_MINTER = 0xbAFA44EFE7901E04E39Dad13167D089C559c1138;
    address private immutable token0;
    address private immutable token1;
    address private immutable owner;
    address private pool;
    address private treasury;
    address private handler;
    uint128 private initialLiquidity;
    uint256 private currentTokenId;
    uint256 private nextTokenId;
    uint24 private immutable poolFee;
    Migration public migration;

    struct Migration {
        uint256 start;
        uint256 end;
        bool started;
    }

    modifier onlyTreasury() {
        if (msg.sender != treasury) revert OnlyTreasury();
        _;
    }

    constructor(address _pool) {
        owner = msg.sender;
        pool = _pool;
        token0 = IUniswapV3Pool(_pool).token0();
        token1 = IUniswapV3Pool(_pool).token1();
        poolFee = IUniswapV3Pool(_pool).fee();
        approvals(token0, token1);
    }

    //============================================================\\
    //==================== EXTERNAL FUNCTIONS ====================\\
    //============================================================\\

    function setTreasuryAndHandler(address _treasury, address _handler) external {
        if (msg.sender != owner) revert OnlyOwner();
        treasury = _treasury;
        handler = _handler;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    ///@notice mint a new liquidity position
    ///@param amount0Desired the amount of token 0 you would like to add to the new position
    ///@param amount1Desired the amount of token1 you would like to add to the new position
    ///@param tickLower the lower tick of the liquidity position
    ///@param tickUpper the upper tick of the liquidity position
    function mintNewPosition(uint256 amount0Desired, uint256 amount1Desired, int24 tickLower, int24 tickUpper)
        public
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        _onlyOwner(msg.sender);
        address zero = token0;
        address one = token1;
        uint24 fee = poolFee;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), amount0Desired)
            let result := call(gas(), zero, 0, ptr, 100, 0, 0)
            if eq(result, 0) {
                mstore(0, 0x7939f42400000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 100)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), amount1Desired)
            let result2 := call(gas(), one, 0, ptr, 100, 0, 0)
            if eq(result2, 0) {
                mstore(0, 0x7939f42400000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 100)
            mstore(ptr, 0x8831645600000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(zero, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), and(one, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), and(fee, 0xffffff))
            mstore(add(ptr, 100), tickLower)
            mstore(add(ptr, 132), tickUpper)
            mstore(add(ptr, 164), amount0Desired)
            mstore(add(ptr, 196), amount1Desired)
            mstore(add(ptr, 228), 0x00)
            mstore(add(ptr, 260), 0x00)
            mstore(add(ptr, 292), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 324), timestamp())
            let result5 := call(gas(), nonfungiblePositionManager, 0, ptr, 356, add(ptr, 356), 128)
            if eq(result5, 0) {
                mstore(0, 0x3f041ab600000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 356)
            tokenId := mload(ptr)
            sstore(currentTokenId.slot, tokenId)
            liquidity := mload(add(ptr, 32))
            sstore(initialLiquidity.slot, liquidity)
            amount0 := mload(add(ptr, 64))
            amount1 := mload(add(ptr, 96))

            ptr := add(ptr, 128)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), zero, ptr, 36, add(ptr, 36), 32))

            ptr := add(ptr, 36)
            let returnAmount0 := mload(ptr)

            ptr := add(ptr, 32)
            if gt(returnAmount0, 0) {
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(ptr, 36), returnAmount0)
                let result7 := call(gas(), zero, 0, ptr, 68, 0, 0)
                if eq(result7, 0) { revert(0, 0) }
                ptr := add(ptr, 68)
            }

            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), one, ptr, 36, add(ptr, 36), 32))

            ptr := add(ptr, 36)
            let returnAmount1 := mload(ptr)

            if gt(returnAmount1, 0) {
                ptr := add(ptr, 32)
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(ptr, 36), returnAmount1)
                let result9 := call(gas(), one, 0, ptr, 68, 0, 0)
                if eq(result9, 0) { revert(0, 0) }
            }
        }
        emit PositionCreated(tokenId, liquidity, amount0, amount1);
    }

    ///@notice increase the current liquidity range
    ///@dev calculatedAmount is determined using mintAmount which is called by the treasury and is used
    /// to make sure that the ratio is correct when minting the new tokens to deposit into the lp position.
    ///@param tokenId the token id of the current liquidity position
    ///@param amount the amount of weth in this case that you are adding
    ///@param calculatedAmount the amount of ukiyo you are adding
    function increaseLiquidityCurrentRange(uint256 tokenId, uint256 amount, uint256 calculatedAmount)
        external
        onlyTreasury
        returns (uint128 liquidityAmount, uint256 amount0, uint256 amount1)
    {
        if (token1 == WETH) {
            (liquidityAmount, amount0, amount1) = mintToken0(treasury, tokenId, amount, calculatedAmount);
        } else {
            (liquidityAmount, amount0, amount1) = mintToken1(treasury, tokenId, amount, calculatedAmount);
        }

        burnExcessUkiyo();
        stakeExcessEth();
    }

    ///@notice decreases liquidity when ukiyo is being burned
    ///@param tokenId the current liquidity position to get the liquidity from
    ///@param liquidity the amount of liquidity to withdraw
    function decreaseLiquidity(uint256 tokenId, uint128 liquidity)
        external
        onlyTreasury
        returns (uint256 amount0, uint256 amount1)
    {
        address _treasury = treasury;
        address feeHandler = handler;
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0xfc6f786500000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), tokenId)
            mstore(add(ptr, 36), and(feeHandler, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            mstore(add(ptr, 100), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            let result := call(gas(), nonfungiblePositionManager, 0, ptr, 132, 0, 0)
            if eq(result, 0) {
                mstore(0, 0xf94220a000000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 132)
            mstore(ptr, 0x0c49ccbe00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), tokenId)
            mstore(add(ptr, 36), liquidity)
            mstore(add(ptr, 68), 0x00)
            mstore(add(ptr, 100), 0x00)
            mstore(add(ptr, 132), timestamp())
            let result2 := call(gas(), nonfungiblePositionManager, 0, ptr, 164, 0, 0)
            if eq(result2, 0) {
                mstore(0, 0xa5bc7c4700000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 164)
            mstore(ptr, 0xfc6f786500000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), tokenId)
            mstore(add(ptr, 36), and(_treasury, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            mstore(add(ptr, 100), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            let result3 := call(gas(), nonfungiblePositionManager, 0, ptr, 132, add(ptr, 132), 64)
            if eq(result3, 0) {
                mstore(0, 0xf94220a000000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            ptr := add(ptr, 132)
            amount0 := mload(ptr)
            amount1 := mload(add(ptr, 32))
        }
    }

    ///@notice function to rebalance liquidity when necessary
    ///@dev when rebalancing it is important to consider the current and new ratio. If they are not the same you will need to deal with excess tokens in some way.
    /// we have gone with a gradual dutch auction to handle the rebalance into the desired  ratio. taken from https://github.com/FrankieIsLost/gradual-dutch-auction/blob/master/src/ContinuousGDA.sol
    /// it is also available to see within the Fee Handler contract.
    function rebalance() external {
        _onlyOwner(msg.sender);
        uint256 currentId = currentTokenId;
        address _handler = handler;
        (,, uint128 currentLiquidity,) = getPositionInfo(currentId);
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x959b13d900000000000000000000000000000000000000000000000000000000)
            let success := call(gas(), _handler, 0, ptr, 4, 0, 0)
            if eq(success, 0) {
                mstore(0, 0x2d4a08cc00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 4)

            mstore(ptr, 0x0c49ccbe00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), currentId)
            mstore(add(ptr, 36), currentLiquidity)
            mstore(add(ptr, 68), 0x00)
            mstore(add(ptr, 100), 0x00)
            mstore(add(ptr, 132), timestamp())
            let result := call(gas(), nonfungiblePositionManager, 0, ptr, 164, 0, 0)
            if eq(result, 0) {
                mstore(0, 0xa5bc7c4700000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            mstore(ptr, 0xfc6f786500000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), currentId)
            mstore(add(ptr, 36), and(_handler, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            mstore(add(ptr, 100), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            let collectResult := call(gas(), nonfungiblePositionManager, 0, ptr, 132, 0, 0)
            if eq(collectResult, 0) {
                mstore(0, 0xf94220a000000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
        }
    }

    ///@notice rebalance function called by the handler after the auctions have finished
    ///@param lower lower tick of the new position
    ///@param upper upper tick of the new position
    ///@param amount0 the amount of token zero that is desired to add
    ///@param amount1 the amount of token one that is desired to add
    ///@param initial if it is the first rebalance or not.
    ///@param finished if the rebalance has completed
    function handlerRebalance(int24 lower, int24 upper, uint256 amount0, uint256 amount1, bool initial, bool finished)
        external
    {
        address _handler = handler;
        if (msg.sender != _handler) revert OnlyHandler();
        address zero = token0;
        uint256 tokenId = currentTokenId;
        uint256 fee = poolFee;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(_handler, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), amount1)
            let result := call(gas(), WETH, 0, ptr, 100, 0, 0)
            if eq(result, 0) {
                mstore(0, 0x7939f42400000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 100)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(_handler, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), amount0)
            let result2 := call(gas(), zero, 0, ptr, 100, 0, 0)
            if eq(result2, 0) {
                mstore(0, 0x7939f42400000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 100)

            // Mint a new liquidity position
            if eq(initial, 0x01) {
                mstore(ptr, 0x8831645600000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), and(zero, 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(ptr, 36), and(WETH, 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(ptr, 68), and(fee, 0xffffff))
                mstore(add(ptr, 100), lower)
                mstore(add(ptr, 132), upper)
                mstore(add(ptr, 164), amount0)
                mstore(add(ptr, 196), amount1)
                mstore(add(ptr, 228), 0x00)
                mstore(add(ptr, 260), 0x00)
                mstore(add(ptr, 292), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(ptr, 324), timestamp())
                let mintResult := call(gas(), nonfungiblePositionManager, 0, ptr, 356, add(ptr, 356), 128)
                if eq(mintResult, 0) {
                    mstore(0, 0x07637bd800000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
                ptr := add(ptr, 356)
                let newId := mload(ptr)
                let newInitialLiquidity := mload(add(ptr, 32))
                ptr := add(ptr, 128)

                sstore(currentTokenId.slot, newId)
                sstore(initialLiquidity.slot, newInitialLiquidity)
            }
            if eq(initial, 0x00) {
                if eq(finished, 0x00) {
                    mstore(ptr, 0x219f5d1700000000000000000000000000000000000000000000000000000000)
                    mstore(add(ptr, 4), tokenId)
                    mstore(add(ptr, 36), amount0)
                    mstore(add(ptr, 68), amount1)
                    mstore(add(ptr, 100), 0x00)
                    mstore(add(ptr, 132), 0x00)
                    mstore(add(ptr, 164), timestamp())

                    let result3 := call(gas(), nonfungiblePositionManager, 0, ptr, 196, add(ptr, 196), 96)
                    if eq(result3, 0) {
                        mstore(0, 0x112db0cd00000000000000000000000000000000000000000000000000000000)
                        revert(0, 4)
                    }
                }
            }
            if eq(finished, 0x01) {
                mstore(ptr, 0xc015539900000000000000000000000000000000000000000000000000000000)
                let completed := call(gas(), _handler, 0, ptr, 4, 0, 0)
                if eq(completed, 0) {
                    mstore(0, 0xcf6f807d00000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
            }
        }
        transferToHandler(zero, _handler);
    }

    ///@notice collects swap fees and sends them to the handler
    ///@param tokenId the current liquidity id
    function collectFees(uint256 tokenId) external returns (uint256 amount0, uint256 amount1) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0xfc6f786500000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), tokenId)
            mstore(add(ptr, 36), and(sload(handler.slot), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            mstore(add(ptr, 100), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            let result := call(gas(), nonfungiblePositionManager, 0, ptr, 132, add(ptr, 132), 64)
            if eq(result, 0) {
                mstore(0, 0xf94220a000000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            ptr := add(ptr, 132)
            amount0 := mload(ptr)
            amount1 := mload(add(ptr, 32))
        }
    }

    //============================================================\\
    //=================== MIGRATION FUNCTIONS ====================\\
    //============================================================\\

    ///@notice function to start the migration of liquidity if needed
    ///@dev there is a two week timelock
    function startMigration() external {
        _onlyOwner(msg.sender);
        migration = Migration({start: block.timestamp, end: block.timestamp + 1209600, started: true});
    }

    ///@notice executes the migration after the timelock has passed.
    function executeMigration(address _migrationHandler, uint128 liquidityAmount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (msg.sender != owner || migration.started == false || migration.end > block.timestamp) {
            revert MigrationError();
        }

        uint256 currentId = currentTokenId;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x0c49ccbe00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), currentId)
            mstore(add(ptr, 36), liquidityAmount)
            mstore(add(ptr, 68), 0x00)
            mstore(add(ptr, 100), 0x00)
            mstore(add(ptr, 132), timestamp())
            let result := call(gas(), nonfungiblePositionManager, 0, ptr, 164, 0, 0)
            if eq(result, 0) {
                mstore(0, 0xa5bc7c4700000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            ptr := add(ptr, 164)
            mstore(ptr, 0xfc6f786500000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), currentId)
            mstore(add(ptr, 36), and(_migrationHandler, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            mstore(add(ptr, 100), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            let collectResult := call(gas(), nonfungiblePositionManager, 0, ptr, 132, add(ptr, 132), 64)
            if eq(collectResult, 0) {
                mstore(0, 0xf94220a000000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            ptr := add(ptr, 132)
            amount0 := mload(ptr)
            amount1 := mload(add(ptr, 32))
        }
        emit MigrationExecuted(msg.sender, _migrationHandler, block.timestamp, amount0, amount1);
    }

    //============================================================\\
    //================= EXTERNAL VIEW FUNCTIONS ==================\\
    //============================================================\\

    ///@notice calculates how much weth is currently in the lp position minus what was deposited from the initial liquidity
    ///@dev initial liquidity here does not refer to the amount of weth initially deposited, but weth in total liquidity - initial
    function wethInPosition() external view returns (uint256 amount) {
        (int24 tickLower, int24 tickUpper, uint128 liquidity, uint160 sqrtPriceX96) = getPositionInfo(currentTokenId);
        if (token1 == WETH) {
            uint160 sqrtPriceA = TickMath.getSqrtRatioAtTick(tickLower);
            amount = SqrtPriceMath.getAmount1Delta(sqrtPriceX96, sqrtPriceA, liquidity - initialLiquidity, true);
        } else {
            uint160 sqrtPriceA = TickMath.getSqrtRatioAtTick(tickUpper);
            amount = SqrtPriceMath.getAmount0Delta(sqrtPriceA, sqrtPriceX96, liquidity - initialLiquidity, true);
        }
    }

    ///@notice calculates the amount of ukiyo in the LP minus what was initially deposited
    ///@dev same thing applies as in wethInPosition
    function ukiyoAmountForLiquidity() external view returns (uint256 ukiyoAmount) {
        (int24 tickLower, int24 tickUpper, uint128 liquidity, uint160 sqrtPriceX96) = getPositionInfo(currentTokenId);
        if (token0 != WETH) {
            uint160 sqrtPriceA = TickMath.getSqrtRatioAtTick(tickUpper);
            ukiyoAmount = SqrtPriceMath.getAmount0Delta(sqrtPriceA, sqrtPriceX96, liquidity - initialLiquidity, true);
        } else {
            uint160 sqrtPriceA = TickMath.getSqrtRatioAtTick(tickLower);
            ukiyoAmount = SqrtPriceMath.getAmount1Delta(sqrtPriceA, sqrtPriceX96, liquidity - initialLiquidity, true);
        }
    }

    ///@notice returns the current liquidity id
    function liquidityId() external view returns (uint256) {
        return currentTokenId;
    }

    ///@notice the total available liquidity in the protocol owned position
    function totalAvailableLiquidity() external view returns (uint128 availableLiquidity) {
        uint256 tokenId = currentTokenId;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x99fbab8800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), tokenId)
            let result := staticcall(gas(), nonfungiblePositionManager, ptr, 36, 0, 0)
            ptr := add(ptr, 36)
            returndatacopy(ptr, 224, 32)
            availableLiquidity := mload(ptr)
        }
    }

    ///@notice gets useful information about the current liquidity position
    function getPositionInfo(uint256 tokenId)
        internal
        view
        returns (int24 lower, int24 upper, uint128 liquidity, uint160 currentSqrtPriceX96)
    {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x99fbab8800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), tokenId)
            let result := staticcall(gas(), nonfungiblePositionManager, ptr, 36, 0, 0)
            ptr := add(ptr, 36)
            returndatacopy(ptr, 160, 96)
            lower := mload(ptr)
            upper := mload(add(ptr, 32))
            liquidity := mload(add(ptr, 64))
            ptr := add(ptr, 96)
            mstore(ptr, 0x3850c7bd00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), sload(pool.slot), ptr, 4, add(ptr, 4), 224))
            currentSqrtPriceX96 := mload(add(ptr, 4))
        }
    }

    ///@notice gets the liquidity deposited when a new position is created
    function getInitialLiquidity() external view returns (uint128) {
        return initialLiquidity;
    }

    ///@notice calculated how much ukiyo to mint based on the amount of weth that is being added to liquidity
    function mintAmount(uint256 tokenId, uint256 amount) external view returns (uint256 amountToMint) {
        (int24 lower, int24 upper,, uint160 currentSqrtPriceX96) = getPositionInfo(tokenId);
        uint160 sqrtPriceAX96 = TickMath.getSqrtRatioAtTick(lower);
        uint160 sqrtPriceBX96 = TickMath.getSqrtRatioAtTick(upper);
        uint128 liquidity;
        if (WETH == token1) {
            liquidity = LiquidityAmounts.getLiquidityForAmount1(sqrtPriceAX96, currentSqrtPriceX96, amount);
            amountToMint = SqrtPriceMath.getAmount0Delta(currentSqrtPriceX96, sqrtPriceBX96, liquidity, true);
        } else {
            liquidity = LiquidityAmounts.getLiquidityForAmount0(currentSqrtPriceX96, sqrtPriceBX96, amount);
            amountToMint = SqrtPriceMath.getAmount1Delta(sqrtPriceAX96, currentSqrtPriceX96, liquidity, true);
        }
    }

    //============================================================\\
    //=================== INTERNAL FUNCTIONS =====================\\
    //============================================================\\

    ///@notice internal function to transfer tokens to the handler contract during rebalancing
    function transferToHandler(address zero, address _handler) private {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), WETH, ptr, 36, add(ptr, 36), 32))
            ptr := add(ptr, 36)
            let wethBalance := mload(ptr)
            ptr := add(ptr, 32)

            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), zero, ptr, 36, add(ptr, 36), 32))
            ptr := add(ptr, 36)
            let ukiyoBalance := mload(ptr)
            ptr := add(ptr, 32)

            if gt(wethBalance, 0) {
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), and(_handler, 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(ptr, 36), wethBalance)
                let success := call(gas(), WETH, 0, ptr, 68, 0, 32)
                if eq(success, 0) {
                    mstore(32, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
            }

            if gt(ukiyoBalance, 0) {
                mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), and(_handler, 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(ptr, 36), ukiyoBalance)
                let success := call(gas(), zero, 0, ptr, 68, 0, 32)
                if eq(success, 0) {
                    mstore(32, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
            }
        }
    }

    ///@notice deposits into the liquidity position
    ///@dev called when ukiyo is token1
    ///@param treasuryAddress the address of the treasury
    ///@param tokenId the current liquidity position Id
    ///@param amount the amount of weth in this case to deposit
    ///@param _mintAmount the amount of minted ukiyo tokens to deposit
    function mintToken1(address treasuryAddress, uint256 tokenId, uint256 amount, uint256 _mintAmount)
        private
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(treasuryAddress, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), amount)
            let result := call(gas(), WETH, 0, ptr, 100, 0, 0)
            if eq(result, 0) {
                mstore(0, 0x7939f42400000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 100)
            mstore(ptr, 0x219f5d1700000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), tokenId)
            mstore(add(ptr, 36), amount)
            mstore(add(ptr, 68), _mintAmount)
            mstore(add(ptr, 100), 0x00)
            mstore(add(ptr, 132), 0x00)
            mstore(add(ptr, 164), timestamp())

            let result2 := call(gas(), nonfungiblePositionManager, 0, ptr, 196, add(ptr, 196), 96)

            if eq(result2, 0) {
                mstore(0, 0x112db0cd00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            ptr := add(ptr, 196)
            liquidity := mload(ptr)
            amount0 := mload(add(ptr, 32))
            amount1 := mload(add(ptr, 64))
        }
    }

    ///@notice deposits into the liquidity position
    ///@dev called when ukiyo is token0
    ///@param treasuryAddress the address of the treasury
    ///@param tokenId the current liquidity position Id
    ///@param amount the amount of weth in this case to deposit
    ///@param _mintAmount the amount of minted ukiyo tokens to deposit
    function mintToken0(address treasuryAddress, uint256 tokenId, uint256 amount, uint256 _mintAmount)
        private
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(treasuryAddress, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), amount)
            let result := call(gas(), WETH, 0, ptr, 100, 0, 0)
            if eq(result, 0) {
                mstore(0, 0x7939f42400000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 100)
            mstore(ptr, 0x219f5d1700000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), tokenId)
            mstore(add(ptr, 36), _mintAmount)
            mstore(add(ptr, 68), amount)
            mstore(add(ptr, 100), 0x00)
            mstore(add(ptr, 132), 0x00)
            mstore(add(ptr, 164), timestamp())

            let result2 := call(gas(), nonfungiblePositionManager, 0, ptr, 196, add(ptr, 196), 96)

            if eq(result2, 0) {
                mstore(0, 0x112db0cd00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 196)
            liquidity := mload(ptr)
            amount0 := mload(add(ptr, 32))
            amount1 := mload(add(ptr, 64))
        }
    }

    ///@notice in case of a time where there is additional eth after increasing liquidity that eth will get staked
    function stakeExcessEth() private {
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), WETH, ptr, 36, add(ptr, 36), 32))
            ptr := add(ptr, 36)
            let wethBalance := mload(ptr)
            ptr := add(ptr, 32)

            if gt(wethBalance, 0) {
                mstore(ptr, 0x2e1a7d4d00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), wethBalance)
                let result2 := call(gas(), WETH, 0, ptr, 36, 0, 0)
                if eq(result2, 0) {
                    mstore(0, 0x3f6134c700000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
                ptr := add(ptr, 36)
                mstore(ptr, 0x4dcd454700000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), and(sload(treasury.slot), 0xffffffffffffffffffffffffffffffffffffffff))
                let result3 := call(gas(), FRAX_MINTER, wethBalance, ptr, 36, 0, 0)
                if eq(result3, 0) {
                    mstore(0, 0xa437293700000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
            }
        }
    }

    ///@notice in case of a time where there is additional ukiyo after increasing liquidity that ukiyo will get burned
    function burnExcessUkiyo() private {
        address token = token0 == WETH ? token1 : token0;
        uint256 ukiyoBalance;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), token, ptr, 36, add(ptr, 36), 32))
            ptr := add(ptr, 36)

            ukiyoBalance := mload(ptr)

            if gt(ukiyoBalance, 0) {
                ptr := add(ptr, 32)
                mstore(ptr, 0x57f767f400000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), ukiyoBalance)
                let result2 := call(gas(), sload(treasury.slot), 0, ptr, 36, 0, 0)
                if eq(result2, 0) {
                    mstore(0, 0x6f16aafc00000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
            }
        }

        emit UkiyoBurned(ukiyoBalance);
    }

    function approvals(address _token0, address _token1) internal {
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), nonfungiblePositionManager)
            mstore(add(ptr, 36), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            let result := call(gas(), _token0, 0, ptr, 68, 0, 0)

            ptr := add(ptr, 68)

            mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), nonfungiblePositionManager)
            mstore(add(ptr, 36), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            let result2 := call(gas(), _token1, 0, ptr, 68, 0, 0)
        }
    }

    function _onlyOwner(address caller) internal view {
        if (caller != owner) revert OnlyOwner();
    }

    //============================================================\\
    //==================== ERRORS AND EVENTS =====================\\
    //============================================================\\

    error OnlyTreasury();
    error OnlyOwner();
    error MigrationError();
    error OnlyHandler();

    event MigrationExecuted(
        address indexed caller, address indexed handler, uint256 timestamp, uint256 amount0, uint256 amount1
    );
    event PositionCreated(uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    event Rebalance(address indexed caller, bool first, bool last, uint128 liquidityTransfered);
    event UkiyoBurned(uint256 burnedExcessUkiyo);

    receive() external payable {}
}
