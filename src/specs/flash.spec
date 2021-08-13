// flash.spec

// certoraRun src/flash.sol:DssFlash --verify DssFlash:src/specs/flash.spec --rule_sanity --solc_args "['--optimize','--optimize-runs','200']"

methods {
    wards(address) returns (uint256) envfree
    vat() returns (address) envfree
    daiJoin() returns (address) envfree
    dai() returns (address) envfree
    max() returns (uint256) envfree
    CALLBACK_SUCCESS() returns (bytes32) envfree
    CALLBACK_SUCCESS_VAT_DAI() returns (bytes32) envfree
    maxFlashLoan() returns (uint256) envfree
    flashFee() returns (uint256) envfree
}
