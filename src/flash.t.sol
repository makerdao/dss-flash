pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-value/value.sol";
import "ds-token/token.sol";
import {Vat}              from "dss/vat.sol";
import {Spotter}          from "dss/spot.sol";
import {Vow}              from "dss/vow.sol";
import {GemJoin, DaiJoin} from "dss/join.sol";
import {Dai}              from "dss/dai.sol";

import "./flash.sol";
import "./interface/IFlashMintReceiver.sol";
import "./base/FlashMintReceiverBase.sol";

interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
}

contract TestVat is Vat {
    function mint(address usr, uint256 rad) public {
        dai[usr] += rad;
    }
}

contract TestVow is Vow {
    constructor(address vat, address flapper, address flopper)
        public Vow(vat, flapper, flopper) {}
    // Total deficit
    function Awe() public view returns (uint256) {
        return vat.sin(address(this));
    }
    // Total surplus
    function Joy() public view returns (uint256) {
        return vat.dai(address(this));
    }
    // Unqueued, pre-auction debt
    function Woe() public view returns (uint256) {
        return sub(sub(Awe(), Sin), Ash);
    }
}

contract TestImmediatePaybackReceiver is FlashMintReceiverBase {

    // --- Init ---
    constructor(address _flash, address _vat) FlashMintReceiverBase(_flash, _vat) public {
    }

    function onFlashMint(uint256 _amount, uint256 _fee, bytes calldata) external override {
        // Just pay back the original amount
        payBackFunds(_amount, _fee);
    }

}

contract TestMintAndPaybackReceiver is FlashMintReceiverBase {

    uint256 mint;

    // --- Init ---
    constructor(address _flash, address _vat) FlashMintReceiverBase(_flash, _vat) public {
    }

    function setMint(uint256 _mint) public {
        mint = _mint;
    }

    function onFlashMint(uint256 _amount, uint256 _fee, bytes calldata) external override {
        TestVat _vat = TestVat(address(vat));
        _vat.mint(address(this), rad(mint));

        payBackFunds(_amount, _fee);
    }

}

contract TestMintAndPaybackAllReceiver is FlashMintReceiverBase {

    uint256 mint;

    // --- Init ---
    constructor(address _flash, address _vat) FlashMintReceiverBase(_flash, _vat) public {
    }

    function setMint(uint256 _mint) public {
        mint = _mint;
    }

    function onFlashMint(uint256 _amount, uint256, bytes calldata) external override {
        TestVat _vat = TestVat(address(vat));
        _vat.mint(address(this), rad(mint));

        vat.move(address(this), address(flash), rad(add(_amount, mint)));
    }

}

contract TestMintAndPaybackDataReceiver is FlashMintReceiverBase {

    // --- Init ---
    constructor(address _flash, address _vat) FlashMintReceiverBase(_flash, _vat) public {
    }

    function onFlashMint(uint256 _amount, uint256 _fee, bytes calldata _data) external override {
        (uint256 mintAmount) = abi.decode(_data, (uint256));
        TestVat _vat = TestVat(address(vat));
        _vat.mint(address(this), rad(mintAmount));

        payBackFunds(_amount, _fee);
    }

}

contract TestReentrancyReceiver is FlashMintReceiverBase {

    TestImmediatePaybackReceiver immediatePaybackReceiver;

    // --- Init ---
    constructor(address _flash, address _vat) FlashMintReceiverBase(_flash, _vat) public {
        immediatePaybackReceiver = new TestImmediatePaybackReceiver(_flash, _vat);
    }

    function onFlashMint(uint256 _amount, uint256 _fee, bytes calldata _data) external override {
        flash.mint(address(immediatePaybackReceiver), _amount + _fee, _data);

        payBackFunds(_amount, _fee);
    }

}

