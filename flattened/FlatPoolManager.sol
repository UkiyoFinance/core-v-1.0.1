//SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/// @title Pool state that never changes
/// @notice These parameters are fixed for a pool forever, i.e., the methods will always return the same values
interface IUniswapV3PoolImmutables {
    /// @notice The contract that deployed the pool, which must adhere to the IUniswapV3Factory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token0() external view returns (address);

    /// @notice The second of the two tokens of the pool, sorted by address
    /// @return The token contract address
    function token1() external view returns (address);

    /// @notice The pool's fee in hundredths of a bip, i.e. 1e-6
    /// @return The fee
    function fee() external view returns (uint24);

    /// @notice The pool tick spacing
    /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
    /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
    /// This value is an int24 to avoid casting even though it is always positive.
    /// @return The tick spacing
    function tickSpacing() external view returns (int24);

    /// @notice The maximum amount of position liquidity that can use any tick in the range
    /// @dev This parameter is enforced per tick to prevent liquidity from overflowing a uint128 at any point, and
    /// also prevents out-of-range liquidity from being used to prevent adding in-range liquidity to a pool
    /// @return The max amount of liquidity per tick
    function maxLiquidityPerTick() external view returns (uint128);
}

/// @title Pool state that can change
/// @notice These methods compose the pool's state, and can change with any frequency including multiple times
/// per transaction
interface IUniswapV3PoolState {
    /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
    /// when accessed externally.
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
    /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
    /// boundary.
    /// observationIndex The index of the last oracle observation that was written,
    /// observationCardinality The current maximum number of observations stored in the pool,
    /// observationCardinalityNext The next maximum number of observations, to be updated when the observation.
    /// feeProtocol The protocol fee for both tokens of the pool.
    /// Encoded as two 4 bit values, where the protocol fee of token1 is shifted 4 bits and the protocol fee of token0
    /// is the lower 4 bits. Used as the denominator of a fraction of the swap fee, e.g. 4 means 1/4th of the swap fee.
    /// unlocked Whether the pool is currently locked to reentrancy
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    /// @notice The fee growth as a Q128.128 fees of token0 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal0X128() external view returns (uint256);

    /// @notice The fee growth as a Q128.128 fees of token1 collected per unit of liquidity for the entire life of the pool
    /// @dev This value can overflow the uint256
    function feeGrowthGlobal1X128() external view returns (uint256);

    /// @notice The amounts of token0 and token1 that are owed to the protocol
    /// @dev Protocol fees will never exceed uint128 max in either token
    function protocolFees() external view returns (uint128 token0, uint128 token1);

    /// @notice The currently in range liquidity available to the pool
    /// @dev This value has no relationship to the total liquidity across all ticks
    function liquidity() external view returns (uint128);

    /// @notice Look up information about a specific tick in the pool
    /// @param tick The tick to look up
    /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
    /// tick upper,
    /// liquidityNet how much liquidity changes when the pool price crosses the tick,
    /// feeGrowthOutside0X128 the fee growth on the other side of the tick from the current tick in token0,
    /// feeGrowthOutside1X128 the fee growth on the other side of the tick from the current tick in token1,
    /// tickCumulativeOutside the cumulative tick value on the other side of the tick from the current tick
    /// secondsPerLiquidityOutsideX128 the seconds spent per liquidity on the other side of the tick from the current tick,
    /// secondsOutside the seconds spent on the other side of the tick from the current tick,
    /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
    /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
    /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
    /// a specific position.
    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
    function tickBitmap(int16 wordPosition) external view returns (uint256);

    /// @notice Returns the information about a position by the position's key
    /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
    /// @return _liquidity The amount of liquidity in the position,
    /// Returns feeGrowthInside0LastX128 fee growth of token0 inside the tick range as of the last mint/burn/poke,
    /// Returns feeGrowthInside1LastX128 fee growth of token1 inside the tick range as of the last mint/burn/poke,
    /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
    /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
    function positions(bytes32 key)
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    /// @notice Returns data about a specific observation index
    /// @param index The element of the observations array to fetch
    /// @dev You most likely want to use #observe() instead of this method to get an observation as of some amount of time
    /// ago, rather than at a specific index in the array.
    /// @return blockTimestamp The timestamp of the observation,
    /// Returns tickCumulative the tick multiplied by seconds elapsed for the life of the pool as of the observation timestamp,
    /// Returns secondsPerLiquidityCumulativeX128 the seconds per in range liquidity for the life of the pool as of the observation timestamp,
    /// Returns initialized whether the observation has been initialized and the values are safe to use
    function observations(uint256 index)
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );
}

