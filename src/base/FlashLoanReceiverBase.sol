// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2021 Dai Foundation
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.6.12;

import "../flash.sol";
import "../interface/IVatDaiFlashLoanReceiver.sol";
import "../interface/IERC3156FlashBorrower.sol";

abstract contract FlashLoanReceiverBase is IVatDaiFlashLoanReceiver, IERC3156FlashBorrower {

    DssFlash public flash;

    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    bytes32 public constant CALLBACK_SUCCESS_VAT_DAI = keccak256("IVatDaiFlashLoanReceiver.onVatDaiFlashLoan");

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
    function approvePayback(uint256 amount) internal {
        // Lender takes back the dai as per ERC 3156 spec
        flash.dai().approve(address(flash), amount);
    }
    function payBackVatDai(uint256 amount) internal {
        // Lender takes back the dai as per ERC 3156 spec
        flash.vat().move(address(this), address(flash), amount);
    }

}
