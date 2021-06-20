from brownie import accounts, reverts, StreamUnlockableNFTFactory
from brownie.network.state import Chain
import pytest

# Canary Test
def test_account_balance():
    balance = accounts[0].balance()
    accounts[0].transfer(accounts[1], "10 ether", gas_price=0)
    assert balance - "10 ether" == accounts[0].balance()

"""
Test Suite Outline
- SUNFTs can be minted by an NFT holder
- SUNFTs can be contain multiple NFTs
- SUNFTs can be deposited into by anyone including the holder
- SUNFTs will unlock their NFT after depositing rate for duration
- SUNFTs can be destoryed to recover the deposits
- SUNFTs will return locked NFTs to the creator if destoryed before unlocking
"""
#
def test_mint_snuft(gambit, nft, creator, owner, stream_rate, seven_days):
    """
    SUNFTs can be minted by an NFT holder
    """
    starting_eth = gambit.balance()

    # Approve 2 NFTs to lock into a SUNFT
    nft.approve(gambit.address, 0, {"from": creator})
    nft.approve(gambit.address, 1, {"from": creator})

    # Mint the SUNFT directly to its owner, append the 2nd NFT after mint
    gambit.mint(nft.address, 0, stream_rate, seven_days, owner, {"from": creator})
    gambit.append(nft.address, 1, stream_rate, seven_days, 1, {"from": creator})

    # Check properties of the SUNFT created
    assert gambit.ownerOf(1) == owner
    assert gambit.getCreator(1) == creator
    assert gambit.getLastStartedAt(1) == 0
    assert gambit.getCurrentIndex(1) == 0
    assert gambit.getPrincipal(1) == 0
    assert gambit.getProgress(1) == 0
    assert nft.ownerOf(0) == gambit.address
    # TODO: Implement fee
    # assert gambit.balance() - starting_eth == MINTING_FEE

    # Check properties for the NFTs in the SUNFT
    assert gambit.getNumberOfNFTs(1) == 2
    assert gambit.getContractAddress(1, 0) == nft.address
    assert gambit.getTokenId(1, 0) == 0
    assert gambit.getRate(1, 0) == stream_rate
    assert gambit.getDuration(1, 0) == seven_days
    assert gambit.getLock(1, 0) == True
    assert gambit.getContractAddress(1, 1) == nft.address
    assert gambit.getTokenId(1, 1) == 1
    assert gambit.getRate(1, 1) == stream_rate
    assert gambit.getDuration(1, 1) == seven_days
    assert gambit.getLock(1, 1) == True