/// @title Pool state that is not stored
/// @notice Contains view functions to provide information about the pool that is computed rather than stored on the
/// blockchain. The functions here may have variable gas costs.
interface IUniswapV3PoolDerivedState {
    /// @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
    /// @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
    /// the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
    /// you must call it with secondsAgos = [3600, 0].
    /// @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
    /// log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
    /// @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
    /// @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
    /// @return secondsPerLiquidityCumulativeX128s Cumulative seconds per liquidity-in-range value as of each `secondsAgos` from the current block
    /// timestamp
    function observe(uint32[] calldata secondsAgos)
        external
        view
        returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);

    /// @notice Returns a snapshot of the tick cumulative, seconds per liquidity and seconds inside a tick range
    /// @dev Snapshots must only be compared to other snapshots, taken over a period for which a position existed.
    /// I.e., snapshots cannot be compared if a position is not held for the entire period between when the first
    /// snapshot is taken and the second snapshot is taken.
    /// @param tickLower The lower tick of the range
    /// @param tickUpper The upper tick of the range
    /// @return tickCumulativeInside The snapshot of the tick accumulator for the range
    /// @return secondsPerLiquidityInsideX128 The snapshot of seconds per liquidity for the range
    /// @return secondsInside The snapshot of seconds per liquidity for the range
    function snapshotCumulativesInside(int24 tickLower, int24 tickUpper)
        external
        view
        returns (
            int56 tickCumulativeInside,
            uint160 secondsPerLiquidityInsideX128,
            uint32 secondsInside
        );
}

/// @title Permissionless pool actions
/// @notice Contains pool methods that can be called by anyone
interface IUniswapV3PoolActions {
    /// @notice Sets the initial price for the pool
    /// @dev Price is represented as a sqrt(amountToken1/amountToken0) Q64.96 value
    /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
    function initialize(uint160 sqrtPriceX96) external;

    /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
    /// @dev The caller of this method receives a callback in the form of IUniswapV3MintCallback#uniswapV3MintCallback
    /// in which they must pay any token0 or token1 owed for the liquidity. The amount of token0/token1 due depends
    /// on tickLower, tickUpper, the amount of liquidity, and the current price.
    /// @param recipient The address for which the liquidity will be created
    /// @param tickLower The lower tick of the position in which to add liquidity
    /// @param tickUpper The upper tick of the position in which to add liquidity
    /// @param amount The amount of liquidity to mint
    /// @param data Any data that should be passed through to the callback
    /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
    /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Collects tokens owed to a position
    /// @dev Does not recompute fees earned, which must be done either via mint or burn of any amount of liquidity.
    /// Collect must be called by the position owner. To withdraw only token0 or only token1, amount0Requested or
    /// amount1Requested may be set to zero. To withdraw all tokens owed, caller may pass any value greater than the
    /// actual tokens owed, e.g. type(uint128).max. Tokens owed may be from accumulated swap fees or burned liquidity.
    /// @param recipient The address which should receive the fees collected
    /// @param tickLower The lower tick of the position for which to collect fees
    /// @param tickUpper The upper tick of the position for which to collect fees
    /// @param amount0Requested How much token0 should be withdrawn from the fees owed
    /// @param amount1Requested How much token1 should be withdrawn from the fees owed
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
    /// @dev Can be used to trigger a recalculation of fees owed to a position by calling with an amount of 0
    /// @dev Fees must be collected separately via a call to #collect
    /// @param tickLower The lower tick of the position for which to burn liquidity
    /// @param tickUpper The upper tick of the position for which to burn liquidity
    /// @param amount How much liquidity to burn
    /// @return amount0 The amount of token0 sent to the recipient
    /// @return amount1 The amount of token1 sent to the recipient
    function burn(
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);

    /// @notice Receive token0 and/or token1 and pay it back, plus a fee, in the callback
    /// @dev The caller of this method receives a callback in the form of IUniswapV3FlashCallback#uniswapV3FlashCallback
    /// @dev Can be used to donate underlying tokens pro-rata to currently in-range liquidity providers by calling
    /// with 0 amount{0,1} and sending the donation amount(s) from the callback
    /// @param recipient The address which will receive the token0 and token1 amounts
    /// @param amount0 The amount of token0 to send
    /// @param amount1 The amount of token1 to send
    /// @param data Any data to be passed through to the callback
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;

