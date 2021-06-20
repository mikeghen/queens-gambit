// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC721/IERC721.sol";
import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/utils/Counters.sol";

contract StreamUnlockableNFTFactory is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private sunftCounter;

    struct LockableNFT {       // A reference to an NFT locked in this contract
      address contractAddress; // The address of an ERC721 contract of the NFT
      uint256 tokenId;         // The token id of the NFT
      uint256 rate;            // The amount of uints to stream to unlock the NFT
      uint256 duration;        // The amount of time to stream rate before unlocking
      bool locked;             // True if stream has now not yet unlock the NFT
    }

    struct StreamUnlockableNFT {
      uint256 updatedAt;                     // The last time a stream was updated
      uint256 progress;                      // The amount of time that streaming has happened so far
      uint256 currentNftIndex;               // Tracks the current index within `nfts`
      uint256 principal;                     // The cumulative amount streamed into this SUNFT
      address creator;                       // The address of an ERC721 contract of the NFT
      LockableNFT[] nfts;
    }

    address queen;        // The owner of this StreamUnlockableNFTFactory contract
    address depositToken; // The token accepted for deposit
    uint256 mintingFee;   // Eth amount to take as minting fee

    StreamUnlockableNFT[] sunfts; // All SUNFTs

    constructor () public ERC721 ("Stream Unlockable NFT", "SUNFT"){
      // Initialize a blank SUNFT at index 0
      sunfts.push(); //
      mintingFee = 1e18;
    }

    function mint(address contractAddress, uint256 tokenId, uint256 rate, uint256 duration, address recipient) public payable returns (uint256) {
      // Transfer the NFT into the contract
      IERC721(contractAddress).transferFrom(msg.sender, address(this), tokenId);

      // Make the next SNUFT token ID
      sunftCounter.increment();
      uint256 sunftId = sunftCounter.current();

      // Initialize a new SUNFT
      sunfts.push();
      LockableNFT memory lnft = LockableNFT(contractAddress, tokenId, rate, duration, true);
      sunfts[sunftId].creator = msg.sender;
      sunfts[sunftId].nfts.push(lnft);
      sunfts[sunftId].nfts[0].contractAddress = contractAddress;
      sunfts[sunftId].nfts[0].tokenId = tokenId;
      sunfts[sunftId].nfts[0].rate = rate;
      sunfts[sunftId].nfts[0].duration = duration;

      // Save and mint
      _mint(recipient, sunftId);
      return sunftId;
    }

    function getCreator(uint256 sunftId) external view returns (address) {
      return sunfts[sunftId].creator;
    }
    function getLastStartedAt(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].updatedAt;
    }
    function getCurrentIndex(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].currentNftIndex;
    }
    function getPrincipal(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].principal;
    }
    function getProgress(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].progress;
    }

    function getContractAddress(uint256 sunftId, uint256 nftIndex) external view returns (address) {
      return sunfts[sunftId].nfts[nftIndex].contractAddress;
    }
    function getTokenId(uint256 sunftId, uint256 nftIndex) external view returns (uint256) {
      return sunfts[sunftId].nfts[nftIndex].tokenId;
    }
    function getRate(uint256 sunftId, uint256 nftIndex) external view returns (uint256) {
      return sunfts[sunftId].nfts[nftIndex].rate;
    }
    function getDuration(uint256 sunftId, uint256 nftIndex) external view returns (uint256) {
      return sunfts[sunftId].nfts[nftIndex].duration;
    }
    function getLock(uint256 sunftId, uint256 nftIndex) external view returns (bool) {
      return sunfts[sunftId].nfts[nftIndex].locked;
    }

}
