const { web3tx, toWad, wad4human } = require("@decentral.ee/web3-helpers");
const web3 = require('web3')
const { expect } = require("chai");

const deployFramework = require("@superfluid-finance/ethereum-contracts/scripts/deploy-framework");
const deployTestToken = require("@superfluid-finance/ethereum-contracts/scripts/deploy-test-token");
const deploySuperToken = require("@superfluid-finance/ethereum-contracts/scripts/deploy-super-token");
const SuperfluidSDK = require("@superfluid-finance/js-sdk");

const traveler = require("ganache-time-traveler");
const { isCallTrace } = require("hardhat/internal/hardhat-network/stack-traces/message-trace");
const TEST_TRAVEL_TIME = 3600 * 2; // 1 hours

describe("StreamUnlockableNFTFactory", () => {
    const errorHandler = (err) => {
        if (err) throw err;
    };

    const names = ["Admin", "Alice", "Bob"];

    let sf;
    let dai;
    let daix;
    let app;
    const u = {}; // object with all users
    const aliases = {};

    before(async function () {
        //process.env.RESET_SUPERFLUID_FRAMEWORK = 1;
        const [owner, alice, bob] = await ethers.getSigners();
        await deployFramework(errorHandler, {
            web3,
            from: owner.address,
        });
    });

    beforeEach(async function () {
        const [owner, alice, bob] = await ethers.getSigners();
        const accounts = [owner, alice, bob] ;
        await deployTestToken(errorHandler, [":", "fDAI"], {
            web3,
            from: owner.address,
        });


        sf = new SuperfluidSDK.Framework({
            web3,
            version: "test",
            tokens: ["fDAI"],
        });
        await sf.initialize();
        daix = sf.tokens.fDAIx;
        dai = await sf.contracts.TestToken.at(await sf.tokens.fDAI.address);
        for (var i = 0; i < names.length; i++) {
            u[names[i].toLowerCase()] = sf.user({
                address: accounts[i].address,
                token: daix.address,
            });
            u[names[i].toLowerCase()].alias = names[i];
            aliases[u[names[i].toLowerCase()].address] = names[i];
        }

        for (const [, user] of Object.entries(u)) {
            if (user.alias === "App") return;
            await web3tx(dai.mint, `${user.alias} mints many dai`)(
                user.address,
                toWad(100000000),
                {
                    from: user.address,
                }
            );
            await web3tx(dai.approve, `${user.alias} approves daix`)(
                daix.address,
                toWad(100000000),
                {
                    from: user.address,
                }
            );
        }

        console.log("Admin:", u.admin.address);
        console.log("Host:", sf.host.address);
        console.log("CFA:",sf.agreements.cfa.address);
        console.log("DAIx",daix.address);
    
        const StreamUnlockableNFTFactory = await ethers.getContractFactory("StreamUnlockableNFTFactory");
        app = await StreamUnlockableNFTFactory.deploy(
            daix.address,
            10**18
        );
        u.app = sf.user({ address: app.address, token: daix.address});
        u.app.alias = "App";
        await checkBalance(u.app);     
        
        // await web3tx(
        //     sf.host.callAgreement,
        //     "Alice approves subscription to the app"
        // )(
        //     sf.agreements.cfa.address,
        //     sf.agreements.cfa.contract.methods
        //         .approveSubscription(ethx.address, app.address, 0, "0x")
        //         .encodeABI(),
        //     "0x", // user data
        //     {
        //         from: u.alice.address
        //     }
        // );
        // await web3tx(
        //     sf.host.callAgreement,
        //     "Bob approves subscription to the app"
        // )(
        //     sf.agreements.cfa.address,
        //     sf.agreements.cfa.contract.methods
        //         .approveSubscription(ethx.address, app.address, 0, "0x")
        //         .encodeABI(),
        //     "0x", // user data
        //     {
        //         from: u.bob.address
        //     }
        // );

    });

    describe("SNUFT", async function () {
        this.timeout(100000);

        it("Call deposit on stream initiation callback", async function() {
            
            
            
            expect((100).to.equal(100),"not equal!!")

        });
    });
    


});

