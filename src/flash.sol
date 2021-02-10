pragma solidity ^0.6.7;

import "./interface/IERC3156FlashLender.sol";
import "./interface/IERC3156FlashBorrower.sol";

interface VatLike {
    function dai(address) external view returns (uint256);
    function move(address src, address dst, uint256 rad) external;
    function heal(uint256 rad) external;
    function suck(address,address,uint256) external;
}

contract DssFlash is IERC3156FlashLender {

    // --- Auth ---
    function rely(address guy) external auth { emit Rely(guy); wards[guy] = 1; }
    function deny(address guy) external auth { emit Deny(guy); wards[guy] = 0; }
    mapping (address => uint256) public wards;
    modifier auth {
        require(wards[msg.sender] == 1, "DssFlash/not-authorized");
        _;
    }

    // --- Data ---
    VatLike public immutable  vat;    // CDP Engine
    address public immutable  vow;    // Debt Engine
    address public immutable  dai;    // Dai
    uint256 public  line;             // Debt Ceiling  [rad]
    uint256 public  toll;             // Fee           [wad]
    uint256 private locked;           // reentrancy guard

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
    constructor(address _vat, address _vow, address _daiJoin) public {
        wards[msg.sender] = 1;
        emit Rely(msg.sender);
        vat = VatLike(_vat);
        vow = _vow;
    }

    // --- Math ---
    uint256 constant WAD = 10 ** 18;
    function rad(uint256 wad) internal pure returns (uint256) {
        return mul(wad, 10 ** 27);
    }
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    // --- Administration ---
    function file(bytes32 what, uint256 data) external auth {
        if (what == "line") line = data;
        else if (what == "toll") toll = data;
        else revert("DssFlash/file-unrecognized-param");
        emit File(what, data);
    }

    // --- ERC 3156 Spec ---
    function maxFlashLoan(
        address token       // Unused
    ) external view returns (uint256) {
        if ()
        return line;
    }
    function flashFee(
        address token,      // Unused
        uint256 amount
    ) external view returns (uint256) {
        return mul(amount, toll) / WAD;
    }
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,      // Unused
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        
    }

    // --- Vat Dai Flash Loan ---
    function vatDaiFlashLoan(
        IVatDaiFlashLoanReceiver receiver,      // address of conformant IVatDaiFlashLoanReceiver
        uint256 _amount,                        // amount to flash loan [rad]
        bytes calldata data                     // arbitrary data to pass to the receiver
    ) external lock {
        uint256 arad = rad(_amount);

        require(arad <= line, "DssFlash/ceiling-exceeded");

        vat.suck(address(this), _receiver, arad);

        uint256 fee = mul(_amount, toll) / WAD;

        IFlashLoanReceiver(_receiver).onFlashLoan(msg.sender, _amount, fee, _data);

        vat.heal(arad);
        vat.move(address(this), vow, rad(fee));
        emit Mint(_receiver, _amount, fee);
    }
}
