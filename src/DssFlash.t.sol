pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./DssFlash.sol";

contract DssFlashTest is DSTest {
    DssFlash flash;

    function setUp() public {
        flash = new DssFlash();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}
