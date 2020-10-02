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
    function rely(address guy) external auth { emit Rely(guy); wards[guy] = 1; }
    function deny(address guy) external auth { emit Deny(guy); wards[guy] = 0; }
    mapping (address => uint256) public wards;
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

    // --- Events ---
    event Rely(address indexed usr);
    event Deny(address indexed usr);
    event File(bytes32 indexed what, uint256 data);
    event File(bytes32 indexed what, address data);
    event Mint(address indexed receiver, uint256 amount, uint256 fee);

    modifier lock {
        locked += 1;
        uint256 localLocked = locked;
        _;
        require(localLocked == locked, "DssFlash/reentrancy-guard");
    }

    // --- Init ---
    constructor(address _vat) public {
        wards[msg.sender] = 1;
        vat = VatLike(_vat);
        locked = 1;
    }

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    function rad(uint256 wad) internal pure returns (uint256) {
        return wad * 10 ** 27;
    }
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }
    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x * y;
        require(y == 0 || z / y == x);
        z = z / WAD;
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
        address _receiver,      // address of conformant IFlashMintReceiver
        uint256 _amount,        // amount to flash mint [wad]
        bytes calldata _data    // arbitrary data to pass to the _receiver
    ) external lock {
        uint256 arad = rad(_amount);

        require(arad > 0, "DssFlash/amount-zero");
        require(arad <= line, "DssFlash/ceiling-exceeded");

        IFlashMintReceiver receiver = IFlashMintReceiver(_receiver);

        vat.suck(address(this), _receiver, arad);
        uint256 fee = wmul(_amount, toll);
        uint256 bal = vat.dai(address(this));

        receiver.execute(_amount, fee, _data);

        require(vat.dai(address(this)) == add(bal, rad(add(_amount, fee))), "DssFlash/invalid-payback");

        vat.heal(arad);
        vat.move(address(this), vow, rad(fee));
        emit Mint(_receiver, _amount, fee);
    }

}
