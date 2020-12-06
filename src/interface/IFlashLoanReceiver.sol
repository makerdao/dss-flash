pragma solidity ^0.6.7;

interface IFlashLoanReceiver {

    /**
    * Must transfer _amount + _fee back to the flash loan contract when complete.
    */
    function onFlashLoan(address _sender, uint256 _amount, uint256 _fee, bytes calldata _params) external;

}