contract TestDEXTradeReceiver is FlashMintReceiverBase {

    Dai dai;
    DaiJoin daiJoin;
    DSToken gold;
    GemJoin gemA;
    bytes32 ilk;

    // --- Init ---
    constructor(address flash_, address vat_, address dai_, address daiJoin_, address gold_, address gemA_, bytes32 ilk_) FlashMintReceiverBase(flash_, vat_) public {
        dai = Dai(dai_);
        daiJoin = DaiJoin(daiJoin_);
        gold = DSToken(gold_);
        gemA = GemJoin(gemA_);
        ilk = ilk_;
    }

    function onFlashMint(uint256 _amount, uint256 _fee, bytes calldata) external override {
        address me = address(this);
        uint256 totalDebt = _amount + _fee;
        uint256 goldAmount = totalDebt * 3;
        TestVat _vat = TestVat(address(vat));

        _vat.hope(address(daiJoin));
        daiJoin.exit(me, _amount);

        // Perform a "trade"
        dai.burn(me, _amount);
        gold.mint(me, goldAmount);

        // Mint some more dai to repay the original loan
        gold.approve(address(gemA));
        gemA.join(me, goldAmount);
        _vat.frob(ilk, me, me, me, int256(goldAmount), int256(totalDebt));

        payBackFunds(_amount, _fee);
    }

}