    /// @notice Increase the maximum number of price and liquidity observations that this pool will store
    /// @dev This method is no-op if the pool already has an observationCardinalityNext greater than or equal to
    /// the input observationCardinalityNext.
    /// @param observationCardinalityNext The desired minimum number of observations for the pool to store
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the factory owner
interface IUniswapV3PoolOwnerActions {
    /// @notice Set the denominator of the protocol's % share of the fees
    /// @param feeProtocol0 new protocol fee for token0 of the pool
    /// @param feeProtocol1 new protocol fee for token1 of the pool
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice Collect the protocol fee accrued to the pool
    /// @param recipient The address to which collected protocol fees should be sent
    /// @param amount0Requested The maximum amount of token0 to send, can be 0 to collect fees in only token1
    /// @param amount1Requested The maximum amount of token1 to send, can be 0 to collect fees in only token0
    /// @return amount0 The protocol fee collected in token0
    /// @return amount1 The protocol fee collected in token1
    function collectProtocol(
        address recipient,
        uint128 amount0Requested,
        uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);
}

/// @title Events emitted by a pool
/// @notice Contains all events emitted by the pool
interface IUniswapV3PoolEvents {
    /// @notice Emitted exactly once by a pool when #initialize is first called on the pool
    /// @dev Mint/Burn/Swap cannot be emitted by the pool before Initialize
    /// @param sqrtPriceX96 The initial sqrt price of the pool, as a Q64.96
    /// @param tick The initial tick of the pool, i.e. log base 1.0001 of the starting price of the pool
    event Initialize(uint160 sqrtPriceX96, int24 tick);

    /// @notice Emitted when liquidity is minted for a given position
    /// @param sender The address that minted the liquidity
    /// @param owner The owner of the position and recipient of any minted liquidity
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity minted to the position range
    /// @param amount0 How much token0 was required for the minted liquidity
    /// @param amount1 How much token1 was required for the minted liquidity
    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted when fees are collected by the owner of a position
    /// @dev Collect events may be emitted with zero amount0 and amount1 when the caller chooses not to collect fees
    /// @param owner The owner of the position for which fees are collected
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount0 The amount of token0 fees collected
    /// @param amount1 The amount of token1 fees collected
    event Collect(
        address indexed owner,
        address recipient,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount0,
        uint128 amount1
    );

    /// @notice Emitted when a position's liquidity is removed
    /// @dev Does not withdraw any fees earned by the liquidity position, which must be withdrawn via #collect
    /// @param owner The owner of the position for which liquidity is removed
    /// @param tickLower The lower tick of the position
    /// @param tickUpper The upper tick of the position
    /// @param amount The amount of liquidity to remove
    /// @param amount0 The amount of token0 withdrawn
    /// @param amount1 The amount of token1 withdrawn
    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Emitted by the pool for any swaps between token0 and token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the output of the swap
    /// @param amount0 The delta of the token0 balance of the pool
    /// @param amount1 The delta of the token1 balance of the pool
    /// @param sqrtPriceX96 The sqrt(price) of the pool after the swap, as a Q64.96
    /// @param liquidity The liquidity of the pool after the swap
    /// @param tick The log base 1.0001 of price of the pool after the swap
    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    /// @notice Emitted by the pool for any flashes of token0/token1
    /// @param sender The address that initiated the swap call, and that received the callback
    /// @param recipient The address that received the tokens from flash
    /// @param amount0 The amount of token0 that was flashed
    /// @param amount1 The amount of token1 that was flashed
    /// @param paid0 The amount of token0 paid for the flash, which can exceed the amount0 plus the fee
    /// @param paid1 The amount of token1 paid for the flash, which can exceed the amount1 plus the fee
    event Flash(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1,
        uint256 paid0,
        uint256 paid1
    );

    /// @notice Emitted by the pool for increases to the number of observations that can be stored
    /// @dev observationCardinalityNext is not the observation cardinality until an observation is written at the index
    /// just before a mint/swap/burn.
    /// @param observationCardinalityNextOld The previous value of the next observation cardinality
    /// @param observationCardinalityNextNew The updated value of the next observation cardinality
    event IncreaseObservationCardinalityNext(
        uint16 observationCardinalityNextOld,
        uint16 observationCardinalityNextNew
    );

    /// @notice Emitted when the protocol fee is changed by the pool
    /// @param feeProtocol0Old The previous value of the token0 protocol fee
    /// @param feeProtocol1Old The previous value of the token1 protocol fee
    /// @param feeProtocol0New The updated value of the token0 protocol fee
    /// @param feeProtocol1New The updated value of the token1 protocol fee
    event SetFeeProtocol(uint8 feeProtocol0Old, uint8 feeProtocol1Old, uint8 feeProtocol0New, uint8 feeProtocol1New);

