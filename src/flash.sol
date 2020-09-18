pragma solidity ^0.6.7;

import "./interface/IFlashMintReceiver.sol";

interface VatLike {
    function dai (address) external view returns (uint);
    function move(address src, address dst, uint256 rad) external;
    function heal(uint rad) external;
    function suck(address,address,uint256) external;
}

contract DssFlash {

    // --- Auth ---
    mapping (address => uint) public wards;
    function rely(address guy) external auth { wards[guy] = 1; }
    function deny(address guy) external auth { wards[guy] = 0; }
    modifier auth {
        require(wards[msg.sender] == 1, "DssFlash/not-authorized");
        _;
    }

    // --- Data ---
    VatLike public  vat;    // CDP Engine
    address public  vow;    // Debt Engine
    uint256 public  line;   // Debt Ceiling  [rad]
    uint256 public  toll;   // Fee           [wad]
    uint256 private locked; // reentrancy guard

    modifier lock {
        require(locked == 1, "DssFlash/reentrancy-guard");
        locked = 2;
        _;
        locked = 1;
    }

    // --- Init ---
    constructor(address vat_) public {
        wards[msg.sender] = 1;
        vat = VatLike(vat_);
        locked = 1;
    }

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = x * y;
        require(y == 0 || z / y == x);
        z = z / WAD;
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
    function mint(
        address _receiver,      // address of conformant IFlashMintReceiver
        uint256 _amount,        // amount to flash mint [rad]
        bytes calldata _data    // calldata
    ) external lock {
        require(_amount > 0, "DssFlash/amount-zero");
        require(_amount <= line, "DssFlash/ceiling-exceeded");
        require(_data.length > 0, "DssFlash/empty-calldata");

        IFlashMintReceiver receiver = IFlashMintReceiver(_receiver);

        vat.suck(address(this), _receiver, _amount);
        uint256 fee = rmul(_amount, toll);
        uint256 bal = vat.dai(address(this));

        receiver.execute(_amount, fee, _data);

        require(vat.dai(address(this)) == add(bal, add(_amount, fee)), "DssFlash/invalid-payback");

        vat.heal(_amount);
        vat.move(address(this), vow, fee);
    }

}
