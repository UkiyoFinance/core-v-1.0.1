//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/src/Script.sol";
import {Ukiyo} from "../src/Ukiyo.sol";
import {UkiyoTreasury} from "../src/UkiyoTreasury.sol";
import {UkiyoPoolManager} from "../src/UkiyoPoolManager.sol";
import {FeeHandler} from "../src/FeeHandler.sol";
import {IUniswapV3Factory} from "v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract DeployScript is Script {
    IUniswapV3Factory public factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // Ukiyo ukiyo = new Ukiyo("Ukiyo", "UKY", 18);
        // address pool = factory.createPool(
        //     0x6493354EB3f3e3e39ADe2b93BF694f5fa5613Ec6, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 10000
        // );
        // IUniswapV3Pool(pool).initialize(2 ** 96);
        FeeHandler handler = new FeeHandler(0x6493354EB3f3e3e39ADe2b93BF694f5fa5613Ec6);
        vm.stopBroadcast();
    }
}
