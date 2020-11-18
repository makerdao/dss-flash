pragma solidity ^0.6.7;

import "./interface/IFlashMintReceiver.sol";

interface VatLike {
    function dai(address) external view returns (uint256);
    function move(address src, address dst, uint256 rad) external;
    function heal(uint256 rad) external;
    function suck(address,address,uint256) external;
}

contract DssFlash {

    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address guy) external auth { wards[guy] = 1; emit Rely(guy);}
    function deny(address guy) external auth { wards[guy] = 0; emit Deny(guy);}
    modifier auth {
        require(wards[msg.sender] == 1, "DssFlash/not-authorized");
        _;
    }

    // --- Data ---
    VatLike public  vat;    // CDP Engine
    address public  vow;    // Debt Engine
    uint256 public  line;   // Debt Ceiling     [rad]
    uint256 public  toll;   // Fee              [wad]
    uint256 private locked; // Reentrancy guard

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);
    event Mint(address indexed receiver, uint256 amount, uint256 fee);

    modifier lock {
        require(locked == 0, "DssFlash/reentrancy-guard");
        locked = 1;
        _;
        locked = 0;
    }

    // --- Init ---
    constructor(address _vat) public {
        wards[msg.sender] = 1;
        vat = VatLike(_vat);
    }

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    function rad(uint256 wad) internal pure returns (uint256) {
        return mul(wad, 10 ** 27);
    }
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // --- Administration ---
    function file(bytes32 what, address addr) external auth {
        if (what == "vow") vow = addr;
        else revert("DssFlash/file-unrecognized-param");
        emit File(what, addr);
    }
    function file(bytes32 what, uint256 data) external auth {
        if (what == "line") line = data;
        else if (what == "toll") toll = data;
        else revert("DssFlash/file-unrecognized-param");
        emit File(what, data);
    }

    // --- Mint ---
    function mint(
        address bolt,         // Address of conformant IFlashMintReceiver
        uint256 wad,          // Amount to flash mint [wad]
        bytes calldata _data  // Arbitrary data to pass to the bolt
    ) external lock {
        uint256 dai = rad(wad);

        require(dai > 0,     "DssFlash/amount-zero");
        require(dai <= line, "DssFlash/ceiling-exceeded");

        vat.suck(address(this), bolt, dai);

        uint256 fee = mul(wad, toll) / WAD;
        uint256 bal = vat.dai(address(this));

        IFlashMintReceiver(bolt).execute(wad, fee, _data);

        uint256 due = rad(fee);
        require(vat.dai(address(this)) == add(bal, add(dai, due)), "DssFlash/invalid-payback");

        vat.heal(dai);
        vat.move(address(this), vow, due);
        emit Mint(bolt, wad, fee);
    }
}
