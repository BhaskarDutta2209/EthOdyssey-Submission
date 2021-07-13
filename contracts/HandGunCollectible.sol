// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@chainlink/contracts/src/v0.6/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HandGunCollectible is ERC721, ChainlinkClient {

    uint256 public tokenCounter;
    address public owner;

    mapping (bytes32 => address) public requestIdToSender;
    mapping (address => bool) public usedAirDrop; // Every account is eligible for 1 free collectible
    mapping (bytes32 => string) public requestIdToTokenURI;
    mapping (IERC20 => uint256) public whitelistedTokens;

    address private oracle;
    bytes32 private jobId;
    uint256 private fee;

    event ownershipTransferedTo(address indexed new_owner);
    event requestedAirDrop(bytes32 indexed requestId);
    event newTokenWhitelisted(IERC20 indexed token, uint256 indexed per_collectible_price);

    constructor(
        address _oracle, 
        string memory _jobId, 
        uint256 _fee, 
        address _link
    )
    public 
    ERC721("HandGuns","HG") {
    
        if(_link == address(0)) {
            setPublicChainlinkToken();
        } else {
            setChainlinkToken(_link);
        }

        owner = msg.sender;
        oracle = _oracle;
        jobId = stringToBytes32(_jobId);
        fee = _fee;
    }

    function transferOwnership(address new_owner) public {
        require(owner == msg.sender, "Only present owner can transfer the ownership");
        owner = new_owner;
        emit ownershipTransferedTo(new_owner);
    }

    function whitelistToken(IERC20 token, uint256 per_collectible_price) public {
        require(owner == msg.sender);

        whitelistedTokens[token] = per_collectible_price;
        emit newTokenWhitelisted(token, per_collectible_price);
    }

    function requestAirDrop(string memory tokenURI) public returns (bytes32) {
        // Check if eligible for airdrop
        require(
            usedAirDrop[msg.sender] == false
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


        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        // Set the URL to perform the GET request on
        request.add("get","http://www.randomnumberapi.com/api/v1.0/random");

    }

    function fulfill(bytes32 _requestId, uint256 _volume) public recordChainlinkFulfillment(_requestId) {
        // Do the main stuff of generating the NFT
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