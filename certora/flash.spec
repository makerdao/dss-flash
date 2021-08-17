// flash.spec

// certoraRun src/flash.sol:DssFlash --verify DssFlash:certora/flash.spec --rule_sanity --solc_args "['--optimize','--optimize-runs','200']"

methods {
    wards(address) returns (uint256) envfree
    vat() returns (address) envfree
    daiJoin() returns (address) envfree
    dai() returns (address) envfree
    max() returns (uint256) envfree
    CALLBACK_SUCCESS() returns (bytes32) envfree
    CALLBACK_SUCCESS_VAT_DAI() returns (bytes32) envfree
    maxFlashLoan(address) returns (uint256) envfree
    flashFee(address, uint256) returns (uint256) envfree
}

ghost lockedGhost() returns uint256;

hook Sstore locked uint256 n_locked STORAGE {
    havoc lockedGhost assuming lockedGhost@new() == n_locked;
}

hook Sload uint256 value locked STORAGE {
    require lockedGhost() == value;
}

// Verify that wards behaves correctly on rely
rule rely(address usr) {
    env e;

    rely(e, usr);

    assert(wards(usr) == 1, "Rely did not set the wards as expected");
}

// Verify revert rules on rely
rule rely_revert(address usr) {
    env e;

    uint256 ward = wards(e.msg.sender);

    rely@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;

    assert(revert1 => lastReverted, "Sending ETH did not revert");
    assert(revert2 => lastReverted, "Lack of auth did not revert");
    assert(lastReverted => revert1 || revert2, "Revert rules are not covering all the cases");
}

// Verify that wards behaves correctly on deny
rule deny(address usr) {
    env e;

    deny(e, usr);

    assert(wards(usr) == 0, "Deny did not set the wards as expected");
}

// Verify revert rules on deny
rule deny_revert(address usr) {
    env e;

    uint256 ward = wards(e.msg.sender);

    deny@withrevert(e, usr);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;

    assert(revert1 => lastReverted, "Sending ETH did not revert");
    assert(revert2 => lastReverted, "Lack of auth did not revert");
    assert(lastReverted => revert1 || revert2, "Revert rules are not covering all the cases");
}

// Verify that max behave correctly on file
rule file(bytes32 what, uint256 data) {
    env e;
    
    file(e, what, data);

    assert(max() == data, "File did not set max as expected");
}

// Verify revert rules on file
rule file_revert(bytes32 what, uint256 data) {
    env e;

    uint256 ward = wards(e.msg.sender);

    file@withrevert(e, what, data);

    bool revert1 = e.msg.value > 0;
    bool revert2 = ward != 1;
    bool revert3 = what != 0x6d61780000000000000000000000000000000000000000000000000000000000; // what != "max"
    bool revert4 = data > 10 ^ 45;

    assert(revert1 => lastReverted, "Sending ETH did not revert");
    assert(revert2 => lastReverted, "Lack of auth did not revert");
    assert(revert3 => lastReverted, "File unrecognized param did not revert");
    assert(revert4 => lastReverted, "Max too large did not revert");

    assert(lastReverted => revert1 || revert2 || revert3 || revert4, "Revert rules are not covering all the cases");
}

// Verify that only unlocked dai has a max flash loan
rule maxFlashLoan(address token) {
    uint256 locked = lockedGhost();

    uint256 expectedMax = locked == 0 && token == dai() ? max() : 0;

    uint256 actualMax = maxFlashLoan(token);

    assert(actualMax == expectedMax, "Max flash loan is invalid");
}

// Verify flash fee always returns 0
rule flashFee(address token, uint256 amount) {
    uint256 fee = flashFee(token, amount);

    assert(fee == 0, "Fee should always be 0");
}

// Verify revert rules on flashFee
rule flashFee_revert(address token, uint256 amount) {
    address _dai = dai();

    flashFee@withrevert(token, amount);

    bool revert1 = token != _dai;

    assert(revert1 => lastReverted, "Non-dai token did not revert");

    assert(lastReverted => revert1, "Revert rules are not covering all the cases");
}
