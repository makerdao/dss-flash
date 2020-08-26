pragma solidity ^0.6.7;

interface VatLike {
    function suck(address,address,uint256) external;
}

contract DssFlash {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) external auth { wards[guy] = 1;  }
    function deny(address guy) external auth { wards[guy] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "DssFlash/not-authorized");
        _;
    }

    // --- Data ---
    VatLike public vat;   // CDP Engine
    address public vow;   // Debt Engine

    // --- Init ---
    constructor(address vat_) public {
        vat = VatLike(vat_);
    }

    // --- Math ---
    uint256 constant ONE = 10 ** 27;
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }

    // --- Administration ---
    function file(bytes32 what, address addr) external auth {
        if (what == "vow") vow = addr;
        else revert("Pot/file-unrecognized-param");
    }

    // --- Mint ---
    function mint(uint256 rad) external {
        vat.suck(address(vow), address(msg.sender), rad);
    }

}
