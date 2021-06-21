from brownie import accounts, reverts, StreamUnlockableNFTFactory
from brownie.network.state import Chain
import pytest

chain = Chain()

# Canary Test
def test_account_balance():
    balance = accounts[0].balance()
    accounts[0].transfer(accounts[1], "10 ether", gas_price=0)
    assert balance - "10 ether" == accounts[0].balance()

"""
Test Suite Outline
- SUNFTs can be minted by an NFT holder and can be contain multiple NFTs
- SUNFTs can be deposited into by anyone including the holder
- SUNFTs will unlock their NFT after depositing rate for duration
- SUNFTs can be destoryed to recover the deposits
- SUNFTs will return locked NFTs to the creator if destoryed before unlocking
"""
#
def test_mint_snuft(gambit, nft, sunft, creator, owner, stream_rate, seven_days):
    """
    SUNFTs can be minted by an NFT holder and can be contain multiple NFTs
    """
    # First SUNFT minted in conftest.py

    # Check properties of the SUNFT created
    assert gambit.ownerOf(sunft) == owner
    assert gambit.getCreator(sunft) == creator
    assert gambit.getLastStartedAt(sunft) == 0
    assert gambit.getCurrentIndex(sunft) == 0
    assert gambit.getPrincipal(sunft) == 0
    assert gambit.getProgress(sunft) == 0
    assert nft.ownerOf(0) == gambit.address
    assert nft.ownerOf(1) == gambit.address
    # TODO: Implement fee
    # assert gambit.balance() - starting_eth == minting_fee

    # Check properties for the NFTs in the SUNFT
    assert gambit.getNumberOfNFTs(sunft) == 2
    assert gambit.getContractAddress(sunft, 0) == nft.address
    assert gambit.getTokenId(sunft, 0) == 0
    assert gambit.getRate(sunft, 0) == stream_rate
    assert gambit.getDuration(sunft, 0) == seven_days
    assert gambit.getLock(sunft, 0) == True
    assert gambit.getContractAddress(1, 1) == nft.address
    assert gambit.getTokenId(sunft, 1) == 1
    assert gambit.getRate(sunft, 1) == stream_rate
    assert gambit.getDuration(sunft, 1) == seven_days
    assert gambit.getLock(sunft, 1) == True


def test_unlock_nft(gambit, dai, nft, sunft, creator, owner, stream_rate, seven_days):
    """
    NFTs in a SUNFT can be unlocked by depositing rate over duration
    """
    starting_eth = gambit.balance()

    dai.approve(gambit.address, stream_rate * seven_days, {"from": owner})
    gambit.deposit(sunft, stream_rate * seven_days, {"from": owner})

    # Check properties of the SUNFT
    assert gambit.getLastStartedAt(sunft) != 0
    assert gambit.getCreator(sunft) == creator
    assert gambit.getPrincipal(sunft) == stream_rate * seven_days

    # Wait out the first NFTs duration
    chain.sleep(seven_days)

    # Unlock it
    gambit.tryUnlock(sunft, {"from": owner})
    # Confirm NFT ownership transfer
    assert nft.ownerOf(0) == owner
    assert gambit.getLock(sunft, 0) == False
    assert gambit.getPrincipal(sunft) == stream_rate * seven_days
    assert gambit.getProgress(sunft) == 0
    assert gambit.getCurrentIndex(sunft) == 1

    ## Unlock the second NFT in the SUNFT
    dai.approve(gambit.address, stream_rate * seven_days, {"from": owner})
    gambit.deposit(sunft, stream_rate * seven_days, {"from": owner})
    chain.sleep(seven_days // 2)
    # Try to unlock it
    gambit.tryUnlock(sunft, {"from": owner})
    assert gambit.getProgress(sunft) >= seven_days / 2
    assert gambit.getLock(sunft, 1) == True # Still locked


    chain.sleep(seven_days // 2)
    gambit.tryUnlock(sunft, {"from": owner})

    assert nft.ownerOf(1) == owner
    assert gambit.getLock(sunft, 1) == False
    assert gambit.getPrincipal(sunft) == stream_rate * seven_days * 2
    assert gambit.getProgress(sunft) == 0
    assert gambit.getCurrentIndex(sunft) == 2
