pragma solidity ^0.6.7;

import "../flash.sol";
import "../interface/IFlashMintReceiver.sol";

abstract contract FlashMintReceiverBase is IFlashMintReceiver {

    DssFlash public flash;
    VatLike public vat;

    // --- Init ---
    constructor(address _flash, address _vat) public {
        flash = DssFlash(_flash);
        vat = VatLike(_vat);
    }

    // --- Math ---
    function rad(uint wad) internal pure returns (uint) {
        return wad * 10 ** 27;
    }
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    // --- Transaction ---
    function completeTransaction(uint _amount, uint _fee) internal {
        vat.move(address(this), address(flash), rad(add(_amount, _fee)));
    }

}