// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HandGunCollectible is ERC721, ChainlinkClient {

    uint256 public tokenCounter;
    address public owner;
    uint256 public per_collectible_price;
    uint256 public total_funds_collected;

    mapping (bytes32 => address) public requestIdToSender;
    mapping (address => bool) public usedAirDrop; // Every account is eligible for 1 free collectible
    mapping (bytes32 => string) public requestIdToTokenURI;
    mapping (uint256 => Weapon) public tokenIdToWeapon;
    mapping (bytes32 => uint256) public requestIdToTokenId;
    // mapping (IERC20 => uint256) public whitelistedTokens;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    enum WeaponType { Revolver, AssaultRifle }

    event ownershipTransferedTo(address indexed new_owner);
    event requestedAirDrop(bytes32 indexed requestId);
    event requestedCollectible(bytes32 indexed requestId);
    event commissionChanged(uint256 new_commission);
    // event newTokenWhitelisted(IERC20 indexed token, uint256 indexed per_collectible_price);

    struct Weapon {
        WeaponType weaponType;
        uint256 damage;
    }

    constructor(
        address _oracle, 
        string memory _jobId, 
        uint256 _fee, 
        address _link
    )
    public 
    ERC721("Survival Weapon","WEAPON") {
    
        if(_link == address(0)) {
            setPublicChainlinkToken();
        } else {
            setChainlinkToken(_link);
        }

        owner = msg.sender;
        oracle = _oracle;
        jobId = stringToBytes32(_jobId);
        fee = _fee;
        per_collectible_price = 0;
    }

    function transferOwnership(address new_owner) public {
        require(owner == msg.sender, "Only present owner can transfer the ownership");
        owner = new_owner;
        emit ownershipTransferedTo(new_owner);
    }

    function changeCommission(uint256 new_commission) public {
        require(msg.sender == owner, "Only owner can change the commission");
        per_collectible_price = new_commission;
        emit commissionChanged(new_commission);
    } 

    function withdrawCollection(address payable benificiary, uint256 amount) public {
        require(owner == msg.sender, "Only owner can withdraw");
        require(amount <= total_funds_collected, "Withdraw amount greater than total_funds_collected");

        benificiary.transfer(amount);
    }

    // function whitelistToken(IERC20 token, uint256 per_collectible_price) public {
    //     require(owner == msg.sender);

    //     whitelistedTokens[token] = per_collectible_price;
    //     emit newTokenWhitelisted(token, per_collectible_price);
    // } 

    function requestAirDrop(string memory tokenURI) public returns (bytes32) {
        // Check if eligible for airdrop
        require(
            usedAirDrop[msg.sender] != true
        );

        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        // Set the URL to perform the GET request on
        request.add("get","http://www.randomnumberapi.com/api/v1.0/random");
        
        // Send the request
        bytes32 requestId = sendChainlinkRequestTo(oracle, request, fee);

        requestIdToSender[requestId] = msg.sender;
        usedAirDrop[msg.sender] = true;
        requestIdToTokenURI[requestId] = tokenURI;

        emit requestedAirDrop(requestId);

        return requestId;
    }

    function createCollectible(string memory tokenURI) public payable returns (bytes32) {

        // Take payment
        if(per_collectible_price > 0) {
            require(
                msg.value > 0,
                "Must pay the price of each token"
            );
            require(
                msg.value % per_collectible_price == 0,
                "Must pay a multiple of per collectible price"
            );
        }

        total_funds_collected += msg.value;

        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        // Set the URL to perform the GET request on
        request.add("get","http://www.randomnumberapi.com/api/v1.0/random");

        // Send the request
        bytes32 requestId = sendChainlinkRequestTo(oracle, request, fee);

        requestIdToSender[requestId] = msg.sender;
        requestIdToTokenURI[requestId] = tokenURI;

        emit requestedCollectible(requestId);

        return requestId;
    }

    function fulfill(bytes32 requestId, uint256 randomNumber) public recordChainlinkFulfillment(requestId) {
        
        address collectibleOwner = requestIdToSender[requestId];
        string memory tokenURI = requestIdToTokenURI[requestId];

        uint256 newTokenId = tokenCounter;

        _safeMint(collectibleOwner, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        
        WeaponType gunType = WeaponType(randomNumber%2);

        uint256 minPower;
        if(gunType == WeaponType.AssaultRifle)
            minPower = 50;
        else if(gunType == WeaponType.Revolver)
            minPower = 10;

        Weapon memory weapon = Weapon(gunType, minPower + (randomNumber%50)); // Power varies in range of 50

        tokenIdToWeapon[newTokenId] = weapon;

        requestIdToTokenId[requestId] = newTokenId;

        tokenCounter+=1;
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _setTokenURI(tokenId, tokenURI);
    }

    function stringToBytes32(string memory source) public pure returns (bytes32 result) {

        bytes memory tempEmptyStringTest = bytes(source);

        if(tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}