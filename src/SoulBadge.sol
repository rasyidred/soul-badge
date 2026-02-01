// SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SoulBagde
 * Non-tranferrable digital badge using Soulbound Token
 */

contract SoulBadge is
    ERC721URIStorage,
    Ownable,
    ReentrancyGuard,
    ERC721Burnable
{
    uint256 private _tokenIdCounter;

    address public contractOwner;
    address public storageAddress;

    modifier checkValid(bytes32 nullifier) {
        require(
            eventDetails[nullifier].isExist == true,
            "The code is not valid nor exist"
        );
        _;
    }

    constructor(address _storageAddress) ERC721("SoulBadge", "SBT") Ownable(msg.sender) {
        contractOwner = msg.sender;
        storageAddress = _storageAddress;
    }

    event eventCreated(uint maxAttendees, string eventInfo, bytes32 nullifier);

    struct Claimer {
        address attendee;
        uint tokenId;
        bool claimed;
    }

    struct Details {
        uint maxAttendees;
        uint counterClaimed;
        uint startingTokenId;
        uint endingTokenId;
        string URI;
        bool isExist;
        mapping(address => Claimer) attendeeDetails;
        Claimer[] claimers;
    }

    mapping(bytes32 nullifier => Details) public eventDetails;

    function mintNFTs(
        uint _noOfAttendees,
        string memory _tokenURI
    ) public onlyOwner nonReentrant returns (bytes32 nullifier) {
        nullifier = keccak256(
            abi.encodePacked(block.timestamp, _noOfAttendees, _tokenURI)
        );
        uint startingTokenId;
        if (_tokenIdCounter == 0) {
            startingTokenId = 1;
        } else {
            startingTokenId = _tokenIdCounter;
        }

        uint endingTokenId = startingTokenId + _noOfAttendees;

        eventDetails[nullifier].maxAttendees = _noOfAttendees;
        eventDetails[nullifier].startingTokenId = startingTokenId;
        eventDetails[nullifier].endingTokenId = endingTokenId;
        eventDetails[nullifier].URI = _tokenURI;
        eventDetails[nullifier].isExist = true;

        for (uint i = 0; i < _noOfAttendees; i++) {
            uint tokenId = ++_tokenIdCounter;

            _safeMint(contractOwner, tokenId);
            _setTokenURI(tokenId, _tokenURI);
            setApprovalForAll(storageAddress, true);
        }

        emit eventCreated(_noOfAttendees, _tokenURI, nullifier);
        return nullifier;
    }

    function claim(
        bytes32 _nullifier,
        address _to
    )
        public
        checkValid(_nullifier)
        nonReentrant
        returns (uint tokenId, uint remainingTokens)
    {
        bool isClaimed = eventDetails[_nullifier].attendeeDetails[_to].claimed;
        require(isClaimed == false, "Recipient already claimed the Token");

        //require max claim
        remainingTokens = getRemainingTokens(_nullifier);
        require(remainingTokens > 0, "The maximum claims reached!");

        //record all attendees' details who are already claimed to Details struct
        //biar memudahkan saat ngambil semua data attendee-nya
        tokenId = getTokenId(_nullifier);
        eventDetails[_nullifier].claimers.push(Claimer(_to, tokenId, true));

        //record each attendee that is already claimed, to prevent double spending/minting to the same address
        eventDetails[_nullifier].attendeeDetails[_to] = Claimer(
            _to,
            tokenId,
            true
        );

        eventDetails[_nullifier].counterClaimed += 1;
        return (tokenId, remainingTokens);
    }

    /* Getter Functions */
    function getRemainingTokens(
        bytes32 nullifier
    ) internal view returns (uint remainingTokens) {
        uint startingTokenId = eventDetails[nullifier].startingTokenId;
        uint endingTokenId = eventDetails[nullifier].endingTokenId;
        uint claimed = eventDetails[nullifier].counterClaimed;
        remainingTokens = endingTokenId - startingTokenId - claimed;
    }

    function getTokenId(
        bytes32 nullifier
    ) internal view returns (uint tokenId) {
        tokenId =
            eventDetails[nullifier].counterClaimed +
            eventDetails[nullifier].startingTokenId;
    }

    function getClaimer(
        bytes32 nullifier
    )
        public
        view
        returns (
            address[] memory addresses,
            uint[] memory tokenIds,
            bool[] memory claimed
        )
    {
        addresses = new address[](eventDetails[nullifier].maxAttendees);
        tokenIds = new uint[](eventDetails[nullifier].maxAttendees);
        claimed = new bool[](eventDetails[nullifier].maxAttendees);

        for (uint i; i < eventDetails[nullifier].maxAttendees; i++) {
            addresses[i] = eventDetails[nullifier].claimers[i].attendee;
            tokenIds[i] = eventDetails[nullifier].claimers[i].tokenId;
            claimed[i] = eventDetails[nullifier].claimers[i].claimed;
        }
        return (addresses, tokenIds, claimed);
    }

    /* The following functions are overrides required by Solidity. */

    // OZ v5.0: _beforeTokenTransfer and _afterTokenTransfer replaced with _update
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = _ownerOf(tokenId);

        // Soulbound: can't transfer once owned (except mint, burn, or storage contract)
        require(
            from == address(0) ||
                to == address(0) ||
                from == storageAddress ||
                to == storageAddress,
            "Err: token is SOUL BOUND"
        );

        return super._update(to, tokenId, auth);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

/* SOULBADGE STORAGE TO MAKE CLAIM EASIER */

contract BadgeStorage is ReentrancyGuard, Ownable {
    constructor() Ownable(msg.sender) {}

    struct StorageItem {
        address nftContract;
        uint tokenId;
        address creator; //NFT creator
        address owner; //owner after it's being transfered
        bool claim;
    }

    mapping(uint => StorageItem) private idToStorageItem;

    event ItemStored(
        address indexed nftContract,
        uint indexed tokenId,
        address creator,
        address owner,
        bool claim
    );

    event badgeClaimed(address recipient, uint tokenId, uint remainingTokens);

    /* Stores an NFT on the storage before distributed */
    // create market item
    function storeItem(
        address nftContract,
        uint tokenId
    ) public payable nonReentrant onlyOwner {
        require(
            idToStorageItem[tokenId].claim == false,
            "You can't store a redeemed token!"
        );

        idToStorageItem[tokenId] = StorageItem(
            nftContract,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            false
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit ItemStored(nftContract, tokenId, msg.sender, address(0), false);
    }

    /* Transfers the NFT's ownership to attendee (msg.sender)*/
    // buy nft
    function claimBadge(
        address nftContract,
        bytes32 nullifier
    ) public nonReentrant {
        SoulBadge _SoulBadge = SoulBadge(nftContract);

        require(msg.sender != owner(), "Only attendees that can claim!");
        (uint tokenId, uint remainingTokens) = _SoulBadge.claim(
            nullifier,
            msg.sender
        );

        idToStorageItem[tokenId].owner = (msg.sender);
        idToStorageItem[tokenId].claim = true;

        IERC721(_SoulBadge).transferFrom(address(this), msg.sender, tokenId);

        emit badgeClaimed(msg.sender, tokenId, remainingTokens);
    }
}
