// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/BTPAddress.sol";
import "./interfaces/IFeeManage.sol";
import "./interfaces/ICallService.sol";
import "./interfaces/ICallServiceReceiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ONSProxy is ICallServiceReceiver, Initializable, Ownable, ERC721 {
    address public callSvc;

    string public callSvcBtpAddr;
    string public networkID;
    string public iconBtpAddress; 
    uint256 private lastRollbackId;
    uint256[] private prices;
    mapping(uint256 => string) private tokenURIs;

    struct RollbackData {
        uint256 id;
        bytes rollbackData;
        uint256 ssn;
    }

    mapping(uint256 => RollbackData) private rollbacks;

    event MessageReceived(string indexed _from, bytes _data);
    event MessageSent(address indexed _from, uint256 indexed _messageId, bytes _data);
    event RollbackDataReceived(string indexed _from, bytes _data);
    event CallServiceUpdated(address indexed _from, address indexed _to);

    receive() external payable {}
    fallback() external payable {}

    modifier onlyCallService() {
        require(msg.sender == callSvc, "XCallBase: only CallService can call this function");
        _;
    }

    constructor() ERC721("Omni Name Service", "OMNI") {

    }

    /**
        @notice Initializer. Replaces constructor.
        @dev Callable only once by deployer.
        @param _callServiceAddress Address of x-call service on the current chain
        @param _networkID The network ID of the current chain
     */
    function initialize(
        address _callServiceAddress,
        string memory _networkID,
        string memory _iconBtpAddress,
        uint256[] memory _prices
    ) public initializer {
        require(_callServiceAddress != address(0), "XCallBase: call service address is zero");
        require(bytes(_networkID).length != 0, "XCallBase: network ID is empty");
        require(_prices.length == 4, "Invalid prices length");

        callSvc = _callServiceAddress;
        networkID = _networkID;
        callSvcBtpAddr = string(abi.encodePacked("btp://", networkID, "/", callSvc));
        iconBtpAddress = _iconBtpAddress;
        prices = _prices;
    }

    function compareTo(
        string memory _base,
        string memory _value
    ) internal pure returns (bool) {
        if (keccak256(abi.encodePacked(_base)) == keccak256(abi.encodePacked(_value))) {
            return true;
        }

        return false;
    }

    function _processXCallRollback(bytes memory _data) internal virtual {
        emit RollbackDataReceived(callSvcBtpAddr, _data);
        revert("XCallBase: method not supported");
    }

    // Split a string into an array of values using a delimiter
    function splitString(string memory _str, string memory _delimiter) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(_str);
        uint256 delimiterCount = 1;
        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == bytes1(bytes(_delimiter)[0])) {
                delimiterCount++;
            }
        }

        string[] memory parts = new string[](delimiterCount);
        uint256 partIdx = 0;
        string memory temp = "";

        for (uint256 i = 0; i < strBytes.length; i++) {
            if (strBytes[i] == bytes1(bytes(_delimiter)[0])) {
                parts[partIdx] = temp;
                temp = "";
                partIdx++;
            } else {
                temp = string(abi.encodePacked(temp, strBytes[i]));
            }
        }

        parts[partIdx] = temp;

        return parts;
    }

    // Parse a string to uint256
    function parseUint(string memory _str) internal pure returns (uint256) {
        return uint256(keccak256(bytes(_str)));
    }

    function _processXCallMethod(
        string calldata _from,
        bytes memory _data
    ) internal virtual {
        string memory dataAsString = string(_data);
        string[] memory values = splitString(dataAsString, ",");
        string memory action = values[0];
        if (compareTo(action, 'mint')){
            uint256 tokenId = parseUint(values[1]);
            (, string memory adr) = BTPAddress.parseBTPAddress(values[2]);
            address to = address(bytes20(bytes(adr)));
            string memory uri = values[3];
            
            setTokenURI(tokenId, uri);
            _mint(to, tokenId);
        } else {
            revert("Method not supported");
        }
    }

    function _processXCallMessage(
        string calldata _from,
        bytes calldata _data
    ) internal {
        if (compareTo(_from, callSvcBtpAddr)) {
            (uint256 rbid, bytes memory encodedRb) = abi.decode(_data, (uint256, bytes));
            RollbackData memory storedRb = rollbacks[rbid];

            require(compareTo(string(encodedRb), string(storedRb.rollbackData)), "XCallBase: rollback data mismatch");

            delete rollbacks[rbid];

            _processXCallRollback(encodedRb);
        } else if (compareTo(_from, iconBtpAddress)) {
            _processXCallMethod(_from, _data);
        } else {
            revert("Incorrect caller");
        }
    }

    function requestMint(
        string memory _name,
        string memory _years
    ) public payable returns (uint256) {
        uint fee = getXCallFee(iconBtpAddress, true);

        if (bytes(_name).length == 1 && msg.value - fee != prices[0]) {
            revert("Invalid payment");
        } else if (bytes(_name).length == 2 && msg.value - fee != prices[1]) {
            revert("Invalid payment");
        } else if (bytes(_name).length == 3 && msg.value - fee != prices[2]) {
            revert("Invalid payment");
        } else if (bytes(_name).length >= 4 && msg.value - fee != prices[3]) {
            revert("Invalid payment");
        }

        bytes memory _data = abi.encodePacked(
            "mint,", _name, ",", msg.sender, ",", _years
        );
        bytes memory _rollback = "";


        _sendXCallMessage(iconBtpAddress, _data, _rollback);

        address payable treasury = payable(owner()); 
        uint256 amountToTransfer = msg.value - fee;
        treasury.transfer(amountToTransfer);
    }

    function _sendXCallMessage(
        string memory _to,
        bytes memory _data,
        bytes memory _rollback
    ) internal {
        if (_rollback.length > 0) {
            uint fee = getXCallFee(_to, true);
            require(msg.value >= fee, "XCallBase: insufficient fee");

            uint256 id = ++lastRollbackId;
            bytes memory encodedRd = abi.encode(id, _rollback);

            uint256 sn = ICallService(callSvc).sendCallMessage{value:msg.value}(
                _to,
                _data,
                encodedRd
            );

            rollbacks[id] = RollbackData(id, _rollback, sn);

            emit MessageSent(msg.sender, sn, _data);
        } else {
            uint fee = getXCallFee(_to, false);
            require(msg.value >= fee, "XCallBase: insufficient fee");

            uint256 sn = ICallService(callSvc).sendCallMessage{value:msg.value}(
                _to,
                _data,
                _rollback
            );

            emit MessageSent(msg.sender, sn, _data);
        }
    }

    function handleCallMessage(
        string calldata _from,
        bytes calldata _data
    ) external override onlyCallService {
        _processXCallMessage(_from, _data);
    }

    function getCallService() public view returns (address) {
        return callSvc;
    }

    function getIconBtpAddress() public view returns (string memory) {
        return iconBtpAddress;
    }

    function getXCallFee(
        string memory _to,
        bool _useCallback
    ) public view returns (uint) {
        string memory destinationNetworkID = BTPAddress.networkAddress(_to);
        return IFeeManage(callSvc).getFee(destinationNetworkID, _useCallback);
    }

    function setPrices(uint256[] memory _newPrices) public onlyOwner {
        require(_newPrices.length == 4, "Invalid prices length");
        prices = _newPrices;
    }

    function getPrices() public view returns (uint256[] memory) {
        return prices;
    }

    function setCallServiceAdress(
        address _callServiceAddress
    ) public onlyOwner {
        require(_callServiceAddress != address(0), "XCallBase: call service address is zero");
        address oldCallSvc = callSvc;
        callSvc = _callServiceAddress;
        callSvcBtpAddr = ICallService(callSvc).getBtpAddress();
        emit CallServiceUpdated(oldCallSvc, _callServiceAddress);
    }

        function setTokenURI(uint256 tokenId, string memory tokenURI) internal {
        tokenURIs[tokenId] = tokenURI;
    }

    function _tokenURI(uint256 tokenId) internal view returns (string memory) {
        return tokenURIs[tokenId];
    }

    function getTokenURI(uint256 tokenId) external view returns (string memory) {
        return tokenURIs[tokenId];
    }
}
