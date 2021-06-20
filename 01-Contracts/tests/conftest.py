import pytest
from brownie import (
    config,
    network,
    accounts,
    StreamUnlockableNFTFactory,
    SimpleNFT,
)


@pytest.fixture
def queen(accounts):
    """Creator of the SUNFT, owner of some NFTs"""
    return accounts[0]

@pytest.fixture
def creator(accounts):
    """Creator of the SUNFT, owner of some NFTs"""
    return accounts[1]

@pytest.fixture
def owner(accounts):
    """Owner of the SUNFT"""
    return accounts[2]

@pytest.fixture
def gambit(SimpleNFT, queen, creator, owner):
    """An NFT contract with a few NFTs minted to creator"""
    _nft = queen.deploy(StreamUnlockableNFTFactory)
    return _nft


@pytest.fixture
def nft(SimpleNFT, queen, creator, owner):
    """An NFT contract with a few NFTs minted to creator"""
    _nft = queen.deploy(SimpleNFT)
    _nft.createCollectible("ipfs://0000", {"from": creator})
    _nft.createCollectible("ipfs://1111", {"from": creator})
    return _nft

@pytest.fixture
def seven_days():
    return 60 * 60 * 24 * 7 + 60    # plus 1 min.

@pytest.fixture
def thirty_days():
    return 60 * 60 * 24 * 7 + 60    # plus 1 min.

@pytest.fixture
def stream_rate():
    return 1000

@pytest.fixture
def minting_fee():
    return 1e18
