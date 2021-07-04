import pytest
from brownie import (
    config,
    network,
    accounts,
    Token,
    StreamUnlockableNFTFactory,
    SFStreamUnlockableNFTFactory,
    SimpleNFT,
)
from brownie import Token



@pytest.fixture
def queen(accounts):
    """Creator of the SUNFT, owner of some NFTs"""
    return accounts[0]

@pytest.fixture
def creator(accounts):
    """Creator of the SUNFT, owner of some NFTs"""
    return accounts[1]

@pytest.fixture()
def owner(accounts):
    """Owner of the SUNFT"""
    return accounts[2]

@pytest.fixture
def dai(owner, Token):
    return owner.deploy(Token, "DAI", "DAI", 18, 1000 * 10**18)

@pytest.fixture
def gambit(queen, dai):
    _nft = queen.deploy(StreamUnlockableNFTFactory, dai.address, 1e18)
    return _nft

@pytest.fixture
def SFgambit(queen,dai):
    """Deploying SNUFT contract with rate logic for separate testing"""
    _nft = queen.deploy(SFStreamUnlockableNFTFactory, dai.address, 1e18)
    return _nft

@pytest.fixture
def nft(SimpleNFT, queen, creator, owner):
    """An NFT contract with a few NFTs minted to creator"""
    _nft = queen.deploy(SimpleNFT)
    _nft.createCollectible("ipfs://0000", {"from": creator})
    _nft.createCollectible("ipfs://1111", {"from": creator})
    return _nft

@pytest.fixture
def initial_creator_balance(creator):
    # Use this fixture before other activities/fixtures to capture initial ETH balance of creator account
    init_creator_bal = creator.balance()
    return init_creator_bal                

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

@pytest.fixture
def sunft(nft, gambit, queen, creator, owner, seven_days, stream_rate,minting_fee):
    # Approve 2 NFTs to lock into a SUNFT
    nft.approve(gambit.address, 0, {"from": creator})
    nft.approve(gambit.address, 1, {"from": creator})

    _sunft_id = gambit.mint(nft.address, 0, stream_rate, seven_days-3600, owner, {"from": creator, "value": 10**18}).return_value
    gambit.append(nft.address, 1, stream_rate, seven_days, 1, {"from": creator})

    return _sunft_id

@pytest.fixture
def SFsunft(nft, SFgambit, queen, creator, owner, seven_days, stream_rate,minting_fee):
        # Approve 2 NFTs to lock into a SUNFT
    nft.approve(SFgambit.address, 0, {"from": creator})
    nft.approve(SFgambit.address, 1, {"from": creator})

    _sunft_id = SFgambit.mint(nft.address, 0, stream_rate, seven_days, owner, {"from": creator, "value": 10**18}).return_value
    SFgambit.append(nft.address, 1, stream_rate, seven_days, 1, {"from": creator})

    return _sunft_id