    /// @notice Emitted when the collected protocol fees are withdrawn by the factory owner
    /// @param sender The address that collects the protocol fees
    /// @param recipient The address that receives the collected protocol fees
    /// @param amount0 The amount of token0 protocol fees that is withdrawn
    /// @param amount0 The amount of token1 protocol fees that is withdrawn
    event CollectProtocol(address indexed sender, address indexed recipient, uint128 amount0, uint128 amount1);
}

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapV3Pool is
    IUniswapV3PoolImmutables,
    IUniswapV3PoolState,
    IUniswapV3PoolDerivedState,
    IUniswapV3PoolActions,
    IUniswapV3PoolOwnerActions,
    IUniswapV3PoolEvents
{

}

/// @title Math library for computing sqrt prices from ticks and vice versa
/// @notice Computes sqrt price for ticks of size 1.0001, i.e. sqrt(1.0001^tick) as fixed point Q64.96 numbers. Supports
/// prices between 2**-128 and 2**128
library TickMath {
    error T();
    error R();

    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// @notice Calculates sqrt(1.0001^tick) * 2^96
    /// @dev Throws if |tick| > max tick
    /// @param tick The input tick for the above formula
    /// @return sqrtPriceX96 A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
    /// at the given tick
    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        unchecked {
            uint256 absTick = tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick));
            if (absTick > uint256(int256(MAX_TICK))) revert T();

            uint256 ratio = absTick & 0x1 != 0
                ? 0xfffcb933bd6fad37aa2d162d1a594001
                : 0x100000000000000000000000000000000;
            if (absTick & 0x2 != 0) ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
            if (absTick & 0x4 != 0) ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
            if (absTick & 0x8 != 0) ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
            if (absTick & 0x10 != 0) ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
            if (absTick & 0x20 != 0) ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
            if (absTick & 0x40 != 0) ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
            if (absTick & 0x80 != 0) ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
            if (absTick & 0x100 != 0) ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
            if (absTick & 0x200 != 0) ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
            if (absTick & 0x400 != 0) ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
            if (absTick & 0x800 != 0) ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
            if (absTick & 0x1000 != 0) ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
            if (absTick & 0x2000 != 0) ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
            if (absTick & 0x4000 != 0) ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
            if (absTick & 0x8000 != 0) ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
            if (absTick & 0x10000 != 0) ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
            if (absTick & 0x20000 != 0) ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
            if (absTick & 0x40000 != 0) ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
            if (absTick & 0x80000 != 0) ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

            if (tick > 0) ratio = type(uint256).max / ratio;

