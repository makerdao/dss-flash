pragma solidity ^0.6.7;

import "ds-test/test.sol";
import "ds-value/value.sol";
import "ds-token/token.sol";
import {Vat}     from "dss/vat.sol";
import {Spotter} from "dss/spot.sol";
import {Vow}     from "dss/vow.sol";
import {GemJoin} from "dss/join.sol";

import "./flash.sol";

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

    // CHEAT_CODE = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D
    bytes20 constant CHEAT_CODE =
        bytes20(uint160(uint256(keccak256('hevm cheat code'))));

    bytes32 constant ilk = "gold";

    function ray(uint wad) internal pure returns (uint) {
        return wad * 10 ** 9;
    }

    function rad(uint wad) internal pure returns (uint) {
        return wad * 10 ** 27;
    }

    function setUp() public {
        hevm = Hevm(address(CHEAT_CODE));

        flash = new DssFlash(address(vat));

        me = address(this);

        vat = new TestVat();
        vat = vat;

        spot = new Spotter(address(vat));
        vat.rely(address(spot));

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
    }

    // TODO: Make a few reference implementations of IFlashMintReceiver
    //       - Mock IFlashMintReceiver adapter
    //       - Simple flash mint that uses a DEX
    //           - should test
    //       - Flash mint that moves DAI around in core without DaiJoin.exit()
    //           - should test

    // TODO: test mint() for_amount <= 0

    // TODO: test mint() for _amount > line

    // TODO: test line == 0 means flash minting is halted

    // TODO: test mint() for _data == 0

    // TODO: test unauthorized suck() reverts

    // TODO: test happy path execute() returns vat.dai() == add(_amount, fee)
    //       Make sure we test core system accounting balances before and after.

    // TODO: test execute that return vat.dai() < add(_amount, fee) fails

    // TODO: test execute that return vat.dai() > add(_amount, fee) fails

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
