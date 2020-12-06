pragma solidity ^0.6.7;

import "../flash.sol";
import "../interface/IFlashLoanReceiver.sol";

abstract contract FlashLoanReceiverBase is IFlashLoanReceiver {

    DssFlash public flash;
    VatLike public vat;

    // --- Init ---
    constructor(address _flash) public {
        flash = DssFlash(_flash);
        vat = flash.vat();
    }

    // --- Math ---
    function rad(uint wad) internal pure returns (uint) {
        return wad * 10 ** 27;
    }
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    // --- Helper Functions ---
    function payBackFunds(uint _amount, uint _fee) internal {
        vat.move(address(this), address(flash), rad(add(_amount, _fee)));
    }

}