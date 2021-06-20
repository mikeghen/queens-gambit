// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract SimpleNFT is ERC721URIStorage {
    uint256 public tokenCounter;
    constructor () public ERC721 ("Dogie", "DOG"){
        tokenCounter = 0;
    }

    function createCollectible(string memory tokenURI) public returns (uint256) {
        uint256 newItemId = tokenCounter;
        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        tokenCounter = tokenCounter + 1;
        return newItemId;
    }

}
