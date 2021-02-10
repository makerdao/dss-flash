pragma solidity ^0.6.7;

interface IVatDaiFlashLoanReceiver {

    /**
    * Must transfer _amount + _fee back to the flash loan contract when complete.
    */
    function onVatDaiFlashLoan(address _sender, uint256 _amount, uint256 _fee, bytes calldata _params) external;

}