contract DssFlashTest is DSTest {
    Hevm hevm;

    address me;

    TestVat vat;
    Spotter spot;
    TestVow vow;
    DSValue pip;
    GemJoin gemA;
    DSToken gold;
    DaiJoin daiJoin;
    Dai dai;

    DssFlash flash;

    TestImmediatePaybackReceiver immediatePaybackReceiver;
    TestMintAndPaybackReceiver mintAndPaybackReceiver;
    TestMintAndPaybackAllReceiver mintAndPaybackAllReceiver;
    TestMintAndPaybackDataReceiver mintAndPaybackDataReceiver;
    TestReentrancyReceiver reentrancyReceiver;
    TestDEXTradeReceiver dexTradeReceiver;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint256(keccak256('hevm cheat code'))));

    bytes32 constant ilk = "gold";

    uint256 constant RATE_ONE_PCT = 10 ** 16;

    function ray(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 9;
    }

    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        me = address(this);

        vat = new TestVat();
        vat = vat;

        spot = new Spotter(address(vat));
        vat.rely(address(spot));

        flash = new DssFlash(address(vat));

        vow = new TestVow(address(vat), address(0), address(0));

        gold = new DSToken("GEM");
        gold.mint(1000 ether);

        vat.init(ilk);

        gemA = new GemJoin(address(vat), ilk, address(gold));
        vat.rely(address(gemA));
        gold.approve(address(gemA));
        gemA.join(me, 1000 ether);

        dai = new Dai(0);
        daiJoin = new DaiJoin(address(vat), address(dai));
        vat.rely(address(daiJoin));
        dai.rely(address(daiJoin));

        pip = new DSValue();
        pip.poke(bytes32(uint256(5 ether))); // Spot = $2.5

        spot.file(ilk, bytes32("pip"), address(pip));
        spot.file(ilk, bytes32("mat"), ray(2 ether));
        spot.poke(ilk);

        vat.file(ilk, "line", rad(1000 ether));
        vat.file("Line",      rad(1000 ether));

        gold.approve(address(vat));

        assertEq(vat.gem(ilk, me), 1000 ether);
        assertEq(vat.dai(me), 0);
        vat.frob(ilk, me, me, me, 40 ether, 100 ether);
        assertEq(vat.gem(ilk, me), 960 ether);
        assertEq(vat.dai(me), rad(100 ether));

        // Basic auth and 1000 ether debt ceiling
        flash.file("vow", address(vow));
        flash.file("line", rad(1000 ether));
        vat.rely(address(flash));

        immediatePaybackReceiver = new TestImmediatePaybackReceiver(address(flash), address(vat));
        mintAndPaybackReceiver = new TestMintAndPaybackReceiver(address(flash), address(vat));
        mintAndPaybackAllReceiver = new TestMintAndPaybackAllReceiver(address(flash), address(vat));
        mintAndPaybackDataReceiver = new TestMintAndPaybackDataReceiver(address(flash), address(vat));
        reentrancyReceiver = new TestReentrancyReceiver(address(flash), address(vat));
        dexTradeReceiver = new TestDEXTradeReceiver(address(flash), address(vat), address(dai), address(daiJoin), address(gold), address(gemA), ilk);
        dai.rely(address(dexTradeReceiver));
    }

    function test_mint_no_fee_payback () public {
        flash.mint(address(immediatePaybackReceiver), 10 ether, "");
    }

    // test mint() for _amount == 0
    function test_mint_zero_amount () public {
        flash.mint(address(immediatePaybackReceiver), 0, "");
    }

    // test mint() for _amount > line
    function testFail_mint_amount_over_line () public {
        flash.mint(address(immediatePaybackReceiver), 1001 ether, "");
    }

    // test line == 0 means flash minting is halted
    function testFail_mint_line_zero () public {
        flash.file("line", 0);

        flash.mint(address(immediatePaybackReceiver), 10 ether, "");
    }

    // test unauthorized suck() reverts
    function testFail_mint_unauthorized_suck () public {
        vat.deny(address(flash));

        flash.mint(address(immediatePaybackReceiver), 10 ether, "");
    }

    // test happy path onFlashMint() returns vat.dai() == add(_amount, fee)
    //       Make sure we test core system accounting balances before and after.
    function test_mint_with_fee () public {
        flash.file("toll", RATE_ONE_PCT);
        mintAndPaybackReceiver.setMint(10 ether);

        flash.mint(address(mintAndPaybackReceiver), 100 ether, "");

        assertEq(vow.Joy(), rad(1 ether));
        assertEq(vat.dai(address(mintAndPaybackReceiver)), rad(9 ether));
    }

    // Test mint doesn't fail when contract already has a Dai balance
    function test_preexisting_dai_in_flash () public {
        flash.file("toll", RATE_ONE_PCT);

        // Move some collateral to the flash so it preexists the loan
        vat.move(address(this), address(flash), rad(1 ether));

        mintAndPaybackReceiver.setMint(10 ether);

        flash.mint(address(mintAndPaybackReceiver), 100 ether, "");

        assertEq(vow.Joy(), rad(1 ether));
        assertEq(vat.dai(address(mintAndPaybackReceiver)), rad(9 ether));
        // Ensure pre-existing amount remains in flash
        assertEq(vat.dai(address(flash)), rad(1 ether));
    }

    // test onFlashMint that return vat.dai() < add(_amount, fee) fails
    function testFail_mint_insufficient_dai () public {
        flash.file("toll", 5 * RATE_ONE_PCT);
        mintAndPaybackAllReceiver.setMint(4 ether);

        flash.mint(address(mintAndPaybackAllReceiver), 100 ether, "");
    }

    // test onFlashMint that return vat.dai() > add(_amount, fee) fails
    function testFail_mint_too_much_dai () public {
        flash.file("toll", 5 * RATE_ONE_PCT);
        mintAndPaybackAllReceiver.setMint(8 ether);

        flash.mint(address(mintAndPaybackAllReceiver), 100 ether, "");
    }

    // test that data sends properly
    function test_mint_data () public {
        flash.file("toll", 5 * RATE_ONE_PCT);
        uint256 mintAmount = 8 ether;

        flash.mint(address(mintAndPaybackDataReceiver), 100 ether, abi.encodePacked(mintAmount));

        assertEq(vow.Joy(), rad(5 ether));
        assertEq(vat.dai(address(mintAndPaybackDataReceiver)), rad(3 ether));
    }

    // test reentrancy disallowed
    function testFail_mint_reentrancy () public {
        flash.mint(address(reentrancyReceiver), 100 ether, "");
    }

    // test trading flash minted dai for gold and minting more dai
    function test_dex_trade () public {
        // Set the owner temporarily to allow the receiver to mint
        gold.setOwner(address(dexTradeReceiver));

        flash.mint(address(dexTradeReceiver), 100 ether, "");
    }

}
