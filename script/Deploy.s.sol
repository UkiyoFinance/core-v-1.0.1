//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/src/Script.sol";
import {IWETH9} from "../test/interfaces/IWETH9.sol";
import {Ukiyo} from "../src/Ukiyo.sol";
import {UkiyoTreasury} from "../src/UkiyoTreasury.sol";
import {UkiyoPoolManager} from "../src/UkiyoPoolManager.sol";
import {FeeHandler} from "../src/FeeHandler.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract DeployScript is Script {
    IUniswapV3Factory public factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    UkiyoPoolManager public poolManager;
    FeeHandler public handler;
    UkiyoTreasury public treasury;
    Ukiyo public ukiyo;
    IWETH9 public weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address pool;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ukiyo = new Ukiyo("Ukiyo", "UKY", 18);
        (,, pool) = initializePool();
        handler = new FeeHandler(address(ukiyo));
        poolManager = new UkiyoPoolManager(pool);
        treasury = new UkiyoTreasury(address(ukiyo), address(poolManager), address(handler));
        ukiyo.setTreasuryAndRenounce(address(treasury));
        poolManager.setTreasuryAndHandler(address(treasury), address(handler));
        handler.setTreasuryAndPoolManager(address(treasury), address(poolManager));
        // // Ukiyo ukiyo = new Ukiyo("Ukiyo", "UKY", 18);
        // // address pool = factory.createPool(
        // //     0x6493354EB3f3e3e39ADe2b93BF694f5fa5613Ec6, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 10000
        // // );
        // // IUniswapV3Pool(pool).initialize(2 ** 96);
        // //FeeHandler handler = new FeeHandler(0x6493354EB3f3e3e39ADe2b93BF694f5fa5613Ec6);
        // //UkiyoPoolManager manager = new UkiyoPoolManager(0x695d4cCcB9CCf5e734Ef9c41Cea65522948471B3);
        // // Ukiyo(0x6493354EB3f3e3e39ADe2b93BF694f5fa5613Ec6).approve(0x58121c87A6F1c0b4De2815A86641212c7Ec65585, type(uint256).max);
        // // IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(0x58121c87A6F1c0b4De2815A86641212c7Ec65585, type(uint256).max);
        // // IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).deposit{value: 1e18}();
        // // UkiyoPoolManager(payable(0x58121c87A6F1c0b4De2815A86641212c7Ec65585)).mintNewPosition(1e18, 1e18, -37000, 37000);
        // // Ukiyo(0x6493354EB3f3e3e39ADe2b93BF694f5fa5613Ec6).setTreasuryAndRenounce(0x66C0cF5461B8679c46de37fc7cECf2Bc3729Ac1e);
        // // UkiyoPoolManager(payable(0x58121c87A6F1c0b4De2815A86641212c7Ec65585)).setTreasuryAndHandler(0x66C0cF5461B8679c46de37fc7cECf2Bc3729Ac1e, 0xCa31f400F3CFA3fA0cFcAf3034Fc76ee6301B1FD);
        // // FeeHandler(payable(0xCa31f400F3CFA3fA0cFcAf3034Fc76ee6301B1FD)).setTreasuryAndPoolManager(0x66C0cF5461B8679c46de37fc7cECf2Bc3729Ac1e, 0x58121c87A6F1c0b4De2815A86641212c7Ec65585);
        // // IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).deposit{value: 100}();
        // // IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).transfer(0x58121c87A6F1c0b4De2815A86641212c7Ec65585, 100);
        // uint256 backing = UkiyoTreasury(payable(0x66C0cF5461B8679c46de37fc7cECf2Bc3729Ac1e)).currentBacking();
        vm.stopBroadcast();
    }

    function initializePool() public returns(address, address, address){
        pool = factory.createPool(address(ukiyo), address(weth), 10000);
        IUniswapV3Pool(pool).initialize(2 ** 96);
        return (IUniswapV3Pool(pool).token0(), IUniswapV3Pool(pool).token1(), pool);
    }
}
