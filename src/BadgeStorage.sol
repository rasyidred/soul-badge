// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;
/**
 * @title BadgeStorage
 * Temporary storage before giving to audience
 */

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BadgeStorage is ReentrancyGuard {
    uint256 private itemIds;
    uint256 private itemsRedeemed;

    address payable owner;

    constructor() {
        owner = payable(msg.sender);
    }

    struct StorageItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address payable creator; //NFT creator
        address payable owner; //owner after it's being transfered
        bool claim;
    }

    mapping(uint256 => StorageItem) private idToStorageItem;

    event ItemStored(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address creator,
        address owner,
        bool claim
    );

    /* Stores an NFT on the storage before distributed */
    // create market item
    function storeItem(address nftContract, uint256 tokenId) public payable nonReentrant {
        uint256 itemId = ++itemIds;
        require(idToStorageItem[itemId].claim == false, "You can't store a redeemed token!");
        idToStorageItem[itemId] =
            StorageItem(itemId, nftContract, tokenId, payable(msg.sender), payable(address(0)), false);
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit ItemStored(itemId, nftContract, tokenId, msg.sender, address(0), false);
    }

    /* Transfers the NFT's ownership to attendee (msg.sender)*/
    // buy nft
    function claimItem(address nftContract, uint256 itemId) public payable nonReentrant {
        uint256 tokenId = idToStorageItem[itemId].tokenId;

        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToStorageItem[itemId].owner = payable(msg.sender);
        idToStorageItem[itemId].claim = true;

        ++itemsRedeemed;
    }

    /*Returns all NFTs which has not been claimed*/
    function fetchStorageItems() public view returns (StorageItem[] memory items) {
        uint256 itemCount = itemIds;
        uint256 notRedeemedItemCount = itemIds - itemsRedeemed;
        uint256 currentIndex = 0;

        StorageItem[] memory items = new StorageItem[](notRedeemedItemCount);

        for (uint256 i = 0; i < itemCount; i++) {
            if (idToStorageItem[i + 1].owner == address(0)) {
                uint256 currentId = 1 + i;
                StorageItem storage currentItem = idToStorageItem[currentId];

                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /*Returns all NFTs which has been redeemed*/
    function fetchMyNFTs() public view returns (StorageItem[] memory items) {
        uint256 totalItemCount = itemIds;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToStorageItem[i + 1].owner == msg.sender) {
                itemCount = i + 1;
            }
        }

        StorageItem[] memory items = new StorageItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToStorageItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                StorageItem storage currentItem = idToStorageItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // returns only NFTs the creator has created
    function fetchItemsCreated() public view returns (StorageItem[] memory items) {
        uint256 totalItemCount = itemIds;
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToStorageItem[i + 1].creator == msg.sender) {
                itemCount += 1;
            }
        }

        StorageItem[] memory items = new StorageItem[](itemCount);

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToStorageItem[i + 1].creator == msg.sender) {
                uint256 currentId = i + 1;
                StorageItem storage currentItem = idToStorageItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
