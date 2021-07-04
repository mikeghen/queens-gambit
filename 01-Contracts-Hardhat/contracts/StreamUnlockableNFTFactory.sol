// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import {
    ISuperfluid,
    ISuperToken,
    ISuperApp,
    ISuperAgreement,
    SuperAppDefinitions,
    ISuperfluidToken 
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

// TODO: Superfluid call back that initiates the _deposit

contract StreamUnlockableNFTFactory is ERC721URIStorage, SuperAppBase {

    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address
    // ISuperToken private _acceptedToken; // accepted token

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
      bool initDeposit;                      // See if an initial deposit has been made on the SNUFT
      uint256 currentIndex;                  // Tracks the current index within `nfts` that's up to be unlocked
      uint256 principal;                     // The cumulative amount streamed into this SUNFT
      uint256 rate;                          // rate at which the owner of the NFT is currently streaming into the app
      uint256 tokenId;                       // The tokenID of the SNUFT represented by the struct
      address creator;                       // Minter of the SUNFT (The address of an ERC721 contract of the NFT)
      bool isDestroyed;                      // Whether the SUNFT has been destroyed (has core SUNFT functionality disabled)
      LockableNFT[] nfts;
    }

    address queen;        // The owner of this StreamUnlockableNFTFactory contract
    ISuperToken depositToken; // The token accepted for deposit
    uint256 mintingFee;   // Eth amount to take as minting fee

    StreamUnlockableNFT[] sunfts; // All SUNFTs

    modifier isNotDestroyed(uint256 sunftId) {
      require(sunfts[sunftId].isDestroyed == false, "This SUNFT has already been destroyed");
      _;
    }

    modifier isDestroyed(uint256 sunftId) {
      require(sunfts[sunftId].isDestroyed == true, "Cannot recover NFTs from a SUNFT has not been destroyed");
      _;
    }

    modifier onlyCreator(uint256 sunftId) {
      require(sunfts[sunftId].creator == msg.sender, "You are not the creator of this SUNFT");
      _;
    }
 
    modifier onlyQueen() {
      require(msg.sender == queen, "You are not the contract creator");
      _;
    }

    modifier onlySUNFTHolder(uint256 sunftId) {
      require(msg.sender == ownerOf(sunftId), "You don't own the SUNFT");
      _;
    }

    constructor (
        // address _depositToken, 
        uint256 _mintingFee,        
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken) public ERC721 ("Stream Unlockable NFT", "SUNFT") {

      assert(address(host) != address(0));
      assert(address(cfa) != address(0));
      assert(address(acceptedToken) != address(0));
      
      // Initialize a blank SUNFT at index 0
      sunfts.push(); //
      mintingFee = _mintingFee;
      // depositToken = _depositToken;
      queen = msg.sender;

      _host = host;
      _cfa = cfa;
      depositToken = acceptedToken;
    }

    function mint(address contractAddress, uint256 tokenId, uint256 rate, uint256 duration, address recipient) public payable returns (uint256) {
      // Require a fee to be paid in ETH (MATIC)
      require(msg.value >= mintingFee, "You must pay the minting fee");
      
      // User must approve before minting
      // Transfer the NFT into the contract
      IERC721(contractAddress).transferFrom(msg.sender, address(this), tokenId);

      // Make the next SNUFT token ID
      sunftCounter.increment(); // Starts at 1
      uint256 sunftId = sunftCounter.current();

      // Initialize a new SUNFT
      sunfts.push();
      LockableNFT memory lnft = LockableNFT(contractAddress, tokenId, rate, duration, true);
      sunfts[sunftId].creator = msg.sender;
      sunfts[sunftId].tokenId = sunftId;
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

    // TODO: eventually, stream will have to intelligently start/stop if SUNFT is destroyed. This stop logic might be initiated in destroy function
    // Make it such that you can only call deposit once. Need to simplify for tryUnlock
    function _streamDeposit(uint256 sunftId, uint256 flowRate) 
      isNotDestroyed(sunftId) internal {

      // require(IERC20(depositToken).transferFrom(msg.sender, address(this), amount), "!transferable");
      // TODO: modify rate, amount is irrelevant with streaming
      sunfts[sunftId].rate = flowRate;
      // sunfts[sunftId].principal += amount;
      if (sunfts[sunftId].initDeposit != true) {
        sunfts[sunftId].updatedAt = block.timestamp;
        sunfts[sunftId].initDeposit = true;
      }
    }

    // TODO: stop function (internal), called on stream ended callback

    // if the "stop" function (not implemented yet) calls this upon stream cancellation, perhaps this should be public instead of external
    function tryUnlock(uint256 sunftId) 
      isNotDestroyed(sunftId) onlySUNFTHolder(sunftId) external {
      sunfts[sunftId].progress += block.timestamp - sunfts[sunftId].updatedAt;
      sunfts[sunftId].principal += sunfts[sunftId].rate * (block.timestamp - sunfts[sunftId].updatedAt);
      // First NFT that's appended is the first that can be withdrawn (FIFO), determined by the currentIndex
      LockableNFT memory lnft = sunfts[sunftId].nfts[sunfts[sunftId].currentIndex];
      // The second conditional would be effective for the trying to unlock the first SUNFT, but...
      // After that, it's always going to be greater because principal doesn't reset and lnft.rate * lnft.duration is how much must be streamed for just one NFT
      // You'd have to compare sunfts[sunftId].principal to overall deposit amount needed up until this NFT to unlock it  
      // So like: sunfts[sunftId].principal - (lnft.rate * lnft.duration for all previous NFTs) >=  lnft.rate * lnft.duration to 
      if (sunfts[sunftId].progress >= lnft.duration && sunfts[sunftId].principal >= lnft.rate * lnft.duration ) {
        IERC721(lnft.contractAddress).transferFrom(address(this), msg.sender, lnft.tokenId);
        sunfts[sunftId].nfts[sunfts[sunftId].currentIndex].locked = false;
        sunfts[sunftId].currentIndex += 1;
        // You don't want to wipe out progress because then all the residual progress goes to waste
        // What if you were streaming and had progress equivalent to 2 NFTs. You'd tryUnlock and a ton of progress would vanish. That wouldn't be fair
        // Instead, we reduce progress just by the amount of progress required for the NFT (duration). User keeps the rest of the progress and it gets built on the next time tryUnlock is called!
        sunfts[sunftId].progress -= lnft.duration;
      }
      sunfts[sunftId].updatedAt = block.timestamp;
    }

    function destroy(uint256 sunftId)  
      isNotDestroyed(sunftId) onlySUNFTHolder(sunftId) external {

        _burn(sunftId);
        sunfts[sunftId].isDestroyed = true;

        // If current index of the SUNFT (the index which shows which LockableNFT is up for unlocking next) is equal to the length of the number of NFTs in the SUNFT
        // That indicates that all NFTs in the SUNFT have been unlocked and the SUNFT creator can get their full principle back upon destruction
        // Otherwise, the contract creator (queen) gets a 5% fee
        if (sunfts[sunftId].currentIndex == sunfts[sunftId].nfts.length) {
          IERC20(depositToken).transfer(msg.sender, sunfts[sunftId].principal);
        } 
        else {
          IERC20(depositToken).transfer(msg.sender, (sunfts[sunftId].principal * 95)/100);
          IERC20(depositToken).transfer(queen, (sunfts[sunftId].principal * 5)/100);
        }

        sunfts[sunftId].principal = 0;

      }

    // TODO: SUNFT creator can manually Recover NFTs from a destroyed SNUFT
    function recover(uint256 sunftId, uint256 lockableNFTIndex) 
      onlyCreator(sunftId) isDestroyed(sunftId) external {

      // (!) What if lockableNFTIndex provided is out of bounds? Add require statement
      LockableNFT memory lnft = sunfts[sunftId].nfts[lockableNFTIndex];
      IERC721(lnft.contractAddress).transferFrom(address(this), msg.sender, lnft.tokenId);

    }

    // TODO: test the changeFee changes fee
    function setMintingFee(uint256 newFee) external 
      onlyQueen() {
      mintingFee = newFee;
    }

    /**************************************************************************
     * SuperApp callbacks
     *************************************************************************/

    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata _agreementData,
        bytes calldata ,// _cbdata,
        bytes calldata _ctx
    )
        external override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        newCtx = _ctx;
        // Get flowSender from agreement data
        (address flowSender,) = abi.decode(_agreementData, (address,address));

        // Get flow rate to the app from flowSender
        uint256 depositFlowRate;
        ( ,int96 flowRate, , ) = _cfa.getFlow(depositToken, flowSender, address(this));
        depositFlowRate = uint(int(flowRate));

        // Get SUNFT ID from user data
        uint256 snuftId = abi.decode(_host.decodeCtx(_ctx).userData, (uint256));

        // User SUNFT id must be in range of SUNFT ids created
        require(snuftId <= sunftCounter.current() && snuftId > 0 );

        streamDeposit(snuftId, depositFlowRate);
        return newCtx;
    }

    function _isInputToken(ISuperToken superToken) internal view returns (bool) {
        return address(superToken) == address(depositToken);
    }


    function _isCFAv1(address agreementClass) internal view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    function _isIDAv1(address agreementClass) internal view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.InstantDistributionAgreement.v1");
    }

    modifier onlyHost() {
        require(msg.sender == address(_host), "one host");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
      if (_isCFAv1(agreementClass)) {
        require(_isInputToken(superToken), "!inputAccepted");
      } 
      _;
    }

    /**************************************************************************
     * Getters & Setters
     *************************************************************************/

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
    function getDestroyed(uint256 sunftId) external view returns (bool) {
      return sunfts[sunftId].isDestroyed;
    }
        function getSNUFTRate(uint256 sunftId) external view returns (uint256) {
      return sunfts[sunftId].rate;
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
    function getMintingFee() external view returns (uint256) {
      return mintingFee;
    }

}

