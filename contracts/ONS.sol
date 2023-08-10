// contracts/VotingDapp.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ICallService.sol";
import "./interfaces/ICallServiceReceiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./libraries/BTPAddress.sol";

/**
 * @title VotingDapp
 * @notice A simple voting dapp that can be called from another chain
 */
contract ONSProxy is  ERC721, ICallServiceReceiver {

    address private callSvc;
    uint256 private lastId;
    string private network; 
    string private iconBtpAddress; 
    string private btpCallService; 
    mapping(uint256 => string) private tokenURIs;

    struct RollbackData {
        uint256 id;
        bytes rollback;
        uint256 ssn;
    }

    /*
     * @notice Constructor
     * @param _callService The address of the Call Message Service
     */
    constructor(address _callService, string memory _currentNetwork, string memory _iconBtpAddress) ERC721("Omni Name Service", "OMNI") {
        callSvc = _callService;
        network = _currentNetwork;
        iconBtpAddress = _iconBtpAddress;
        btpCallService = ICallService(callSvc).getBtpAddress();
    }
    
    

    /**
     * @notice modifier to restrict access to the Call Message Service
     */
    modifier onlyCallService() {
        require(msg.sender == callSvc, "OnlyCallService");
        _;
    }

    /**
     * @notice Returns the address of the Call Message Service
     * @return The address of the Call Message Service
     */
    function getCallService() public view returns (address) {
        return callSvc;
    }

    /**
     * @notice compares two strings
     * @param _base The base string
     * @param _value The string to compare
     * @return True if the strings are equal, false otherwise
     */
    function compareTo(
        string memory _base,
        string memory _value
    ) internal pure returns (bool) {
        if (
            keccak256(abi.encodePacked(_base)) ==
            keccak256(abi.encodePacked(_value))
        ) {
            return true;
        }
        return false;
    }

    /**
        @notice Handles the call message received from the source chain.
        @dev Only called from the Call Message Service.
        @param _from The BTP address of the caller on the source chain
        @param _data The calldata delivered from the caller
   */
    function handleCallMessage(
        string calldata _from,
        bytes calldata _data
    ) external override onlyCallService {
        string memory msgData = string(_data);
        emit MessageReceived(_from, _data, msgData);
        if (compareTo(_from, btpCallService)) {
            // RollBack
        } else if (compareTo(_from, iconBtpAddress)) {
            string memory dataAsString = string(_data);
            string[] memory values = splitString(dataAsString, ",");
            string memory action = values[0];
            if (compareTo(action, 'mint')){
                uint256 tokenId = parseUint(values[1]);
                (, string memory adr) = BTPAddress.parseBTPAddress(values[2]);
                address to = address(bytes20(bytes(adr)));
                string memory uri = values[3];
                tokenURIs[tokenId] = uri;
                _mint(to, tokenId);
            } else {
                revert("Method not supported");
            }
        }
        
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

    /**
     * @notice event emitted when a call message is received
     * @dev Only called from the Call Message Service.
     * @param _from The BTP address of the caller on the source chain
     * @param _data The calldata delivered from the caller
     * @param msgData The calldata converted to a string
     */
    event MessageReceived(string _from, bytes _data, string msgData);
}
