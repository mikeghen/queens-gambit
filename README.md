# Queens Gambit
**Stream Unlockable NFTs** (SUNFT) are 1 or more NFTs locked into a smart contract that can only be unlocked by streaming tokens into the contract for a set duration. 1 SNUFT contains a _sequence_ of NFTs that each become unlocked after streaming at a _rate_ for a _duration_ of time.

![images/SUNFTSequence.png](images/SUNFTSequence.png)
_3 Cyrpto Corgis are wrapped together and locked in a contract to create a single SUNFT, each corgi gets locked and is available once DAIx has been stream for a period of time specified by the creator of this SUNFT_

## Overview
* Queens Gambit protocol supports minting and managing a SUNFT
  * The original protocol is used for making SUNFTs using Crypto Corgis
* A SUNFT is define using a _sequence of tuples_ containing:
  * The base NFT `contractAddress`
  * The `tokenId` of the NFT to include
  * The minimum `rate` that needs to be streamed to unlocked
  * The `duration` that the stream needs to be before unlocking
  * `[(contractAddress, tokenId, rate, duration), ... ]`
* Each SUNFT...
  * is _minted_ by passing in the first NFT to add to the SUNFT
  * can have more NFTs _appended_ to it
  * is _funded_ by streaming in DAIx into the SUNFT
  * can be _unlocked_ to recover the art after streaming for the specified rate and duration
  * must be _destroyed_ to recover the deposits
  * can be destroyed early before the locked NFTs are unlocked, the NFTs will return to this SUNFT's _creator_

## Protocol Specification


### Structures

#### `LockableNFT`
* `address contractAddress` - The contract address of the NFT to include
* `uint256 tokenId` - The ID of the NFT from the contract at `contractAddress`
* `int96 rate` - The minimum rate required to start the unlock
* `uint256 duration` - The duration in seconds required to stream at least `rate` to unlock the NFTs
* `bool locked` - Status field for whether this NFT is (un)locked

#### `StreamUnlockableNFT`
* `mapping (uint256 => LockableNFT) nfts` - The sequence of `LockableNFT` that make up this SUNFT
* `address creator` - The minter of this SUNFT
* `uint256 progress` - The amount of time in seconds that the stream has been opened, resets after each NFT in the `nfts` sequence becomes unlocked
* `uint256 lastStartedAt` - The timestamp when the last stream was started/updated
* `uint256 nextUnlockedIndex` - An index tracking which of the `nfts` is currently being worked on
* `uint256 owner` - The account that owns this SUNFT
* `uint256 principal` - The principal amount deposited (i.e. the net total streamed)


### Parameters
  * `address queen` - The owner of the contract and the address authorized to collect fees
  * `mapping (uint256 => StreamUnlockableNFT) sunfts` - A mapping of SUNFT `tokenId`s to their respective `StreamUnlockableNFT`
  * `address depositToken` - The token used to feed the corgi NFTs
  * `uint256 mintingFee` - The fee to mint a SUNFT
  * `address mintingFeeToken` - The token accepted as the minting fee, 0x0 for ETH

### Modifiers
* `onlyRoyalty` - modifies methods so they can only be called by the `queen`

### Methods
#### mint(LockableNFT nftToLock)
* Parameters
  * `nftToLock` - A sequence of NFTs to lock into this SUNFT
* Pre-conditions
  * `msg.sender` has approved this contract to transfer `nftToLock`
  * `msg.sender` has approved this contract to transfer `mintingFee` of `mintingFeeToken`s
* Post-conditions
  * all `nftsToLock` are transferred to this contract
  * 1 SUNFT is transferred to `msg.sender`

#### start(uint256 sunftId)
* Parameters
  * `sunftId` - The id of the SUNFT to start streaming `feedToken` to
* Pre-conditions
  * None
* Post-conditions
  * Opens a superfluid stream to this contract
  * Sets `lastStartedAt` to now

#### tryUnlock(uint256 sunftId)
  * Parameters
    * `sunftId` - The id of the SUNFT to try to unlock/update
  * Pre-conditions
    * None
  * Post-conditions
    * Computes the net amount streamed and updates `principal`
    * Updates progress with the `block.timestamp - lastStartedAt`
    * If `progress >= nfts[nextUnlockedIndex].duration` and `msg.sender == nfts[nextUnlockedIndex].owner`
      * Unlock the nft at `nextUnlockedIndex` and transfer it to the SUNFTs owner
      * Increment `nextUnlockedIndex`
      * Reset progress to 0

#### stop(uint256 sunftId)
* Parameters
  * `sunftId` - The id of the SUNFT to stop streaming `feedToken` to
* Pre-conditions
  * None
* Post-conditions
  * Closes a superfluid stream to this contract
  * Call `tryUnlock`

#### destroy(uint256 sunftId)
* Parameters
  * `sunftId` - The id of the SUNFT to destroy
* Pre-conditions
  * The message sender is the holder of the SUNFT at `sunftId`
* Post-conditions
  * The NFT is burned
  * If any `nfts` are still not unlocked
    * `principal * 0.95` amount of `feedToken` is transfered to `msg.sender`
    * `principal * 0.05` amount of `feedToken` is transfered to `queen` (early withdraw penalty)
    * Transfer them back to the `creator`
  * Otherwise
    * `principal` amount of `feedToken` is transfered to `msg.sender`
