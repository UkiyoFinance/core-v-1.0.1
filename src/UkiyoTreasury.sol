//SPDX-License-Identifier: MIT

pragma solidity >=0.8.19;

// Interest Rate Functionality is taken from Frax Finance Variable V2 Interest Rate Model
// Frax Finance Interest Rate Model Github: https://github.com/FraxFinance/fraxlend/blob/main/src/contracts/VariableInterestRate.sol
// Frax Finance Interest Rate Model Documentation: https://docs.frax.finance/fraxlend/advanced-concepts/interest-rates#variable-rate-v2-interest-rate

contract UkiyoTreasury {
    // Utilization Settings
    /// @notice The minimum utilization wherein no adjustment to full utilization and vertex rates occurs
    uint256 public constant MIN_TARGET_UTIL = 75000;
    /// @notice The maximum utilization wherein no adjustment to full utilization and vertex rates occurs
    uint256 public constant MAX_TARGET_UTIL = 85000;
    /// @notice The utilization at which the slope increases
    uint256 public constant VERTEX_UTILIZATION = 80000;
    /// @notice precision of utilization calculations
    uint256 public constant UTIL_PREC = 1e5; // 5 decimals
    // Interest Rate Settings (all rates are per second), 365.24 days per year
    /// @notice The minimum interest rate (per second) when utilization is 100%
    uint256 public constant MIN_FULL_UTIL_RATE = 1582470460; // 18 decimals
    /// @notice The maximum interest rate (per second) when utilization is 100%
    uint256 public constant MAX_FULL_UTIL_RATE = 3164940920000; // 18 decimals
    /// @notice The interest rate (per second) when utilization is 0%
    uint256 public constant ZERO_UTIL_RATE = 158247046; // 18 decimals
    /// @notice The interest rate half life in seconds, determines rate of adjustments to rate curve
    uint256 public constant RATE_HALF_LIFE = 172800; // 1 decimals
    /// @notice The percent of the delta between max and min
    uint256 public constant VERTEX_RATE_PERCENT = 200000000000000000; // 18 decimals
    /// @notice The precision of interest rate calculations
    uint256 public constant RATE_PREC = 1e18; // 18 decimals

    uint16 private constant TEAM_SHARES = 250;
    uint16 private constant LIQUIDITY_SHARES = 1500;
    uint16 private constant TREASURY_SHARES = 8500;
    uint16 private constant PRECISION = 10000;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant FRAX_MINTER = 0xbAFA44EFE7901E04E39Dad13167D089C559c1138;
    address private constant STAKED_FRAX_ETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address public constant TEAM_ADDRESS = 0x667ed630A19fD25fA19145bcdbb06d4D7E24228b;

    address public immutable ukiyo;
    address public immutable poolManager;
    address public immutable owner;
    address public immutable handler;

    uint128 private currentDecay = 1e18;
    uint256 private totalLoansOut;
    CurrentRateInfo public currentRateInfo;
    uint128 private totalDecay;

    Migration private migration;

    mapping(address => Loan) private loans;

    //============================================================\\
    //=================== FUNCTION SIGNATURES ====================\\
    //============================================================\\

    // 0x095ea7b3 approve(address,uint256)
    // 0x4dcd4547 submitAndDeposit(address)
    // 0x2e1a7d4d withdraw(uint256)
    // 0xd0e30db0 deposit()
    // 0x94bf804d mint(uint256,address)
    // 0xfcd3533c burn(uint256,address)
    // 0x558954c9 increaseLiquidityCurrentRange(uint256,uint256) //0x617d6d6e
    // 0x5f6285db liquidityId()
    // 0x18160ddd totalSupply()
    // 0x053d677e ukiyoAmountForLiquidity()
    // 0x70a08231 balanceOf(address)
    // 0x99530b06 pricePerShare()
    // 0x32d7c435 wethInPositions()
    // 0x07a2d13a convertToAssets()
    // 0xc6e6f592 convertToShares(uint256)
    // 0x735d80e3 totalAvailableLiquidity()
    // 0x6f862a6e getInitialLiquidity()
    // 0x99d7b594 decreaseLiquidity(uint256,uint128)
    // 0xa9059cbb transfer(address, uint256)
    // 0x23b872dd transferFrom(address,address,uint256)
    // 0x0d1e3e98 mintAmount(uint256,uint256)

    //============================================================\\
    //==================== ERROR SIGNATURES ======================\\
    //============================================================\\

    // 0xb90cdbb1 NotTreasury()
    // 0xf4560403 Zero()
    // 0x07637bd8 MintFailed()
    // 0x6f16aafc BurnFailed()
    // 0x7939f424 TransferFromFailed()
    // 0x90b8ec18 TransferFailed()
    // 0x917e8a9f OverMaxBorrow()
    // 0xbd2f3ffb WrappingFailed()

    //============================================================\\
    //============================================================\\
    //============================================================\\

    constructor(address _ukiyo, address _poolManager, address _handler) {
        ukiyo = _ukiyo;
        poolManager = _poolManager;
        handler = _handler;
        approvals(_poolManager);
        owner = msg.sender;
    }

    //============================================================\\
    //=================== MINT / BURN FUNCTIONS ==================\\
    //============================================================\\

    ///@notice mint new ukiyo tokens at the current backing price
    ///@return mintedAmount the amount of tokens the user gets from minting
    ///@return managerMintAmount the amount of tokens that go into the LP
    ///@return teamShares tokens from minting that are sent to the team
    function mint() external payable returns (uint256 mintedAmount, uint256 managerMintAmount, uint256 teamShares) {
        uint256 backingPerToken = backing();
        address token = ukiyo;
        address manager = poolManager;

        assembly {
            if iszero(callvalue()) {
                mstore(0, 0xf456040300000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            mintedAmount := div(mul(callvalue(), exp(10, 18)), backingPerToken)
            teamShares := div(mul(mintedAmount, TEAM_SHARES), PRECISION)
            let liquidityShares := div(mul(mintedAmount, LIQUIDITY_SHARES), PRECISION)
            let treasuryShares := div(mul(mintedAmount, TREASURY_SHARES), PRECISION)
            mintedAmount := sub(mintedAmount, teamShares)

            let ptr := mload(0x40)
            mstore(ptr, 0xd0e30db000000000000000000000000000000000000000000000000000000000)
            let success := call(gas(), WETH, liquidityShares, ptr, 4, 0, 0)
            if eq(success, 0) {
                mstore(0, 0xbd2f3ffb00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 4)
            mstore(ptr, 0x5f6285db00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), manager, ptr, 4, add(ptr, 4), 32))

            ptr := add(ptr, 4)
            let id := mload(ptr)

            ptr := add(ptr, 32)
            mstore(ptr, 0x0d1e3e9800000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), id)
            mstore(add(ptr, 36), liquidityShares)
            pop(staticcall(gas(), manager, ptr, 68, add(ptr, 68), 32))

            ptr := add(ptr, 68)
            managerMintAmount := mload(ptr)

            ptr := add(ptr, 32)
            mstore(ptr, 0x94bf804d00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), managerMintAmount)
            mstore(add(ptr, 36), and(manager, 0xffffffffffffffffffffffffffffffffffffffff))
            let result4 := call(gas(), token, 0, ptr, 68, 0, 0)
            if eq(result4, 0) {
                mstore(0, 0x07637bd800000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 68)
            mstore(ptr, 0x617d6d6e00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), id)
            mstore(add(ptr, 36), liquidityShares)
            mstore(add(ptr, 68), managerMintAmount)
            let result5 := call(gas(), manager, 0, ptr, 100, 0, 0)
            if eq(result5, 0) {
                mstore(0, 0x112db0cd00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 100)
            mstore(ptr, 0x4dcd454700000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            let result6 := call(gas(), FRAX_MINTER, treasuryShares, ptr, 36, 0, 0)
            if eq(result6, 0) {
                mstore(0, 0xa437293700000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 36)
            mstore(ptr, 0x94bf804d00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), teamShares)
            mstore(add(ptr, 36), and(TEAM_ADDRESS, 0xffffffffffffffffffffffffffffffffffffffff))
            let result7 := call(gas(), token, 0, ptr, 68, 0, 0)
            if eq(result7, 0) {
                mstore(0, 0x07637bd800000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            mintedAmount := sub(mintedAmount, managerMintAmount)
            ptr := add(ptr, 68)
            mstore(ptr, 0x94bf804d00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), mintedAmount)
            mstore(add(ptr, 36), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
            let result8 := call(gas(), token, 0, ptr, 68, 0, 0)
            if eq(result8, 0) {
                mstore(0, 0x07637bd800000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
        }

        emit Mint(msg.sender, msg.value, mintedAmount, managerMintAmount, teamShares);
    }

    ///@notice burn ukiyo for backing
    ///@param amount the amount of ukiyo to burn
    ///@return wethAmount the amount of weth returned for burning
    ///@return stakedEthAmount the amount of staked eth returned for burning
    function burn(uint256 amount)
        external
        returns (uint256 wethAmount, uint256 stakedEthAmount, uint256 liquidity, uint256 positionSupply)
    {
        uint256 backingPerToken = backing();
        address token = ukiyo;
        address manager = poolManager;
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), STAKED_FRAX_ETH, ptr, 36, add(ptr, 36), 32))

            ptr := add(ptr, 36)
            let stakedTreasuryBalance := add(mload(ptr), sload(totalLoansOut.slot))

            ptr := add(ptr, 32)
            mstore(ptr, 0x18160ddd00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), token, ptr, 4, add(ptr, 4), 32))

            ptr := add(ptr, 4)
            let totalSupply := sub(mload(ptr), exp(10, 18))

            ptr := add(ptr, 32)
            mstore(ptr, 0x053d677e00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), manager, ptr, 4, add(ptr, 4), 32))
            positionSupply := mload(add(ptr, 4))

            let totalBackingOwed := div(mul(backingPerToken, amount), exp(10, 18))
            stakedEthAmount := div(mul(stakedTreasuryBalance, amount), totalSupply)
            let sender := caller()

            ptr := add(ptr, 32)
            mstore(ptr, 0x735d80e300000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), manager, ptr, 4, add(ptr, 4), 32))

            ptr := add(ptr, 4)
            let totalAvailableLiquidity := mload(ptr)

            ptr := add(ptr, 32)
            mstore(ptr, 0x6f862a6e00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), manager, ptr, 4, add(ptr, 4), 32))

            ptr := add(ptr, 4)
            let initialLiquidity := mload(ptr)

            liquidity :=
                div(mul(amount, sub(totalAvailableLiquidity, initialLiquidity)), sub(totalSupply, positionSupply))

            ptr := add(ptr, 32)
            mstore(ptr, 0x5f6285db00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), manager, ptr, 4, add(ptr, 4), 32))

            ptr := add(ptr, 4)
            let tokenId := mload(ptr)

            ptr := add(ptr, 32)
            mstore(ptr, 0x99d7b59400000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), tokenId)
            mstore(add(ptr, 36), liquidity)
            let result := call(gas(), manager, 0, ptr, 68, add(ptr, 68), 64)
            if eq(result, 0) {
                mstore(0, 0x84d43d1c00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            ptr := add(ptr, 68)
            let returnAmount0 := mload(ptr)
            wethAmount := mload(add(ptr, 32))

            ptr := add(ptr, 64)
            mstore(ptr, 0xfcd3533c00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), returnAmount0)
            mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            let result2 := call(gas(), token, 0, ptr, 68, 0, 0)
            if eq(result2, 0) {
                mstore(0, 0x6f16aafc00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 68)
            mstore(ptr, 0xfcd3533c00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), amount)
            mstore(add(ptr, 36), and(sender, 0xffffffffffffffffffffffffffffffffffffffff))
            let result3 := call(gas(), token, 0, ptr, 68, 0, 0)
            if eq(result3, 0) {
                mstore(0, 0x6f16aafc00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 68)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(sender, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), wethAmount)
            let result4 := call(gas(), WETH, 0, ptr, 68, 0, 0)
            if eq(result4, 0) {
                mstore(0, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            ptr := add(ptr, 68)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(sender, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), div(mul(stakedEthAmount, 9750), 10000))
            let result5 := call(gas(), STAKED_FRAX_ETH, 0, ptr, 68, 0, 0)
            if eq(result5, 0) {
                mstore(0, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
        }

        emit BurnedForBacking(msg.sender, wethAmount, stakedEthAmount);
    }

    ///@notice burn built up ukiyo interest from loans
    function burnDecayedUkiyo() external returns (uint256 amountBurned) {
        address token = ukiyo;

        assembly {
            amountBurned := sload(totalDecay.slot)
            sstore(totalDecay.slot, 0x00)
            let ptr := mload(0x40)
            mstore(ptr, 0xfcd3533c00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), amountBurned)
            mstore(add(ptr, 36), address())
            let result := call(gas(), token, 0, ptr, 68, 0, 0)
            if eq(result, 0) {
                mstore(0, 0x6f16aafc00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
        }
        emit BurnedDecay(amountBurned);
    }

    //============================================================\\
    //====================== LOAN FUNCTIONS ======================\\
    //============================================================\\

    struct Loan {
        uint128 collateral;
        uint128 borrowed;
        uint128 startingDecay;
    }

    ///@notice function to allow users to a portion of or all of the their staked eth backing.
    ///@param collateralAmount the amount of collateral you are depositing into the contract
    ///@param desiredBorrowAmount how much you wish to borrow
    function borrow(uint256 collateralAmount, uint256 desiredBorrowAmount) external {
        if (desiredBorrowAmount == 0) revert Zero();
        updateDecay();
        Loan memory loan = updateLoan(loans[msg.sender]);
        address token = ukiyo;
        bytes32 ptr;
        assembly {
            ptr := mload(0x40)
            let totalLoans := sload(totalLoansOut.slot)

            mstore(ptr, 0x18160ddd00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), token, ptr, 4, add(ptr, 4), 32))
            let totalSupply := sub(mload(add(ptr, 4)), exp(10, 18))

            ptr := add(ptr, 36)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), STAKED_FRAX_ETH, ptr, 36, add(ptr, 36), 32))
            let stakedTreasuryBalance := mload(add(ptr, 36))
            ptr := add(ptr, 68)

            let maxBorrowAmount :=
                div(
                    mul(
                        div(mul(add(stakedTreasuryBalance, totalLoans), exp(10, 18)), totalSupply),
                        add(mload(loan), collateralAmount)
                    ),
                    exp(10, 18)
                )
            if gt(add(mload(add(loan, 32)), desiredBorrowAmount), maxBorrowAmount) {
                mstore(0, 0x917e8a9f00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            sstore(totalLoansOut.slot, add(totalLoans, desiredBorrowAmount))

            if gt(collateralAmount, 0) {
                mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
                mstore(add(ptr, 68), collateralAmount)
                let result := call(gas(), token, 0, ptr, 100, 0, 0)
                ptr := add(ptr, 100)
                if eq(result, 0) {
                    mstore(0, 0x7939f42400000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
            }

            mstore(loan, add(collateralAmount, mload(loan)))
            mstore(add(loan, 32), add(mload(add(loan, 32)), desiredBorrowAmount))
            mstore(add(loan, 64), sload(currentDecay.slot))
        }

        loans[msg.sender] = loan;

        assembly {
            // The pointer does not need to be updated again here as it was updated prior to the collateral amount check and within the
            // transferFrom call if that gets called.
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), desiredBorrowAmount)
            let transferResult := call(gas(), STAKED_FRAX_ETH, 0, ptr, 68, 0, 0)
            if eq(transferResult, 0) {
                mstore(0, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
        }

        emit Borrow(msg.sender, collateralAmount, desiredBorrowAmount, loan);
    }

    ///@param amount the amount of staked eth that is being repaid.
    function repay(uint256 amount) external {
        updateDecay();
        Loan memory loan = updateLoan(loans[msg.sender]);
        if (amount > loan.borrowed || amount == 0) revert BorrowedAmount();
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), amount)
            let transferFromCall := call(gas(), STAKED_FRAX_ETH, 0, ptr, 100, 0, 0)
            if eq(transferFromCall, 0) {
                mstore(0, 0x7939f42400000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            mstore(add(loan, 32), sub(mload(add(loan, 32)), amount))
            sstore(totalLoansOut.slot, sub(sload(totalLoansOut.slot), amount))
        }
        loans[msg.sender] = loan;
        emit Repay(msg.sender, amount, loan);
    }

    ///@param amount the amount of collateral tokens the user would like to remove
    function removeCollateral(uint128 amount) external {
        updateDecay();
        Loan memory loan = updateLoan(loans[msg.sender]);
        if (amount > loan.collateral) revert OverCollateralAmount();
        address token = ukiyo;
        bytes32 ptr;
        assembly {
            ptr := mload(0x40)
            let totalLoans := sload(totalLoansOut.slot)

            mstore(ptr, 0x18160ddd00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), token, ptr, 4, add(ptr, 4), 32))
            let totalSupply := sub(mload(add(ptr, 4)), exp(10, 18))

            ptr := add(ptr, 36)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), STAKED_FRAX_ETH, ptr, 36, add(ptr, 36), 32))
            let stakedTreasuryBalance := mload(add(ptr, 36))

            ptr := add(ptr, 68)

            let maxBorrowAmount :=
                div(
                    mul(
                        div(mul(add(stakedTreasuryBalance, totalLoans), exp(10, 18)), totalSupply), sub(mload(loan), amount)
                    ),
                    exp(10, 18)
                )

            if gt(mload(add(loan, 32)), maxBorrowAmount) {
                mstore(0, 0x917e8a9f00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            mstore(loan, sub(mload(loan), amount))
        }

        loans[msg.sender] = loan;

        assembly {
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), amount)
            let transferCall := call(gas(), token, 0, ptr, 68, 0, 0)
            if eq(transferCall, 0) {
                mstore(0, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
        }
        emit CollateralRemoved(msg.sender, loan);
    }

    ///@notice removes all collateral a user has in the contract
    function removeAllCollateral() external {
        updateDecay();
        Loan memory loan = updateLoan(loans[msg.sender]);
        if (loan.borrowed > 0 || loan.collateral == 0) revert MaxCollateralFailed();
        address token = ukiyo;
        uint128 transferAmount = loan.collateral;
        loan.collateral = 0;
        loans[msg.sender] = loan;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), transferAmount)
            let transferCall := call(gas(), token, 0, ptr, 68, 0, 0)
            if eq(transferCall, 0) {
                mstore(0, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
        }
        emit CollateralRemoved(msg.sender, loan);
    }

    ///@notice add collateral for loans
    ///@param amount the amount of collateral the user could like to add.
    function addCollateral(uint128 amount) external {
        updateDecay();
        Loan memory updated = updateLoan(loans[msg.sender]);
        address token = ukiyo;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(caller(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 68), amount)
            let result := call(gas(), token, 0, ptr, 100, 0, 0)
            if eq(result, 0) {
                mstore(0, 0x7939f42400000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            mstore(updated, add(mload(updated), amount))
        }

        loans[msg.sender] = updated;
        emit AddedCollateral(updated);
    }

    function terminateLoan(address user) external returns(bool terminated) {
        updateDecay();
        Loan memory loan = updateLoan(loans[user]);
        if (loan.collateral == 0 && loan.borrowed > 0) {
            totalLoansOut -= loan.borrowed;
            delete loans[user];
            terminated = true;
        } else {
            terminated = false;
        }
    }

    //============================================================\\
    //=================== MIGRATION FUNCTIONS ====================\\
    //============================================================\\

    struct Migration {
        uint256 start;
        uint256 end;
        bool started;
    }

    ///@notice start the two week period prior to any migration can happen
    ///@dev in the event that a migration is necessary it would be impossible to get all of the staked eth out of the treasury simply through burns due to the
    /// burn fee. These functions take the left over amount and transfer them to the new treasury address, after a 2 week timelock.
    function initializeMigration() external {
        if (migration.started == true || msg.sender != owner) revert InvalidCaller();
        migration = Migration({start: block.timestamp, end: block.timestamp + 1209600, started: true});
        emit MigrationStarted(migration);
    }

    ///@notice after the timelock has passed allows the remaining staked eth to be transfered to the new treasury
    ///@param newTreasuryContract the address of the new treasury
    function migrate(address newTreasuryContract) external {
        if (migration.end > block.timestamp || msg.sender != owner) revert Timelock();
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address())
            pop(staticcall(gas(), STAKED_FRAX_ETH, ptr, 36, 0, 32))

            mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), newTreasuryContract)
            mstore(add(ptr, 36), mload(0))
            let transferResult := call(gas(), STAKED_FRAX_ETH, 0, ptr, 68, add(ptr, 68), 32)
            if eq(transferResult, 0) {
                mstore(32, 0x90b8ec1800000000000000000000000000000000000000000000000000000000)
                revert(32, 4)
            }
        }
        emit Migrate(msg.sender, newTreasuryContract);
    }

    //============================================================\\
    //================= EXTERNAL VIEW FUNCTIONS ==================\\
    //============================================================\\

    ///@notice gets the current backing
    ///@dev current backing is also equivilant to the current mint price
    function currentBacking() external view returns (uint256) {
        return backing();
    }

    ///@notice get the loan information for a given user
    ///@param user the user whos loan information you are looking for
    function getLoan(address user) external view returns (Loan memory) {
        return loans[user];
    }

    ///@notice returns the amount of staked eth backing 1 whole token
    function treasuryBacking() external view returns (uint256 _treasuryBacking) {
        address token = ukiyo;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x70a082300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), address())
            pop(staticcall(gas(), STAKED_FRAX_ETH, ptr, 36, add(ptr, 36), 32))
            let treasuryBalance := add(mload(add(ptr, 36)), sload(totalLoansOut.slot))

            ptr := add(ptr, 68)
            mstore(ptr, 0x18160ddd00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), token, ptr, 4, add(ptr, 4), 32))
            let totalSupply := mload(add(ptr, 4))

            _treasuryBacking := div(mul(treasuryBalance, exp(10, 18)), sub(totalSupply, exp(10, 18)))
        }
    }

    ///@notice returns the amount of eth in the LP pool that backs 1 whole token
    function wethBacking() external view returns (uint256 _wethBacking) {
        address token = ukiyo;
        address manager = poolManager;
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x32d7c43500000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), manager, ptr, 4, add(ptr, 4), 32))
            let wethAmount := mload(add(ptr, 4))

            ptr := add(ptr, 36)
            mstore(ptr, 0x18160ddd00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), token, ptr, 4, add(ptr, 4), 32))
            let totalSupply := mload(add(ptr, 4))

            _wethBacking := div(mul(wethAmount, exp(10, 18)), sub(totalSupply, exp(10, 18)))
        }
    }

    ///@notice the total amount of staked eth that is currently being loaned out.
    function activeLoanAmounts() external view returns (uint256) {
        return totalLoansOut;
    }

    ///@notice the current decay
    ///@dev is equivilant to the total amount of interest built up of the life of the contract
    function decay() external view returns (uint128) {
        return currentDecay;
    }

    ///@notice how much built up interest is available to burn
    function decayedUkiyo() external view returns (uint128) {
        return totalDecay;
    }

    ///@notice current interest rate.
    function currentRate() external view returns (uint64) {
        return currentRateInfo.ratePerSec;
    }

    ///@notice view function to help determine the max borrow amount for a given amount of collateral at the current time
    ///@dev this does not check for if it is a loan that can actually take place as it is not used within this contract.
    ///@param amount the amount of collateral put down
    function maxBorrow(uint256 amount) external view returns (uint256 max) {
        address token = ukiyo;
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), STAKED_FRAX_ETH, ptr, 36, add(ptr, 36), 32))
            ptr := add(ptr, 36)
            let stakedEth := add(sload(totalLoansOut.slot), mload(ptr))
            ptr := add(ptr, 32)

            mstore(ptr, 0x18160ddd00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), token, ptr, 4, add(ptr, 4), 32))
            ptr := add(ptr, 4)
            let totalSupply := sub(mload(ptr), exp(10, 18))

            max := div(mul(div(mul(stakedEth, exp(10, 18)), totalSupply), amount), exp(10, 18))
        }
    }

    //============================================================\\
    //================= INTERNAL VIEW FUNCTIONS ==================\\
    //============================================================\\

    ///@notice calculates the current backing per token.
    ///@dev also used for the mint price
    function backing() internal view returns (uint256 backingPer) {
        address token = ukiyo;
        address manager = poolManager;

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x18160ddd00000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), token, ptr, 4, add(ptr, 4), 32))
            ptr := add(ptr, 4)
            let totalSupply := sub(mload(ptr), exp(10, 18))

            ptr := add(ptr, 32)
            mstore(ptr, 0x32d7c43500000000000000000000000000000000000000000000000000000000)
            pop(staticcall(gas(), manager, ptr, 4, add(ptr, 4), 32))
            ptr := add(ptr, 4)
            let weth := mload(ptr)

            ptr := add(ptr, 32)
            mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
            pop(staticcall(gas(), STAKED_FRAX_ETH, ptr, 36, add(ptr, 36), 32))
            ptr := add(ptr, 36)
            let stakedEth := add(sload(totalLoansOut.slot), mload(ptr))

            ptr := add(ptr, 32)
            mstore(ptr, 0x07a2d13a00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), stakedEth)
            pop(staticcall(gas(), STAKED_FRAX_ETH, ptr, 36, add(ptr, 36), 32))
            ptr := add(ptr, 36)
            let convertedStaked := mload(ptr)

            backingPer := div(mul(add(convertedStaked, weth), exp(10, 18)), totalSupply)
            if eq(backingPer, 0) { backingPer := exp(10, 18) }
        }
    }

    //============================================================\\
    //=================== INTERNAL FUNCTIONS =====================\\
    //============================================================\\

    ///@notice called in the constructor to max approve the pool contract.
    function approvals(address _manager) internal {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), and(_manager, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(add(ptr, 36), 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE)
            let result := call(gas(), WETH, 0, ptr, 68, 0, 0)
        }
    }

    ///@notice internal function to help make sure users who have collateral deposited but are not borrowing at not charged interest.
    ///@dev state gets updated from the functions that call this.
    ///@param loan current loan state
    ///@return updatedLoan the updated loan state if necessary.
    function updateLoan(Loan memory loan) internal returns (Loan memory updatedLoan) {
        assembly {
            if gt(mload(add(loan, 32)), 0) {
                let current := sload(currentDecay.slot)
                let newCollateral := div(mul(mload(loan), mload(add(loan, 64))), current)
                sstore(totalDecay.slot, add(sload(totalDecay.slot), sub(mload(loan), newCollateral)))
                mstore(loan, newCollateral)
                mstore(add(loan, 64), current)
                updatedLoan := loan
            }
        }
        if (loan.borrowed == 0) updatedLoan = loan;
        emit UpdateLoan(updatedLoan);
    }

    //============================================================\\
    //================= INTEREST RATE FUNCTIONS ==================\\
    //============================================================\\

    struct CurrentRateInfo {
        uint32 lastBlock;
        uint64 lastTimestamp;
        uint64 ratePerSec;
        uint64 fullUtilizationRate;
    }

    ///@notice update the current decay rate and interst earned
    function updateDecay()
        internal
        returns (bool isInterestUpdated, uint256 interestEarned, CurrentRateInfo memory rateInfo)
    {
        rateInfo = currentRateInfo;
        InterestCalculationResults memory result = calculateInterest(rateInfo);

        if (result.isInterestUpdated) {
            isInterestUpdated = result.isInterestUpdated;
            interestEarned = result.interestEarned;

            emit UpdateRate(
                rateInfo.ratePerSec, rateInfo.fullUtilizationRate, result.newRate, result.newFullUtilizationRate
            );
            emit AddInterest(interestEarned, result.newRate);

            rateInfo.ratePerSec = result.newRate;
            rateInfo.fullUtilizationRate = result.newFullUtilizationRate;
            rateInfo.lastTimestamp = uint64(block.timestamp);
            rateInfo.lastBlock = uint32(block.number);

            currentRateInfo = rateInfo;
        }
    }

    struct InterestCalculationResults {
        bool isInterestUpdated;
        uint64 newRate;
        uint64 newFullUtilizationRate;
        uint256 interestEarned;
    }

    function calculateInterest(CurrentRateInfo memory rateInfo) internal returns (InterestCalculationResults memory) {
        uint256 deltaTime;
        uint256 loansOut = totalLoansOut;
        uint256 utilizationRate;
        InterestCalculationResults memory results;
        assembly {
            if eq(eq(mload(add(rateInfo, 32)), timestamp()), 0) {
                let ptr := mload(0x40)
                mstore(ptr, 0x70a0823100000000000000000000000000000000000000000000000000000000)
                mstore(add(ptr, 4), and(address(), 0xffffffffffffffffffffffffffffffffffffffff))
                pop(staticcall(gas(), STAKED_FRAX_ETH, ptr, 36, add(ptr, 36), 32))
                let currentBalance := mload(add(ptr, 36))
                ptr := add(ptr, 32)

                mstore(results, true)
                deltaTime := sub(timestamp(), mload(add(rateInfo, 32)))
                utilizationRate := div(mul(UTIL_PREC, loansOut), add(currentBalance, loansOut))
            }
        }

        (results.newRate, results.newFullUtilizationRate) =
            getNewRate(deltaTime, utilizationRate, rateInfo.fullUtilizationRate);

        assembly {
            let interestEarned := div(mul(mul(deltaTime, loansOut), mload(add(results, 32))), RATE_PREC)

            mstore(add(results, 96), interestEarned)
            if gt(interestEarned, 0) { sstore(currentDecay.slot, add(sload(currentDecay.slot), interestEarned)) }
        }

        return results;
    }

    function getFullUtilizationInterest(uint256 deltaTime, uint256 utilization, uint64 fullUtilizationInterest)
        internal
        pure
        returns (uint64 newFullUtilizationInterest)
    {
        if (utilization < MIN_TARGET_UTIL) {
            uint256 deltaUtilization = ((MIN_TARGET_UTIL - utilization) * 1e18) / MIN_TARGET_UTIL;
            uint256 decayGrowth = (RATE_HALF_LIFE * 1e36) + (deltaUtilization * deltaUtilization * deltaTime);
            newFullUtilizationInterest = uint64((fullUtilizationInterest * (RATE_HALF_LIFE * 1e36)) / decayGrowth);
        } else if (utilization > MAX_TARGET_UTIL) {
            // 18 decimals
            uint256 deltaUtilization = ((utilization - MAX_TARGET_UTIL) * 1e18) / (UTIL_PREC - MAX_TARGET_UTIL);
            // 36 decimals
            uint256 decayGrowth = (RATE_HALF_LIFE * 1e36) + (deltaUtilization * deltaUtilization * deltaTime);
            // 18 decimals
            newFullUtilizationInterest = uint64((fullUtilizationInterest * decayGrowth) / (RATE_HALF_LIFE * 1e36));
        } else {
            newFullUtilizationInterest = fullUtilizationInterest;
        }
        if (newFullUtilizationInterest > MAX_FULL_UTIL_RATE) {
            newFullUtilizationInterest = uint64(MAX_FULL_UTIL_RATE);
        } else if (newFullUtilizationInterest < MIN_FULL_UTIL_RATE) {
            newFullUtilizationInterest = uint64(MIN_FULL_UTIL_RATE);
        }
    }

    function getNewRate(uint256 deltaTime, uint256 utilization, uint64 oldFullUtilizationInterest)
        internal
        pure
        returns (uint64 newRatePerSec, uint64 newFullUtilizationInterest)
    {
        newFullUtilizationInterest = getFullUtilizationInterest(deltaTime, utilization, oldFullUtilizationInterest);
        // _vertexInterest is calculated as the percentage of the delta between min and max interest
        uint256 vertexInterest =
            (((newFullUtilizationInterest - ZERO_UTIL_RATE) * VERTEX_RATE_PERCENT) / RATE_PREC) + ZERO_UTIL_RATE;
        if (utilization < VERTEX_UTILIZATION) {
            // For readability, the following formula is equivalent to:
            // uint256 _slope = ((_vertexInterest - ZERO_UTIL_RATE) * UTIL_PREC) / VERTEX_UTILIZATION;
            // _newRatePerSec = uint64(ZERO_UTIL_RATE + ((_utilization * _slope) / UTIL_PREC));

            // 18 decimals
            newRatePerSec =
                uint64(ZERO_UTIL_RATE + (utilization * (vertexInterest - ZERO_UTIL_RATE)) / VERTEX_UTILIZATION);
        } else {
            // For readability, the following formula is equivalent to:
            // uint256 _slope = (((_newFullUtilizationInterest - _vertexInterest) * UTIL_PREC) / (UTIL_PREC - VERTEX_UTILIZATION));
            // _newRatePerSec = uint64(_vertexInterest + (((_utilization - VERTEX_UTILIZATION) * _slope) / UTIL_PREC));

            // 18 decimals
            newRatePerSec = uint64(
                vertexInterest
                    + ((utilization - VERTEX_UTILIZATION) * (newFullUtilizationInterest - vertexInterest))
                        / (UTIL_PREC - VERTEX_UTILIZATION)
            );
        }
        newFullUtilizationInterest = getFullUtilizationInterest(deltaTime, utilization, oldFullUtilizationInterest);
    }

    //============================================================\\
    //================= LIQUIDITY POOL FUNCTIONS =================\\
    //============================================================\\

    ///@notice callback function called by the pool manager to burn tokens from when removing liquidity
    function liquidityBurnCallback(uint256 amount) external {
        address manager = poolManager;
        address token = ukiyo;
        assembly {
            let ptr := mload(0x40)
            if eq(
                eq(
                    and(manager, 0xffffffffffffffffffffffffffffffffffffffff),
                    and(caller(), 0xffffffffffffffffffffffffffffffffffffffff)
                ),
                0
            ) {
                mstore(0, 0xb90cdbb100000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            mstore(ptr, 0xfcd3533c00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), amount)
            mstore(add(ptr, 36), and(manager, 0xffffffffffffffffffffffffffffffffffffffff))
            let result := call(gas(), token, 0, ptr, 100, 0, 0)
            if eq(result, 0) {
                mstore(4, 0x6f16aafc00000000000000000000000000000000000000000000000000000000)
                revert(4, 4)
            }
        }
        emit BurnCallback(amount);
    }

    ///@notice burns ukiyo from fees earned by the protocol liquidity position
    ///@param amount the amount of ukiyo to burn
    function burnFees(uint256 amount) external {
        address token = ukiyo;
        address feeHandler = handler;
        assembly {
            if eq(
                eq(
                    and(feeHandler, 0xffffffffffffffffffffffffffffffffffffffff),
                    and(caller(), 0xffffffffffffffffffffffffffffffffffffffff)
                ),
                0
            ) {
                mstore(0, 0x8d21578200000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
            let ptr := mload(0x40)
            mstore(ptr, 0xfcd3533c00000000000000000000000000000000000000000000000000000000)
            mstore(add(ptr, 4), amount)
            mstore(add(ptr, 36), and(feeHandler, 0xffffffffffffffffffffffffffffffffffffffff))
            let result := call(gas(), token, 0, ptr, 100, 0, 0)
            if eq(result, 0) {
                mstore(0, 0x6f16aafc00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }
        }
        emit FeesBurned(msg.sender, amount);
    }

    //============================================================\\
    //==================== ERRORS AND EVENTS =====================\\
    //============================================================\\

    error LoanAlreadyCreated();
    error Zero();
    error OverMaxBorrow();
    error InvalidCaller();
    error Timelock();
    error BorrowedAmount();
    error OverCollateralAmount();
    error MaxCollateralFailed();

    event AddInterest(uint256 interestEarned, uint64 newRate);
    event AddedCollateral(Loan updated);
    event Borrow(address indexed borrowed, uint256 collateralAdded, uint256 amountBorrowed, Loan loanInfo);
    event BurnCallback(uint256 amountBurned);
    event BurnedDecay(uint256 amountBurned);
    event CollateralRemoved(address indexed caller, Loan updatedLoanInfo);
    event BurnedForBacking(address indexed caller, uint256 wethAmount, uint256 stakedEthAmount);
    event FeesBurned(address indexed caller, uint256 burnedAmount);
    event Migrate(address indexed caller, address newTreasury);
    event MigrationStarted(Migration migration);
    event Mint(
        address indexed caller, uint256 depositAmount, uint256 userAmount, uint256 liquidityAmount, uint256 teamShares
    );
    event MintWeth(
        address indexed caller, uint256 depositAmount, uint256 userAmount, uint256 liquidityAmount, uint256 teamShares
    );
    event Repay(address indexed caller, uint256 repaymentAmount, Loan updatedLoan);
    event UpdateLoan(Loan updatedLoan);
    event UpdateRate(uint64 ratePerSec, uint64 fullUtilizationRate, uint64 newRate, uint64 newFullUtilizationRate);

    receive() external payable {}
}
