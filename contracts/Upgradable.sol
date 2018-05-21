pragma solidity ^0.4.18;

import './EternalStorageUpdater.sol';

/**
 * @title Upgrdable Contract
 * @dev Allows accounts to be upgraded by an "upgader" role
*/
contract Upgradable is EternalStorageUpdater {

  address public upgrader;
  address public upgradedAddress;
  event Upgraded(address newContractAddress);

  /**
   * @dev Throws if called by any account other than the upgrader
  */
  modifier onlyUpgrader() {
    require(msg.sender == upgrader);
    _;
  }

  /**
   * @dev Checks if contract has been upgraded
  */
  function isUpgraded() public view returns (bool) {
    return upgradedAddress != 0x0;
  }

  /**
   * @dev upgrades contract 
   * @param _contractAddress address The address of the new contract
  */
  function upgrade(address _contractAddress) onlyUpgrader public {
    upgradedAddress = _contractAddress;
    contractStorage.setAccess(_contractAddress, true);
    contractStorage.setAccess(address(this), false);
    Upgraded(upgradedAddress);
  }

}
