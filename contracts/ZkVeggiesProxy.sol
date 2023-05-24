//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.18;

/* -------------------------- OpenZeppelin imports -------------------------- */
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/* ----------------------------- Solmate imports ---------------------------- */
import {Owned} from "solmate/src/auth/Owned.sol";

contract ZkVeggiesProxy is Owned, TransparentUpgradeableProxy {
    bool initialized;

    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) Owned(admin_) TransparentUpgradeableProxy(_logic, admin_, _data) {}

    function initialize(
        address owner,
        string memory _name,
        string memory _symbol,
        string memory _baseUri,
        string memory _contractURI,
        uint256 _royaltyPercentage,
        address _zkSeeds
    ) public ifAdmin {
        require(!initialized, "Already initialized");

        (bool success, ) = _implementation().delegatecall(
            abi.encodeWithSelector(
                bytes4(0xc691e573),
                _name,
                _symbol,
                _baseUri,
                _contractURI,
                _royaltyPercentage,
                _zkSeeds
            )
        );

        transferOwnership(owner);

        require(success, "IMPL_INIT_FAILED");
    }
}
