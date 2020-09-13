pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-value/value.sol";
import "ds-token/token.sol";
import {Vat}     from "dss/vat.sol";
import {Spotter} from "dss/spot.sol";
import {Vow}     from "dss/vow.sol";
import {GemJoin} from "dss/join.sol";

import "./flash.sol";
import "./interface/IFlashMintReceiver.sol";

interface Hevm {
    function warp(uint256) external;
    function store(address,bytes32,bytes32) external;
}

contract TestVat is Vat {
    function mint(address usr, uint rad) public {
        dai[usr] += rad;
    }
}

contract TestVow is Vow {
    constructor(address vat, address flapper, address flopper)
        public Vow(vat, flapper, flopper) {}
    // Total deficit
    function Awe() public view returns (uint) {
        return vat.sin(address(this));
    }
    // Total surplus
    function Joy() public view returns (uint) {
        return vat.dai(address(this));
    }
    // Unqueued, pre-auction debt
    function Woe() public view returns (uint) {
        return sub(sub(Awe(), Sin), Ash);
    }
}

contract TestImmediatePaybackReceiver is IFlashMintReceiver {

    Vat vat;
    DssFlash flash;

    // --- Init ---
    constructor(address vat_, address flash_) public {
        vat = Vat(vat_);
        flash = DssFlash(flash_);
    }

    function execute(uint256 _amount, uint256 _fee, bytes calldata _params) external override {
        // Just pay back the original amount
        vat.move(address(this), address(flash), _amount);
    }

}

contract TestMintAndPaybackReceiver is IFlashMintReceiver {

    TestVat vat;
    DssFlash flash;
    uint256 mintRad;

    // --- Init ---
    constructor(address vat_, address flash_) public {
        vat = TestVat(vat_);
        flash = DssFlash(flash_);
    }

    function setMint(uint256 mintRad_) public {
        mintRad = mintRad_;
    }

    function execute(uint256 _amount, uint256 _fee, bytes calldata _params) external override {
        vat.mint(address(this), mintRad);
        vat.move(address(this), address(flash), _amount + _fee);
    }

}

contract TestMintAndPaybackAllReceiver is IFlashMintReceiver {

    TestVat vat;
    DssFlash flash;
    uint256 mintRad;

    // --- Init ---
    constructor(address vat_, address flash_) public {
        vat = TestVat(vat_);
        flash = DssFlash(flash_);
    }

    function setMint(uint256 mintRad_) public {
        mintRad = mintRad_;
    }

    function execute(uint256 _amount, uint256 _fee, bytes calldata _params) external override {
        vat.mint(address(this), mintRad);
        vat.move(address(this), address(flash), _amount + mintRad);
    }

}

contract TestReentrancyReceiver is IFlashMintReceiver {

    TestVat vat;
    DssFlash flash;
    TestImmediatePaybackReceiver immediatePaybackReceiver;

    // --- Init ---
    constructor(address vat_, address flash_) public {
        vat = TestVat(vat_);
        flash = DssFlash(flash_);
        immediatePaybackReceiver = new TestImmediatePaybackReceiver(vat_, flash_);
    }

    function execute(uint256 _amount, uint256 _fee, bytes calldata _params) external override {
        flash.mint(address(immediatePaybackReceiver), _amount + _fee, _params);
        vat.move(address(this), address(flash), _amount + _fee);
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

    DssFlash flash;

    TestImmediatePaybackReceiver immediatePaybackReceiver;
    TestMintAndPaybackReceiver mintAndPaybackReceiver;
    TestMintAndPaybackAllReceiver mintAndPaybackAllReceiver;
    TestReentrancyReceiver reentrancyReceiver;

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint256(keccak256('hevm cheat code'))));

    bytes32 constant ilk = "gold";

    uint256 constant RATE_ONE_PCT = 10 ** 16;

    function ray(uint wad) internal pure returns (uint) {
        return wad * 10 ** 9;
    }

    function rad(uint wad) internal pure returns (uint) {
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

        immediatePaybackReceiver = new TestImmediatePaybackReceiver(address(vat), address(flash));
        mintAndPaybackReceiver = new TestMintAndPaybackReceiver(address(vat), address(flash));
        mintAndPaybackAllReceiver = new TestMintAndPaybackAllReceiver(address(vat), address(flash));
        reentrancyReceiver = new TestReentrancyReceiver(address(vat), address(flash));
    }

    function test_mint_no_fee_payback () public {
        flash.mint(address(immediatePaybackReceiver), rad(10 ether), msg.data);
    }

    // test mint() for_amount <= 0
    function testFail_mint_zero_amount () public {
        flash.mint(address(immediatePaybackReceiver), 0, msg.data);
    }

    // test mint() for _amount > line
    function testFail_mint_amount_over_line () public {
        flash.mint(address(immediatePaybackReceiver), rad(1001 ether), msg.data);
    }

    // test line == 0 means flash minting is halted
    function testFail_mint_line_zero () public {
        flash.file("line", 0);

        flash.mint(address(immediatePaybackReceiver), rad(10 ether), msg.data);
    }

    // test mint() for _data == 0
    function testFail_mint_empty_data () public {
        flash.mint(address(immediatePaybackReceiver), rad(10 ether), "");
    }

    // test unauthorized suck() reverts
    function testFail_mint_unauthorized_suck () public {
        vat.deny(address(flash));

        flash.mint(address(immediatePaybackReceiver), rad(10 ether), msg.data);
    }

    // test happy path execute() returns vat.dai() == add(_amount, fee)
    //       Make sure we test core system accounting balances before and after.
    function test_mint_with_fee () public {
        flash.file("toll", RATE_ONE_PCT);
        mintAndPaybackReceiver.setMint(rad(10 ether));

        flash.mint(address(mintAndPaybackReceiver), rad(100 ether), msg.data);

        assertEq(vow.Joy(), rad(1 ether));
        assertEq(vat.dai(address(mintAndPaybackReceiver)), rad(9 ether));
    }

    // test execute that return vat.dai() < add(_amount, fee) fails
    function testFail_mint_insufficient_dai () public {
        flash.file("toll", 5 * RATE_ONE_PCT);
        mintAndPaybackAllReceiver.setMint(rad(4 ether));

        flash.mint(address(mintAndPaybackAllReceiver), rad(100 ether), msg.data);
    }

    // test execute that return vat.dai() > add(_amount, fee) fails
    function testFail_mint_too_much_dai () public {
        flash.file("toll", 5 * RATE_ONE_PCT);
        mintAndPaybackAllReceiver.setMint(rad(8 ether));

        flash.mint(address(mintAndPaybackAllReceiver), rad(100 ether), msg.data);
    }

    // test reentrancy disallowed
    function testFail_mint_reentrancy () public {
        flash.mint(address(reentrancyReceiver), rad(100 ether), msg.data);
    }

    // TODO:
    //       - Simple flash mint that uses a DEX
    //           - should test
    //       - Flash mint that moves DAI around in core without DaiJoin.exit()
    //           - should test
    
}
