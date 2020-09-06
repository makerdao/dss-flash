pragma solidity ^0.6.7;

interface IFlashMintReceiver {

    function execute(uint256 _amount, uint256 _fee, bytes calldata _params) external;

}