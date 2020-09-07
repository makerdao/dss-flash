pragma solidity ^0.6.7;

import "./interface/IFlashMintReceiver.sol";

interface VatLike {
    function dai (address) external view returns (uint);
    function move(address src, address dst, uint256 rad) external;
    function heal(uint rad) external;
    function suck(address,address,uint256) external;
}

contract DssFlash is ReentrancyGuard {

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
    uint256 public line;  // Debt Ceiling  [rad]
    uint256 public toll;  // Fee           [wad]

    // --- Init ---
    constructor(address vat_) public {
        vat = VatLike(vat_);
    }

    // --- Math ---
    uint256 constant ONE = 10 ** 18;
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || z / y == x);
        z = z / ONE;
    }

    // --- Administration ---
    function file(bytes32 what, address addr) external auth {
        if (what == "vow") vow = addr;
        else revert("DssFlash/file-unrecognized-param");
    }
    function file(bytes32 what, uint data) external auth {
        if (what == "line") line = data;
        else if (what == "toll") toll = data;
        else revert("DssFlash/file-unrecognized-param");
    }

    // --- Mint ---
    function mint(address _receiver, uint256 _amount, bytes calldata _params) external {
        require(_amount > 0, "DssFlash/amount-zero");
        require(_amount <= line, "DssFlash/ceiling-exceeded");

        IFlashMintReceiver receiver = IFlashMintReceiver(_receiver);

        vat.suck(address(this), address(_receiver), _amount);
        uint256 fee = rmul(_amount, toll);

        receiver.execute(_amount, fee, _params);

        require(vat.dai(address(this)) >= add(_amount, fee), "DssFlash/insufficient-payback");

        vat.heal(_amount);
        vat.move(address(this), vow, fee);
    }

}
