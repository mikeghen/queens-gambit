from brownie import accounts, reverts, StreamUnlockableNFTFactory
from brownie.network.state import Chain
import pytest

chain = Chain()

def is_within_four(item1,item2):
    return abs(item1 - item2) <= 4

# Canary Test
def test_account_balance():

    balance = accounts[0].balance()
    accounts[0].transfer(accounts[1], "10 ether", gas_price=0)
    assert balance - "10 ether" == accounts[0].balance()
    balance = accounts[1].balance()
    accounts[1].transfer(accounts[0],"10 ether", gas_price=0)
    assert balance - "10 ether" == accounts[1].balance()
    

"""
Test Suite Outline
- SUNFTs can be minted by an NFT holder and can be contain multiple NFTs
- SUNFTs can be deposited into by anyone including the holder
- SUNFTs will unlock their NFT after depositing rate for duration
- SUNFTs can be destoryed to recover the deposits
- SUNFTs will return locked NFTs to the creator if destoryed before unlocking
"""

def test_mint_snuft(initial_creator_balance, gambit, nft, sunft, creator, owner, stream_rate, seven_days, minting_fee):
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

    # Check if fee has properly been taken
    # Note: initial_balance grabs creator's balance before the test SUNFT is minted in the sunft fixture toc ompare to balance after
    assert initial_creator_balance - creator.balance() == minting_fee
    assert gambit.balance() == minting_fee

    # Check properties for the NFTs in the SUNFT
    assert gambit.getNumberOfNFTs(sunft) == 2
    assert gambit.getContractAddress(sunft, 0) == nft.address
    assert gambit.getTokenId(sunft, 0) == 0
    assert gambit.getRate(sunft, 0) == stream_rate
    assert gambit.getDuration(sunft, 0) == seven_days-3600
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
    # assert gambit.getProgress(sunft) == 0  
    # assert gambit.getProgress(sunft) == seven_days - gambit.getDuration(sunft, 0) + 1
    assert is_within_four( gambit.getProgress(sunft) , seven_days - gambit.getDuration(sunft, 0) + 1)
    assert gambit.getCurrentIndex(sunft) == 1

    ## Unlock the second NFT in the SUNFT
    dai.approve(gambit.address, stream_rate * seven_days, {"from": owner})
    gambit.deposit(sunft, stream_rate * seven_days, {"from": owner})
    chain.sleep(seven_days // 2)
    # Try to unlock it (and comfirm failure)
    gambit.tryUnlock(sunft, {"from": owner})
    assert gambit.getProgress(sunft) >= seven_days / 2
    # assert gambit.getProgress(sunft) == (seven_days + seven_days // 2) - gambit.getDuration(sunft, 0) + 3
    assert is_within_four( gambit.getProgress(sunft) , (seven_days + seven_days // 2) - gambit.getDuration(sunft, 0) + 3 )
    assert gambit.getLock(sunft, 1) == True # Still locked


    chain.sleep(seven_days // 2)
    gambit.tryUnlock(sunft, {"from": owner})

    assert nft.ownerOf(1) == owner
    assert gambit.getLock(sunft, 1) == False
    assert gambit.getPrincipal(sunft) == stream_rate * seven_days * 2
    # assert gambit.getProgress(sunft) == (seven_days * 2) - (gambit.getDuration(sunft,0) + gambit.getDuration(sunft,1)) + 2
    assert is_within_four( gambit.getProgress(sunft) , (seven_days * 2) - (gambit.getDuration(sunft,0) + gambit.getDuration(sunft,1)) + 2)
    assert gambit.getCurrentIndex(sunft) == 2


# gambit         Deploy StreamUnlockableNFTFactory contract with Dai as deposit token and provide contract instance to test
# dai            Deploy a test ERC20 called DAI and provide contract instance to test
# nft            Mints 2 NFTs to the creator address and provides NFT contract instance to test
# sunft          Mints a SUNFT and appends to it the two NFTs the creator has and provides sunftId of the SUNFT
# creator        Provides test the address of the SNUFT creator
# owner          Provides test the address of the person who the SNUFT has been minted to
# stream_rate    Provides test a stream rate of 1000 gwei/sec
# seven_days     Provides test seven days plus a minute worth of seconds

# Testing destroy WITH NO NFTs unlocked
def test_destroy_all_locked(gambit, dai, nft, sunft, creator, owner, queen, stream_rate, seven_days):       
    
    # Deposit 7 days worth of Dai
    dai.approve(gambit.address, stream_rate * seven_days, {"from": owner})
    gambit.deposit(sunft, stream_rate * seven_days, {"from": owner})

    # Test that the deposit went through
    assert gambit.getPrincipal(sunft) == stream_rate * seven_days
    assert dai.balanceOf(gambit.address) == stream_rate * seven_days

    # Canary - owner should own one SNUFT
    assert gambit.balanceOf(owner) == 1

    # Getting initial state before calling destroy
    owner_balance_after_deposit = dai.balanceOf(owner)
    initial_queen_balance = dai.balanceOf(queen)

    # Destroy SNUFT
    gambit.destroy(sunft, {"from":owner})

    # Test that sunft struct has been marked destroyed and the 1 SNUFT the owner has is burned
    assert gambit.getDestroyed(sunft) == True
    assert gambit.balanceOf(owner) == 0

    # Testing that the 5% fee is taken on the principal -> 95% goes to owner, 5% to queen
    assert dai.balanceOf(queen) - initial_queen_balance == (stream_rate * seven_days * 5)/100
    assert dai.balanceOf(owner) - owner_balance_after_deposit == (stream_rate * seven_days * 95)/100

    # Test that the principle gets zeroed out
    assert gambit.getPrincipal(sunft) == 0


# Testing destroy WITH NFTs unlocked
def test_destroy_one_unlocked(gambit, dai, nft, sunft, creator, owner, queen, stream_rate, seven_days):       
    
    # Deposit 14 days worth of Dai
    dai.approve(gambit.address, stream_rate * seven_days * 2, {"from": owner})
    gambit.deposit(sunft, stream_rate * seven_days * 2, {"from": owner})

    # Test that the deposit went through
    assert gambit.getPrincipal(sunft) == stream_rate * seven_days * 2
    assert dai.balanceOf(gambit.address) == stream_rate * seven_days * 2

    # Unlock both NFTs
    chain.sleep(seven_days)
    gambit.tryUnlock(sunft, {"from": owner})
    chain.sleep(seven_days)
    gambit.tryUnlock(sunft, {"from": owner})

    # Owner should now have 2 NFTs from unlocking
    assert nft.balanceOf(owner) == 2

    # Canary - owner should own one SNUFT
    assert gambit.balanceOf(owner) == 1

    # Getting initial state before calling destroy
    owner_balance_after_deposit = dai.balanceOf(owner)

    # Destroy SNUFT
    gambit.destroy(sunft, {"from":owner})

    # Test that sunft struct has been marked destroyed and the 1 SNUFT the owner has is burned
    assert gambit.getDestroyed(sunft) == True
    assert gambit.balanceOf(owner) == 0

    # Testing that no fee is taken by the queen as all NFTs have been unlocked before destruction
    assert dai.balanceOf(owner) - owner_balance_after_deposit == stream_rate * seven_days * 2

    # Test that the principle gets zeroed out
    assert gambit.getPrincipal(sunft) == 0


def test_setMintingFee(gambit, dai, nft, sunft, creator, owner, queen, stream_rate, seven_days):
    
    gambit.setMintingFee(2e18,{"from":queen})

    assert gambit.getMintingFee() == 2e18