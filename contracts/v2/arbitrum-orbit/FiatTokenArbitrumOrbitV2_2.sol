// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import { FiatTokenV2_2 } from "../FiatTokenV2_2.sol";
import { IArbToken } from "../../interface/arbitrum-orbit/IArbToken.sol";

contract FiatTokenArbitrumOrbitV2_2 is FiatTokenV2_2, IArbToken {
    address public l2Gateway;
    address public override l1Address;

    modifier onlyGateway() {
        require(msg.sender == l2Gateway, "ONLY_GATEWAY");
        _;
    }

    /**
     * @notice initialize the token
     * @param l2Gateway_ L2 gateway this token communicates with
     * @param l1Counterpart_ L1 address of ERC20
     */
    function initialize_ArbCompatible(
        address l2Gateway_,
        address l1Counterpart_
    ) external {
        // initializeV2_2 of FiatTokenV2_2 sets version to 3
        require(_initializedVersion == 3);
        require(l2Gateway_ != address(0), "INVALID_GATEWAY");
        require(l2Gateway == address(0), "ALREADY_INIT");
        l2Gateway = l2Gateway_;
        l1Address = l1Counterpart_;
    }

    /**
     * @notice Mint tokens on L2. Callable path is L1Gateway depositToken (which handles L1 escrow), which triggers L2Gateway, which calls this
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
     * @notice Burn tokens on L2.
     * @dev only the token bridge can call this
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
     * @notice Mints fiat tokens to an address.
     * @dev Function 'mint' in FiatTokenV1 is unaccessible from here in the same call due to being external,
     *      so minting logic is copied over here into private function.
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint. Must be less than or equal
     * to the minterAllowance of the caller.
     * @return True if the operation was successful.
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
     * @notice Allows a minter to burn some of its own tokens.
     * @dev Function 'burn' in FiatTokenV1 is unaccessible from here in the same call due to being external,
     *      and also it operates on msg.sender as burn account. Burn logic is copied over here into private function and burn account is provided.
     * @dev The caller must be a minter, must not be blacklisted, and the amount to burn
     * should be less than or equal to the account's balance.
     * @param _amount the amount of tokens to be burned.
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

        totalSupply_ = totalSupply_ - _amount;
        _setBalance(_account, balance - _amount);
        emit Burn(_account, _amount);
        emit Transfer(_account, address(0), _amount);
    }
}
