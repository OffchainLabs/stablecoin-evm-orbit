// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { FiatTokenV2_2 } from "../FiatTokenV2_2.sol";
import { IArbToken } from "../../interface/arbitrum-orbit/IArbToken.sol";

/**
 * @title Custom extension of USDC to make it usable as bridged USDC on Arbitrum Orbit chain.
 * @notice Reference to the Circle's Bridged USDC Standard:
 *         https://github.com/circlefin/stablecoin-evm/blob/master/doc/bridged_USDC_standard.md
 *
 * @dev    This contract can be used on new Orbit chains which want to provide USDC
 *         bridging solution and keep the possibility to upgrade to native USDC at
 *         some point later.
 */
contract FiatTokenArbitrumOrbitV2_2 is FiatTokenV2_2, IArbToken {
    /**
     * @dev Storage slot with the address of the child chain gateway
     * This is the keccak-256 hash of "FiatTokenArbitrumOrbitV2_2.l2Gateway.slot" subtracted by 1.
     * Slot is hard-coded so that base USDC contracts can be further expanded without the possibility
     * of slot collision.
     */
    bytes32
        private constant L2_GATEWAY_SLOT = 0xdbf6298cab77bb44ebfd5abb25ed2538c2a55f7404c47e83e6531361fba28c24;

    /**
     * @dev Storage slot with the address of the parent chain USDC
     * This is the keccak-256 hash of "FiatTokenArbitrumOrbitV2_2.l1Address.slot" subtracted by 1.
     * Slot is hard-coded so that base USDC contracts can be further expanded without the possibility
     * of slot collision.
     */
    bytes32
        private constant L1_ADDRESS_SLOT = 0x54352c0d7cc5793352a36344bfdcdcf68ba6258544ce1aed71f60a74d882c191;

    modifier onlyGateway() {
        require(msg.sender == l2Gateway(), "ONLY_GATEWAY");
        _;
    }

    /**
     * @notice initialize the token
     * @param l2Gateway_ child chain gateway this token communicates with
     * @param l1Counterpart_ parent chain address of the USDC
     */
    function initializeArbitrumOrbit(address l2Gateway_, address l1Counterpart_)
        external
    {
        // initializeV2_2 of FiatTokenV2_2 sets version to 3
        require(_initializedVersion == 3);
        require(l2Gateway_ != address(0), "INVALID_GATEWAY");
        require(l1Counterpart_ != address(0), "INVALID_COUNTERPART");
        require(l2Gateway() == address(0), "ALREADY_INIT");
        assembly {
            sstore(L2_GATEWAY_SLOT, l2Gateway_)
            sstore(L1_ADDRESS_SLOT, l1Counterpart_)
        }
    }

    /**
     * @notice Get the address of the child chain gateway connected to this token
     */
    function l2Gateway() public view returns (address _l2Gateway) {
        assembly {
            _l2Gateway := sload(L2_GATEWAY_SLOT)
        }
    }

    /**
     * @notice Get the address of the parent chain USDC
     */
    function l1Address() public override view returns (address _l1Address) {
        assembly {
            _l1Address := sload(L1_ADDRESS_SLOT)
        }
    }

    /**
     * @notice Mint tokens on child chain. Callable path is L1Gateway depositToken (which handles L1 escrow), which triggers L2Gateway, which calls this
     * @param account recipient of tokens
     * @param amount amount of tokens minted
     */
    function bridgeMint(address account, uint256 amount)
        external
        virtual
        override
        onlyGateway
    {
        _mint(account, amount);
    }

    /**
     * @notice Burn tokens on child chain.
     * @dev only the token bridge gateway can call this
     * @param account owner of tokens
     * @param amount amount of tokens burnt
     */
    function bridgeBurn(address account, uint256 amount)
        external
        virtual
        override
        onlyGateway
    {
        _burn(account, amount);
    }

    /**
     * @dev Function 'mint' in FiatTokenV1 is unaccessible from here in the same call due to being external,
     *      so minting logic is copied over here into private function.
     */
    function _mint(address _to, uint256 _amount)
        private
        whenNotPaused
        onlyMinters
        notBlacklisted(msg.sender)
        notBlacklisted(_to)
        returns (bool)
    {
        require(_to != address(0), "FiatToken: mint to the zero address");
        require(_amount > 0, "FiatToken: mint amount not greater than 0");

        uint256 mintingAllowedAmount = minterAllowed[msg.sender];
        require(
            _amount <= mintingAllowedAmount,
            "FiatToken: mint amount exceeds minterAllowance"
        );

        totalSupply_ = totalSupply_.add(_amount);
        _setBalance(_to, _balanceOf(_to).add(_amount));
        minterAllowed[msg.sender] = mintingAllowedAmount.sub(_amount);
        emit Mint(msg.sender, _to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    /**
     * @dev Function 'burn' in FiatTokenV1 is unaccessible from here in the same call due to being external,
     *      and also it operates on msg.sender as burn account. Burn logic is copied over here into private
     *      function and burn account is provided.
     */
    function _burn(address _account, uint256 _amount)
        private
        whenNotPaused
        onlyMinters
        notBlacklisted(_account)
    {
        uint256 balance = _balanceOf(_account);
        require(_amount > 0, "FiatToken: burn amount not greater than 0");
        require(balance >= _amount, "FiatToken: burn amount exceeds balance");

        totalSupply_ = totalSupply_.sub(_amount);
        _setBalance(_account, balance.sub(_amount));
        emit Burn(_account, _amount);
        emit Transfer(_account, address(0), _amount);
    }
}
