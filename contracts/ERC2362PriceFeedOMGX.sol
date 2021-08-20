// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import "./ERC2362PriceFeed.sol";
import "witnet-ethereum-bridge/contracts/interfaces/IERC20.sol";

// Your contract needs to inherit from UsingWitnet
contract ERC2362PriceFeedOMGX is ERC2362PriceFeed {

    IERC20 public immutable oETH;
    uint256 internal lastBalance;

    /// Constructor.
    /// @param _wrb WitnetRequestBoard instance, or proxy, address.
    /// @param _erc2362id Price feed denomination according to ERC2362 specs.
    /// @param _decimals Fixed number of decimals.
    /// @param _oEth ERC-20 compliant oETH address.
    constructor (
        WitnetRequestBoard _wrb,
        string memory _erc2362id,
        uint8 _decimals,
        IERC20 _oEth
      )
      ERC2362PriceFeed(_wrb, _erc2362id, _decimals)
    {
        oETH = _oEth;
    }

    receive() external payable {
        revert("ERC2362PriceFeedOMGX: no transfers accepted");
    }

    modifier __payableOVM {
        _;
        lastBalance = __balanceOf(address(this));
    }

    /// @notice Calculates `msg.value` equivalent oETH value. 
    /// @dev Based on `lastBalance` value.
    function __msgValue() internal view returns (uint256) {
        uint256 _newBalance = __balanceOf(address(this));
        assert(_newBalance >= lastBalance);
        return _newBalance - lastBalance;
    }

    /// Gets oETH balance of given address.
    function __balanceOf(address _from) internal view returns (uint256) {
        return oETH.balanceOf(_from);
    }

    /// @notice Transfers oETHs to given address.
    /// @dev Updates `lastBalance` value.
    /// @param _to oETH recipient account.
    /// @param _amount Amount of oETHs to transfer.
    function __safeTransferTo(address payable _to, uint256 _amount) internal {
        uint256 _balance = __balanceOf(address(this));
        require(_amount <= _balance, "truffl: insufficient funds");
        lastBalance = _balance - _amount;
        oETH.transfer(_to, _amount);
    }

    /// @notice Sends `request` to the WitnetRequestBoard.
    /// @dev This method will only succeed if `pending` is 0.  
    function requestUpdate()
        public payable
        __payableOVM
        override
    {
        require(pending == false, "ERC2362PriceFeed: pending update");

        // Send the request to Witnet and store the ID for later retrieval of the result:
        __safeTransferTo(payable(address(witnet)), __msgValue());
        requestId = _witnetPostRequest(this);

        // Signal that there is already a pending request
        pending = true;
    }
}