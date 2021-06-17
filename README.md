# dss-flash

Flash Mint Module for the Maker protocol - an implementation of [MIP25](https://forum.makerdao.com/t/mip25-flash-mint-module/4400). This module conforms to the [ERC3156 spec](https://eips.ethereum.org/EIPS/eip-3156) so please read this over to get a firm idea of the considerations/risks.

## Usage

Since this module conforms to the ERC3156 spec, you can just use the reference borrower implementation from the spec:

```
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IERC3156FlashBorrower.sol";
import "./interfaces/IERC3156FlashLender.sol";

contract FlashBorrower is IERC3156FlashBorrower {
    enum Action {NORMAL, OTHER}

    IERC3156FlashLender lender;

    constructor (
        IERC3156FlashLender lender_
    ) {
        lender = lender_;
    }

    /// @dev ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns(bool) {
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower: Untrusted loan initiator"
        );
        (Action action) = abi.decode(data, (Action));
        if (action == Action.NORMAL) {
            // do one thing
        } else if (action == Action.OTHER) {
            // do another
        }
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    /// @dev Initiate a flash loan
    function flashBorrow(
        address token,
        uint256 amount
    ) public {
        bytes memory data = abi.encode(Action.NORMAL);
        uint256 _allowance = IERC20(token).allowance(address(this), address(lender));
        uint256 _fee = lender.flashFee(token, amount);
        uint256 _repayment = amount + _fee;
        IERC20(token).approve(address(lender), _allowance + _repayment);
        lender.flashLoan(this, token, amount, data);
    }
}
```

## Vat Dai

It may be that users are interested in moving dai around in the internal vat balances. Instead of wasting gas by minting/burning ERC20 dai you can instead use the vat dai flash mint function to short cut this.

The vat dai version of flash mint is roughly the same as the ERC20 dai version with a few caveats:

### Function Signature

`vatDaiFlashLoan(IVatDaiFlashBorrower receiver, uint256 amount, bytes calldata data)`

vs

`flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)`

Notice that no token is required because it is assumed to be vat dai. Also, the `amount` is in RADs and not in WADs.

### Approval Mechanism

ERC3156 specifies using a token approval to approve the amount to repay to the lender. Unfortunately vat dai does not have a way to specify delegation amounts, so instead of giving the flash mint module full rights to withdraw any amount of vat dai we have instead opted to have the receiver push the balance owed at the end of the transaction.

### Example

Here is an example similar to the one above to showcase the differences:

```
pragma solidity ^0.6.12;

import "dss-interfaces/dss/VatAbstract.sol";

import "./interfaces/IERC3156FlashLender.sol";
import "./interfaces/IVatDaiFlashBorrower.sol";

contract FlashBorrower is IVatDaiFlashBorrower {
    enum Action {NORMAL, OTHER}

    VatAbstract vat;
    IVatDaiFlashLender lender;

    constructor (
        VatAbstract vat_,
        IVatDaiFlashLender lender_
    ) public {
        vat = vat_;
        lender = lender_;
    }

    /// @dev Vat Dai Flash loan callback
    function onVatDaiFlashLoan(
        address initiator,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override returns(bool) {
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower: Untrusted loan initiator"
        );
        (Action action) = abi.decode(data, (Action));
        if (action == Action.NORMAL) {
            // do one thing
        } else if (action == Action.OTHER) {
            // do another
        }

        // Repay the loan amount + fee
        // Be sure not to overpay as there are no safety guards for this
        vat.move(address(this), address(lender), amount + fee);

        return keccak256("VatDaiFlashBorrower.onVatDaiFlashLoan");
    }

    /// @dev Initiate a flash loan
    function vatDaiFlashBorrow(
        uint256 amount
    ) public {
        bytes memory data = abi.encode(Action.NORMAL);
        lender.flashLoan(this, amount, data);
    }
}

```

## Deployment

To deploy this contract run the following commands:

`make deploy-mainnet` for mainnet deployment

`make deploy-kovan` for kovan deployment

Deployed Kovan address: `0x5aA1323f61D679E52a90120DFDA2ed1A76E4475A`
