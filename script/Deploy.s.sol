// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console} from "forge-std/Script.sol";
import {SoulBadge, BadgeStorage} from "../src/SoulBadge.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public returns (SoulBadge soulBadge, BadgeStorage badgeStorage) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy BadgeStorage first
        badgeStorage = new BadgeStorage();
        console.log("BadgeStorage deployed at:", address(badgeStorage));

        // Deploy SoulBadge with BadgeStorage address
        soulBadge = new SoulBadge(address(badgeStorage));
        console.log("SoulBadge deployed at:", address(soulBadge));

        vm.stopBroadcast();

        return (soulBadge, badgeStorage);
    }
}

contract DeployLocalScript is Script {
    function setUp() public {}

    function run() public returns (SoulBadge soulBadge, BadgeStorage badgeStorage) {
        vm.startBroadcast();

        // Deploy BadgeStorage first
        badgeStorage = new BadgeStorage();
        console.log("BadgeStorage deployed at:", address(badgeStorage));

        // Deploy SoulBadge with BadgeStorage address
        soulBadge = new SoulBadge(address(badgeStorage));
        console.log("SoulBadge deployed at:", address(soulBadge));

        vm.stopBroadcast();

        return (soulBadge, badgeStorage);
    }
}
