// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC721/IERC721.sol";
import "OpenZeppelin/openzeppelin-contracts@4.0.0/contracts/token/ERC20/IERC20.sol";
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
      uint256 currentIndex;                  // Tracks the current index within `nfts`
      uint256 principal;                     // The cumulative amount streamed into this SUNFT
      address creator;                       // Minter of the SUNFT (The address of an ERC721 contract of the NFT)
      bool isDestroyed;                      // Whether the SUNFT has been destroyed (has core SUNFT functionality disabled)
      LockableNFT[] nfts;
    }

    address queen;        // The owner of this StreamUnlockableNFTFactory contract
    address depositToken; // The token accepted for deposit
    uint256 mintingFee;   // Eth amount to take as minting fee

    StreamUnlockableNFT[] sunfts; // All SUNFTs

    // TODO: make isNotDestroyed modifier - based on snuftId, change identity access mgmt for according functions

    modifier isNotDestroyed(uint256 sunftId) {
      require(sunfts[sunftId].isDestroyed == false, "This SUNFT has been destroyed");
      _;
    }

    modifier onlyCreator(uint256 sunftId) {
      require(sunfts[sunftId].creator == msg.sender, "You are not the creator of this SUNFT");
      _;
    }
 
    modifier onlyQueen() {
      require(msg.sender == queen, "You are not the owner");
      _;
    }

    constructor (address _depositToken, uint256 _mintingFee) public ERC721 ("Stream Unlockable NFT", "SUNFT"){
      // Initialize a blank SUNFT at index 0
      sunfts.push(); //
      mintingFee = _mintingFee;
      depositToken = _depositToken;
      queen = msg.sender;
    }

    function mint(address contractAddress, uint256 tokenId, uint256 rate, uint256 duration, address recipient) public payable returns (uint256) {
      // Require a fee to be paid in ETH (MATIC)
      require(msg.value >= mintingFee, "You must pay the minting fee");
      
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

    function append(address contractAddress, uint256 tokenId, uint256 rate, uint256 duration, uint256 sunftId)
      onlyCreator(sunftId) isNotDestroyed(sunftId) public returns(uint256) {

      // Transfer the NFT into the contract
      IERC721(contractAddress).transferFrom(msg.sender, address(this), tokenId);

      // Initialize a new SUNFT
      // TODO: Dry this out?
      uint256 index = sunfts[sunftId].nfts.length;
      sunfts.push();
      LockableNFT memory lnft = LockableNFT(contractAddress, tokenId, rate, duration, true);
      sunfts[sunftId].creator = msg.sender;
      sunfts[sunftId].nfts.push(lnft);
      sunfts[sunftId].nfts[index].contractAddress = contractAddress;
      sunfts[sunftId].nfts[index].tokenId = tokenId;
      sunfts[sunftId].nfts[index].rate = rate;
      sunfts[sunftId].nfts[index].duration = duration;

    }

    // TODO: Superfluid start stream
    function deposit(uint256 sunftId, uint256 amount) 
      isNotDestroyed(sunftId) external {

      require(IERC20(depositToken).transferFrom(msg.sender, address(this), amount), "!transferable");
      sunfts[sunftId].principal += amount;
      sunfts[sunftId].updatedAt = block.timestamp;
    }

    // if the "stop" function (not implemented yet) calls this upon stream cancellation, perhaps this should be public instead of external
    function tryUnlock(uint256 sunftId) 
      isNotDestroyed(sunftId) external {

      sunfts[sunftId].progress += block.timestamp - sunfts[sunftId].updatedAt;
      LockableNFT memory lnft = sunfts[sunftId].nfts[sunfts[sunftId].currentIndex];
      if (sunfts[sunftId].progress >= lnft.duration && sunfts[sunftId].principal >= lnft.rate * lnft.duration ) {
        IERC721(lnft.contractAddress).transferFrom(address(this), msg.sender, lnft.tokenId);
        sunfts[sunftId].nfts[sunfts[sunftId].currentIndex].locked = false;
        sunfts[sunftId].currentIndex += 1;
        sunfts[sunftId].progress = 0;
      }
    }

    function destroy(uint256 sunftId) external 
      onlyCreator(tokenId) {

        // where in this contract are we burning the NFTs?
        // How do you burn all the NFTs at once without a loop?

        sunfts[sunftId].isDestroyed = true;

      }

    // Recover NFTs from a destroyed SNUFT
    function recover(uint256 sunftId, uint256 lockableNFTIndex) {

    }

    // TODO: make a burn function that destorys token by SNUFT ID

    // TODO: test the changeFee changes fee
    function setMintingFee(uint256 newFee) external 
      onlyQueen() {
      mintingFee = newFee;
    }

    function getCreator(uint256 sunftId) external view returns (address) {
      return sunfts[sunftId].creator;
    }
    function getLastStartedAt(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].updatedAt;
    }
    function getCurrentIndex(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].currentIndex;
    }
    function getPrincipal(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].principal;
    }

    function getProgress(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].progress;
    }

    function getNumberOfNFTs(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].nfts.length;
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
