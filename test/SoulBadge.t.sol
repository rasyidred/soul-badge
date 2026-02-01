// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {SoulBadge, BadgeStorage} from "../src/SoulBadge.sol";

contract SoulBadgeTest is Test {
    SoulBadge public soulBadge;
    BadgeStorage public badgeStorage;

    address public owner;
    address public attendee1 = makeAddr("attendee1");
    address public attendee2 = makeAddr("attendee2");

    string constant TOKEN_URI = "ipfs://QmTestTokenURI";

    function setUp() public {
        owner = makeAddr("owner");
        vm.startPrank(owner);
        badgeStorage = new BadgeStorage();
        soulBadge = new SoulBadge(address(badgeStorage));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deployment() public view {
        assertEq(soulBadge.name(), "SoulBadge");
        assertEq(soulBadge.symbol(), "SBT");
        assertEq(soulBadge.contractOwner(), owner);
        assertEq(soulBadge.storageAddress(), address(badgeStorage));
    }

    /*//////////////////////////////////////////////////////////////
                            MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MintNFTs() public {
        uint256 numAttendees = 5;

        vm.prank(owner);
        bytes32 nullifier = soulBadge.mintNFTs(numAttendees, TOKEN_URI);

        // Check nullifier is not zero
        assertTrue(nullifier != bytes32(0));

        // Check tokens were minted to owner
        for (uint256 i = 1; i <= numAttendees; i++) {
            assertEq(soulBadge.ownerOf(i), owner);
            assertEq(soulBadge.tokenURI(i), TOKEN_URI);
        }
    }

    function test_MintNFTs_OnlyOwner() public {
        vm.prank(attendee1);
        vm.expectRevert();
        soulBadge.mintNFTs(5, TOKEN_URI);
    }

    function test_MintNFTs_MultipleBatches() public {
        vm.startPrank(owner);
        bytes32 nullifier1 = soulBadge.mintNFTs(3, TOKEN_URI);
        bytes32 nullifier2 = soulBadge.mintNFTs(2, "ipfs://QmSecondBatch");
        vm.stopPrank();

        // Nullifiers should be different
        assertTrue(nullifier1 != nullifier2);

        // Check all 5 tokens exist
        assertEq(soulBadge.ownerOf(1), owner);
        assertEq(soulBadge.ownerOf(5), owner);
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Claim() public {
        vm.prank(owner);
        bytes32 nullifier = soulBadge.mintNFTs(3, TOKEN_URI);

        (uint256 tokenId, uint256 remaining) = soulBadge.claim(nullifier, attendee1);

        assertEq(tokenId, 1);
        assertEq(remaining, 3); // remaining is calculated before claim is recorded
    }

    function test_Claim_PreventDoubleClaim() public {
        vm.prank(owner);
        bytes32 nullifier = soulBadge.mintNFTs(3, TOKEN_URI);

        soulBadge.claim(nullifier, attendee1);

        vm.expectRevert("Recipient already claimed the Token");
        soulBadge.claim(nullifier, attendee1);
    }

    function test_Claim_MaxClaimsReached() public {
        vm.prank(owner);
        bytes32 nullifier = soulBadge.mintNFTs(2, TOKEN_URI);

        soulBadge.claim(nullifier, attendee1);
        soulBadge.claim(nullifier, attendee2);

        address attendee3 = makeAddr("attendee3");
        vm.expectRevert("The maximum claims reached!");
        soulBadge.claim(nullifier, attendee3);
    }

    function test_Claim_InvalidNullifier() public {
        bytes32 fakeNullifier = keccak256("fake");

        vm.expectRevert("The code is not valid nor exist");
        soulBadge.claim(fakeNullifier, attendee1);
    }

    /*//////////////////////////////////////////////////////////////
                            SOULBOUND TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Soulbound_CannotTransfer() public {
        vm.prank(owner);
        soulBadge.mintNFTs(1, TOKEN_URI);

        // Transfer to storage is allowed
        vm.prank(owner);
        soulBadge.transferFrom(owner, address(badgeStorage), 1);
        assertEq(soulBadge.ownerOf(1), address(badgeStorage));

        // Transfer from storage to attendee is allowed
        vm.prank(address(badgeStorage));
        soulBadge.transferFrom(address(badgeStorage), attendee1, 1);
        assertEq(soulBadge.ownerOf(1), attendee1);

        // Transfer between users is NOT allowed (soulbound)
        vm.prank(attendee1);
        vm.expectRevert("Err: token is SOUL BOUND");
        soulBadge.transferFrom(attendee1, attendee2, 1);
    }

    function test_Soulbound_CanBurn() public {
        vm.prank(owner);
        soulBadge.mintNFTs(1, TOKEN_URI);

        // Owner can burn
        vm.prank(owner);
        soulBadge.burn(1);

        vm.expectRevert();
        soulBadge.ownerOf(1);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetClaimer() public {
        vm.prank(owner);
        bytes32 nullifier = soulBadge.mintNFTs(2, TOKEN_URI);

        soulBadge.claim(nullifier, attendee1);
        soulBadge.claim(nullifier, attendee2);

        (address[] memory addresses, uint256[] memory tokenIds, bool[] memory claimed) = soulBadge.getClaimer(nullifier);

        assertEq(addresses[0], attendee1);
        assertEq(addresses[1], attendee2);
        assertEq(tokenIds[0], 1);
        assertEq(tokenIds[1], 2);
        assertTrue(claimed[0]);
        assertTrue(claimed[1]);
    }
}

contract BadgeStorageTest is Test {
    SoulBadge public soulBadge;
    BadgeStorage public badgeStorage;

    address public owner;
    address public attendee1 = makeAddr("attendee1");
    address public attendee2 = makeAddr("attendee2");

    string constant TOKEN_URI = "ipfs://QmTestTokenURI";

    function setUp() public {
        owner = makeAddr("owner");
        vm.startPrank(owner);
        badgeStorage = new BadgeStorage();
        soulBadge = new SoulBadge(address(badgeStorage));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            STORE ITEM TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StoreItem() public {
        vm.startPrank(owner);
        soulBadge.mintNFTs(1, TOKEN_URI);

        // Approve and store
        soulBadge.approve(address(badgeStorage), 1);
        badgeStorage.storeItem(address(soulBadge), 1);
        vm.stopPrank();

        assertEq(soulBadge.ownerOf(1), address(badgeStorage));
    }

    function test_StoreItem_OnlyOwner() public {
        vm.prank(owner);
        soulBadge.mintNFTs(1, TOKEN_URI);

        vm.prank(attendee1);
        vm.expectRevert();
        badgeStorage.storeItem(address(soulBadge), 1);
    }

    /*//////////////////////////////////////////////////////////////
                            CLAIM BADGE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ClaimBadge() public {
        vm.startPrank(owner);
        bytes32 nullifier = soulBadge.mintNFTs(2, TOKEN_URI);

        // Store tokens
        soulBadge.approve(address(badgeStorage), 1);
        soulBadge.approve(address(badgeStorage), 2);
        badgeStorage.storeItem(address(soulBadge), 1);
        badgeStorage.storeItem(address(soulBadge), 2);
        vm.stopPrank();

        // Attendee claims
        vm.prank(attendee1);
        badgeStorage.claimBadge(address(soulBadge), nullifier);

        assertEq(soulBadge.ownerOf(1), attendee1);
    }

    function test_ClaimBadge_OwnerCannotClaim() public {
        vm.startPrank(owner);
        bytes32 nullifier = soulBadge.mintNFTs(1, TOKEN_URI);

        soulBadge.approve(address(badgeStorage), 1);
        badgeStorage.storeItem(address(soulBadge), 1);

        // Owner tries to claim - should fail
        vm.expectRevert("Only attendees that can claim!");
        badgeStorage.claimBadge(address(soulBadge), nullifier);
        vm.stopPrank();
    }

    function test_ClaimBadge_MultipleAttendees() public {
        vm.startPrank(owner);
        bytes32 nullifier = soulBadge.mintNFTs(3, TOKEN_URI);

        // Store all tokens
        for (uint256 i = 1; i <= 3; i++) {
            soulBadge.approve(address(badgeStorage), i);
            badgeStorage.storeItem(address(soulBadge), i);
        }
        vm.stopPrank();

        // Multiple attendees claim
        vm.prank(attendee1);
        badgeStorage.claimBadge(address(soulBadge), nullifier);

        vm.prank(attendee2);
        badgeStorage.claimBadge(address(soulBadge), nullifier);

        assertEq(soulBadge.ownerOf(1), attendee1);
        assertEq(soulBadge.ownerOf(2), attendee2);
    }

    /*//////////////////////////////////////////////////////////////
                            EVENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EmitBadgeClaimed() public {
        vm.startPrank(owner);
        bytes32 nullifier = soulBadge.mintNFTs(2, TOKEN_URI);

        soulBadge.approve(address(badgeStorage), 1);
        soulBadge.approve(address(badgeStorage), 2);
        badgeStorage.storeItem(address(soulBadge), 1);
        badgeStorage.storeItem(address(soulBadge), 2);
        vm.stopPrank();

        vm.prank(attendee1);
        vm.expectEmit(true, true, true, true);
        emit BadgeStorage.badgeClaimed(attendee1, 1, 2); // remaining calculated before claim
        badgeStorage.claimBadge(address(soulBadge), nullifier);
    }
}
