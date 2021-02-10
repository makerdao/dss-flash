pragma solidity ^0.6.7;

import "../flash.sol";
import "../interface/IVatDaiFlashLoanReceiver.sol";
import "../interface/IERC3156FlashBorrower.sol";

abstract contract FlashLoanReceiverBase is IVatDaiFlashLoanReceiver, IERC3156FlashBorrower {

    DssFlash public flash;

    bytes32 public constant RETURN_HASH = keccak256("ERC3156FlashBorrower.onFlashLoan");
    bytes32 public constant RETURN_HASH_VAT_DAI = keccak256("IVatDaiFlashLoanReceiver.onVatDaiFlashLoan");

    // --- Init ---
    constructor(address _flash) public {
        flash = DssFlash(_flash);
    }

    // --- Math ---
    uint256 constant RAY = 10 ** 27;
    function rad(uint wad) internal pure returns (uint) {
        return mul(wad, RAY);
    }
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // --- Helper Functions ---
    function payBack(uint256 amount) internal {
        flash.dai().transfer(address(flash), amount);
    }
    function payBackVatDai(uint256 amount) internal {
        flash.vat().move(address(this), address(flash), amount);
    }

}