            // this divides by 1<<32 rounding up to go from a Q128.128 to a Q128.96.
            // we then downcast because we know the result always fits within 160 bits due to our tick input constraint
            // we round up in the division so getTickAtSqrtRatio of the output price is always consistent
            sqrtPriceX96 = uint160((ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1));
        }
    }

    /// @notice Calculates the greatest tick value such that getRatioAtTick(tick) <= ratio
    /// @dev Throws in case sqrtPriceX96 < MIN_SQRT_RATIO, as MIN_SQRT_RATIO is the lowest value getRatioAtTick may
    /// ever return.
    /// @param sqrtPriceX96 The sqrt ratio for which to compute the tick as a Q64.96
    /// @return tick The greatest tick for which the ratio is less than or equal to the input ratio
    function getTickAtSqrtRatio(uint160 sqrtPriceX96) internal pure returns (int24 tick) {
        unchecked {
            // second inequality must be < because the price can never reach the price at the max tick
            if (!(sqrtPriceX96 >= MIN_SQRT_RATIO && sqrtPriceX96 < MAX_SQRT_RATIO)) revert R();
            uint256 ratio = uint256(sqrtPriceX96) << 32;

            uint256 r = ratio;
            uint256 msb = 0;

            assembly {
                let f := shl(7, gt(r, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(6, gt(r, 0xFFFFFFFFFFFFFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(5, gt(r, 0xFFFFFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(4, gt(r, 0xFFFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(3, gt(r, 0xFF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(2, gt(r, 0xF))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := shl(1, gt(r, 0x3))
                msb := or(msb, f)
                r := shr(f, r)
            }
            assembly {
                let f := gt(r, 0x1)
                msb := or(msb, f)
            }

            if (msb >= 128) r = ratio >> (msb - 127);
            else r = ratio << (127 - msb);

            int256 log_2 = (int256(msb) - 128) << 64;

            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(63, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(62, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(61, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(60, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(59, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(58, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(57, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(56, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(55, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(54, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(53, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(52, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(51, f))
                r := shr(f, r)
            }
            assembly {
                r := shr(127, mul(r, r))
                let f := shr(128, r)
                log_2 := or(log_2, shl(50, f))
            }

            int256 log_sqrt10001 = log_2 * 255738958999603826347141; // 128.128 number

            int24 tickLow = int24((log_sqrt10001 - 3402992956809132418596140100660247210) >> 128);
            int24 tickHi = int24((log_sqrt10001 + 291339464771989622907027621153398088495) >> 128);

            tick = tickLow == tickHi ? tickLow : getSqrtRatioAtTick(tickHi) <= sqrtPriceX96 ? tickHi : tickLow;
        }
    }
}

/// @title Optimized overflow and underflow safe math operations
/// @notice Contains methods for doing math operations that revert on overflow or underflow for minimal gas cost
library LowGasSafeMath {
    /// @notice Returns x + y, reverts if sum overflows uint256
    /// @param x The augend
    /// @param y The addend
    /// @return z The sum of x and y
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    /// @notice Returns x - y, reverts if underflows
    /// @param x The minuend
    /// @param y The subtrahend
    /// @return z The difference of x and y
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    /// @notice Returns x * y, reverts if overflows
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @return z The product of x and y
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    /// @notice Returns x + y, reverts if overflows or underflows
    /// @param x The augend
    /// @param y The addend
    /// @return z The sum of x and y
    function add(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x + y) >= x == (y >= 0));
    }

    /// @notice Returns x - y, reverts if overflows or underflows
    /// @param x The minuend
    /// @param y The subtrahend
    /// @return z The difference of x and y
    function sub(int256 x, int256 y) internal pure returns (int256 z) {
        require((z = x - y) <= x == (y >= 0));
    }
}

/// @title Safe casting methods
/// @notice Contains methods for safely casting between types
library SafeCast {
    /// @notice Cast a uint256 to a uint160, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint160
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y);
    }

    /// @notice Cast a int256 to a int128, revert on overflow or underflow
    /// @param y The int256 to be downcasted
    /// @return z The downcasted integer, now type int128
    function toInt128(int256 y) internal pure returns (int128 z) {
        require((z = int128(y)) == y);
    }

    /// @notice Cast a uint256 to a int256, revert on overflow
    /// @param y The uint256 to be casted
    /// @return z The casted integer, now type int256
    function toInt256(uint256 y) internal pure returns (int256 z) {
        require(y < 2**255);
        z = int256(y);
    }
}

/// @title Contains 512-bit math functions
/// @notice Facilitates multiplication and division that can have overflow of an intermediate value without any loss of precision
/// @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
library FullMath {
    /// @notice Calculates floor(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = a * b
            // Compute the product mod 2**256 and mod 2**256 - 1
            // then use the Chinese Remainder Theorem to reconstruct
            // the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2**256 + prod0
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division
            if (prod1 == 0) {
                require(denominator > 0);
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }

            // Make sure the result is less than 2**256.
            // Also prevents denominator == 0
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0]
            // Compute remainder using mulmod
            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
            }
            // Subtract 256 bit number from 512 bit number
            assembly {
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator
            // Compute largest power of two divisor of denominator.
            // Always >= 1.
            uint256 twos = (0 - denominator) & denominator;
            // Divide denominator by power of two
            assembly {
                denominator := div(denominator, twos)
            }

            // Divide [prod1 prod0] by the factors of two
            assembly {
                prod0 := div(prod0, twos)
            }
            // Shift in bits from prod1 into prod0. For this we need
            // to flip `twos` such that it is 2**256 / twos.
            // If twos is zero, then it becomes one
            assembly {
                twos := add(div(sub(0, twos), twos), 1)
            }
            prod0 |= prod1 * twos;

            // Invert denominator mod 2**256
            // Now that denominator is an odd number, it has an inverse
            // modulo 2**256 such that denominator * inv = 1 mod 2**256.
            // Compute the inverse by starting with a seed that is correct
            // correct for four bits. That is, denominator * inv = 1 mod 2**4
            uint256 inv = (3 * denominator) ^ 2;
            // Now use Newton-Raphson iteration to improve the precision.
            // Thanks to Hensel's lifting lemma, this also works in modular
            // arithmetic, doubling the correct bits in each step.
            inv *= 2 - denominator * inv; // inverse mod 2**8
            inv *= 2 - denominator * inv; // inverse mod 2**16
            inv *= 2 - denominator * inv; // inverse mod 2**32
            inv *= 2 - denominator * inv; // inverse mod 2**64
            inv *= 2 - denominator * inv; // inverse mod 2**128
            inv *= 2 - denominator * inv; // inverse mod 2**256

            // Because the division is now exact we can divide by multiplying
            // with the modular inverse of denominator. This will give us the
            // correct result modulo 2**256. Since the precoditions guarantee
            // that the outcome is less than 2**256, this is the final result.
            // We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inv;
            return result;
        }
    }

    /// @notice Calculates ceil(a×b÷denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
    /// @param a The multiplicand
    /// @param b The multiplier
    /// @param denominator The divisor
    /// @return result The 256-bit result
    function mulDivRoundingUp(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            result = mulDiv(a, b, denominator);
            if (mulmod(a, b, denominator) > 0) {
                require(result < type(uint256).max);
                result++;
            }
        }
    }
}

/// @title Math functions that do not check inputs or outputs
/// @notice Contains methods that perform common math functions but do not do any overflow or underflow checks
library UnsafeMath {
    /// @notice Returns ceil(x / y)
    /// @dev division by 0 has unspecified behavior, and must be checked externally
    /// @param x The dividend
    /// @param y The divisor
    /// @return z The quotient, ceil(x / y)
    function divRoundingUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := add(div(x, y), gt(mod(x, y), 0))
        }
    }
}

/// @title FixedPoint96
/// @notice A library for handling binary fixed point numbers, see https://en.wikipedia.org/wiki/Q_(number_format)
/// @dev Used in SqrtPriceMath.sol
library FixedPoint96 {
    uint8 internal constant RESOLUTION = 96;
    uint256 internal constant Q96 = 0x1000000000000000000000000;
}

/// @title Functions based on Q64.96 sqrt price and liquidity
/// @notice Contains the math that uses square root of price as a Q64.96 and liquidity to compute deltas
library SqrtPriceMath {
    using LowGasSafeMath for uint256;
    using SafeCast for uint256;

    /// @notice Gets the next sqrt price given a delta of token0
    /// @dev Always rounds up, because in the exact output case (increasing price) we need to move the price at least
    /// far enough to get the desired output amount, and in the exact input case (decreasing price) we need to move the
    /// price less in order to not send too much output.
    /// The most precise formula for this is liquidity * sqrtPX96 / (liquidity +- amount * sqrtPX96),
    /// if this is impossible because of overflow, we calculate liquidity / (liquidity / sqrtPX96 +- amount).
    /// @param sqrtPX96 The starting price, i.e. before accounting for the token0 delta
    /// @param liquidity The amount of usable liquidity
    /// @param amount How much of token0 to add or remove from virtual reserves
    /// @param add Whether to add or remove the amount of token0
    /// @return The price after adding or removing amount, depending on add
    function getNextSqrtPriceFromAmount0RoundingUp(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // we short circuit amount == 0 because the result is otherwise not guaranteed to equal the input price
        if (amount == 0) return sqrtPX96;
        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;

        if (add) {
            uint256 product;
            if ((product = amount * sqrtPX96) / amount == sqrtPX96) {
                uint256 denominator = numerator1 + product;
                if (denominator >= numerator1)
                    // always fits in 160 bits
                    return uint160(FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator));
            }

            return uint160(UnsafeMath.divRoundingUp(numerator1, (numerator1 / sqrtPX96).add(amount)));
        } else {
            uint256 product;
            // if the product overflows, we know the denominator underflows
            // in addition, we must check that the denominator does not underflow
            require((product = amount * sqrtPX96) / amount == sqrtPX96 && numerator1 > product);
            uint256 denominator = numerator1 - product;
            return FullMath.mulDivRoundingUp(numerator1, sqrtPX96, denominator).toUint160();
        }
    }

    /// @notice Gets the next sqrt price given a delta of token1
    /// @dev Always rounds down, because in the exact output case (decreasing price) we need to move the price at least
    /// far enough to get the desired output amount, and in the exact input case (increasing price) we need to move the
    /// price less in order to not send too much output.
    /// The formula we compute is within <1 wei of the lossless version: sqrtPX96 +- amount / liquidity
    /// @param sqrtPX96 The starting price, i.e., before accounting for the token1 delta
    /// @param liquidity The amount of usable liquidity
    /// @param amount How much of token1 to add, or remove, from virtual reserves
    /// @param add Whether to add, or remove, the amount of token1
    /// @return The price after adding or removing `amount`
    function getNextSqrtPriceFromAmount1RoundingDown(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amount,
        bool add
    ) internal pure returns (uint160) {
        // if we're adding (subtracting), rounding down requires rounding the quotient down (up)
        // in both cases, avoid a mulDiv for most inputs
        if (add) {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? (amount << FixedPoint96.RESOLUTION) / liquidity
                        : FullMath.mulDiv(amount, FixedPoint96.Q96, liquidity)
                );

            return uint256(sqrtPX96).add(quotient).toUint160();
        } else {
            uint256 quotient =
                (
                    amount <= type(uint160).max
                        ? UnsafeMath.divRoundingUp(amount << FixedPoint96.RESOLUTION, liquidity)
                        : FullMath.mulDivRoundingUp(amount, FixedPoint96.Q96, liquidity)
                );

            require(sqrtPX96 > quotient);
            // always fits 160 bits
            return uint160(sqrtPX96 - quotient);
        }
    }

    /// @notice Gets the next sqrt price given an input amount of token0 or token1
    /// @dev Throws if price or liquidity are 0, or if the next price is out of bounds
    /// @param sqrtPX96 The starting price, i.e., before accounting for the input amount
    /// @param liquidity The amount of usable liquidity
    /// @param amountIn How much of token0, or token1, is being swapped in
    /// @param zeroForOne Whether the amount in is token0 or token1
    /// @return sqrtQX96 The price after adding the input amount to token0 or token1
    function getNextSqrtPriceFromInput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountIn,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // round to make sure that we don't pass the target price
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountIn, true)
                : getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountIn, true);
    }

    /// @notice Gets the next sqrt price given an output amount of token0 or token1
    /// @dev Throws if price or liquidity are 0 or the next price is out of bounds
    /// @param sqrtPX96 The starting price before accounting for the output amount
    /// @param liquidity The amount of usable liquidity
    /// @param amountOut How much of token0, or token1, is being swapped out
    /// @param zeroForOne Whether the amount out is token0 or token1
    /// @return sqrtQX96 The price after removing the output amount of token0 or token1
    function getNextSqrtPriceFromOutput(
        uint160 sqrtPX96,
        uint128 liquidity,
        uint256 amountOut,
        bool zeroForOne
    ) internal pure returns (uint160 sqrtQX96) {
        require(sqrtPX96 > 0);
        require(liquidity > 0);

        // round to make sure that we pass the target price
        return
            zeroForOne
                ? getNextSqrtPriceFromAmount1RoundingDown(sqrtPX96, liquidity, amountOut, false)
                : getNextSqrtPriceFromAmount0RoundingUp(sqrtPX96, liquidity, amountOut, false);
    }

    /// @notice Gets the amount0 delta between two prices
    /// @dev Calculates liquidity / sqrt(lower) - liquidity / sqrt(upper),
    /// i.e. liquidity * (sqrt(upper) - sqrt(lower)) / (sqrt(upper) * sqrt(lower))
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The amount of usable liquidity
    /// @param roundUp Whether to round the amount up or down
    /// @return amount0 Amount of token0 required to cover a position of size liquidity between the two passed prices
    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount0) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        uint256 numerator1 = uint256(liquidity) << FixedPoint96.RESOLUTION;
        uint256 numerator2 = sqrtRatioBX96 - sqrtRatioAX96;

        require(sqrtRatioAX96 > 0);

        return
            roundUp
                ? UnsafeMath.divRoundingUp(
                    FullMath.mulDivRoundingUp(numerator1, numerator2, sqrtRatioBX96),
                    sqrtRatioAX96
                )
                : FullMath.mulDiv(numerator1, numerator2, sqrtRatioBX96) / sqrtRatioAX96;
    }

    /// @notice Gets the amount1 delta between two prices
    /// @dev Calculates liquidity * (sqrt(upper) - sqrt(lower))
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The amount of usable liquidity
    /// @param roundUp Whether to round the amount up, or down
    /// @return amount1 Amount of token1 required to cover a position of size liquidity between the two passed prices
    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity,
        bool roundUp
    ) internal pure returns (uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return
            roundUp
                ? FullMath.mulDivRoundingUp(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96)
                : FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
    }

    /// @notice Helper that gets signed token0 delta
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The change in liquidity for which to compute the amount0 delta
    /// @return amount0 Amount of token0 corresponding to the passed liquidityDelta between the two prices
    function getAmount0Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 amount0) {
        return
            liquidity < 0
                ? -getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount0Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
    }

    /// @notice Helper that gets signed token1 delta
    /// @param sqrtRatioAX96 A sqrt price
    /// @param sqrtRatioBX96 Another sqrt price
    /// @param liquidity The change in liquidity for which to compute the amount1 delta
    /// @return amount1 Amount of token1 corresponding to the passed liquidityDelta between the two prices
    function getAmount1Delta(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        int128 liquidity
    ) internal pure returns (int256 amount1) {
        return
            liquidity < 0
                ? -getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(-liquidity), false).toInt256()
                : getAmount1Delta(sqrtRatioAX96, sqrtRatioBX96, uint128(liquidity), true).toInt256();
    }
}

/// @title Liquidity amount functions
/// @notice Provides functions for computing liquidity amounts from token amounts and prices
library LiquidityAmounts {
    /// @notice Downcasts uint256 to uint128
    /// @param x The uint258 to be downcasted
    /// @return y The passed value, downcasted to uint128
    function toUint128(uint256 x) private pure returns (uint128 y) {
        require((y = uint128(x)) == x);
    }

    /// @notice Computes the amount of liquidity received for a given amount of token0 and price range
    /// @dev Calculates amount0 * (sqrt(upper) * sqrt(lower)) / (sqrt(upper) - sqrt(lower))
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount0 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount0(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint256 amount0)
        internal
        pure
        returns (uint128 liquidity)
    {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        uint256 intermediate = FullMath.mulDiv(sqrtRatioAX96, sqrtRatioBX96, FixedPoint96.Q96);
        return toUint128(FullMath.mulDiv(amount0, intermediate, sqrtRatioBX96 - sqrtRatioAX96));
    }

    /// @notice Computes the amount of liquidity received for a given amount of token1 and price range
    /// @dev Calculates amount1 / (sqrt(upper) - sqrt(lower)).
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount1 The amount1 being sent in
    /// @return liquidity The amount of returned liquidity
    function getLiquidityForAmount1(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint256 amount1)
        internal
        pure
        returns (uint128 liquidity)
    {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);
        return toUint128(FullMath.mulDiv(amount1, FixedPoint96.Q96, sqrtRatioBX96 - sqrtRatioAX96));
    }

    /// @notice Computes the maximum amount of liquidity received for a given amount of token0, token1, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrtRatioX96 A sqrt price representing the current pool prices
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param amount0 The amount of token0 being sent in
    /// @param amount1 The amount of token1 being sent in
    /// @return liquidity The maximum amount of liquidity received
    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128 liquidity) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            liquidity = getLiquidityForAmount0(sqrtRatioAX96, sqrtRatioBX96, amount0);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            uint128 liquidity0 = getLiquidityForAmount0(sqrtRatioX96, sqrtRatioBX96, amount0);
            uint128 liquidity1 = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioX96, amount1);

            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        } else {
            liquidity = getLiquidityForAmount1(sqrtRatioAX96, sqrtRatioBX96, amount1);
        }
    }

    /// @notice Computes the amount of token0 for a given amount of liquidity and a price range
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount of token0
    function getAmount0ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity)
        internal
        pure
        returns (uint256 amount0)
    {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return FullMath.mulDiv(
            uint256(liquidity) << FixedPoint96.RESOLUTION, sqrtRatioBX96 - sqrtRatioAX96, sqrtRatioBX96
        ) / sqrtRatioAX96;
    }

    /// @notice Computes the amount of token1 for a given amount of liquidity and a price range
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount1 The amount of token1
    function getAmount1ForLiquidity(uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity)
        internal
        pure
        returns (uint256 amount1)
    {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        return FullMath.mulDiv(liquidity, sqrtRatioBX96 - sqrtRatioAX96, FixedPoint96.Q96);
    }

    /// @notice Computes the token0 and token1 value for a given amount of liquidity, the current
    /// pool prices and the prices at the tick boundaries
    /// @param sqrtRatioX96 A sqrt price representing the current pool prices
    /// @param sqrtRatioAX96 A sqrt price representing the first tick boundary
    /// @param sqrtRatioBX96 A sqrt price representing the second tick boundary
    /// @param liquidity The liquidity being valued
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (sqrtRatioAX96 > sqrtRatioBX96) (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            amount0 = getAmount0ForLiquidity(sqrtRatioX96, sqrtRatioBX96, liquidity);
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioX96, liquidity);
        } else {
            amount1 = getAmount1ForLiquidity(sqrtRatioAX96, sqrtRatioBX96, liquidity);
        }
    }
}

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
