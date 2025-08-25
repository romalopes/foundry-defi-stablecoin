// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

import {UsdrCoin} from "src/UsdrCoin.sol";
import {ReentrancyGuard} from "lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
// import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from
    "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";

/*
 * @title DSCEngine
 * @author Anderson Lopes
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Dollar Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH and WBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract UsdrEngine is ReentrancyGuard {
    ////////////////////
    // Errors
    ////////////////////
    error UsdrEngine_ErrorAmountMustBeMoreThanZero(uint256);
    error UsdrEngine_ErrorArrayofAddressesAreDifferent(uint256, uint256);
    error UsdrEngine_TokenNotAlowed(address);
    error UsdrEngine_ReentrancyGuard_ReentrantCall();
    error UsdrEngine_FailedTransfer(address, address, uint256);
    error UsdrEngine_HealthFactorIsLessThanOne(address, uint256);
    error UsdrEngine_FailedToMintUsdr(address, uint256);
    error UsdrEngine_FailedToBurnUsdr(address, uint256);
    error UsdrEngine_ErrorHealthFactorNotImproved(uint256 startingUserHealthFactor, uint256 endingUserHealthFactor);
    error UsdrEngine_HealthFactorTooHigh(address, uint256);
    ////////////////////
    // State Variables
    ////////////////////

    uint256 private constant ADDITIONAL_FEE_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralization
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    /*
     * @dev Mapping of token to price feed
     * @notice This mapping is used to store the price feed for each token
     */
    mapping(address token => address priceFeed) private s_priceFeed; //TokenToPriceFeed
    // Collateral
    /* @dev Mapping of user to token to amount
     * @notice This mapping is used to store the amount of collateral deposited by the user
     */
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;

    mapping(address user => uint256 amountUsdrMinted) private s_usdrMinted;

    // Usdr
    UsdrCoin private i_usdrCoin;

    address[] private s_collateralTokens;

    ////////////////////
    // Event
    ////////////////////
    /*
     * @dev Event emitted when collateral is deposited
     */
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemCollateralfrom, address indexed redeemCollateralTo, address indexed token, uint256 amount
    );
    event UsdrMinted(address indexed user, uint256 indexed amountUsdr);
    event UsdrBurned(address indexed user, address indexed usdrBurned, uint256 amountUsdr);
    ////////////////////
    // Modifiers
    ////////////////////

    modifier moreThanZero(uint256 _amount) {
        if (_amount <= 0) {
            revert UsdrEngine_ErrorAmountMustBeMoreThanZero(_amount);
        }
        _;
    }

    /**
     * @dev Modifier to check if the token is allowed
     * @param token The address of the token
     * @notice This modifier is used to check if the token is allowed
     */
    modifier isAllowedToken(address token) {
        // If the token is not allowed, rever
        if (s_priceFeed[token] == address(0)) {
            revert UsdrEngine_TokenNotAlowed(token);
        }
        _;
    }

    // modifier isAllowedToken(address[] memory _tokenAddresses) {
    //     // If the token is not allowed, revert
    //     if (_tokenAddresses.length != s_priceFeed.length) {
    //         revert UsdrEngine_ErrorArrayofAddressesAreDifferent(
    //             _tokenAddresses.length,
    //             s_priceFeed.length
    //         );
    //     }
    //     _;
    // }

    ////////////////////
    // Functions
    ///////////////////
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses) {
        //, address _usdrAddress
        // USD Price feeds
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert UsdrEngine_ErrorArrayofAddressesAreDifferent(_tokenAddresses.length, _priceFeedAddresses.length);
        }

        // Examples. BTC/USD, ETH/USD, etc
        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            // Add the token to the mapping
            // Add the price feed to the mapping
            s_priceFeed[_tokenAddresses[i]] = _priceFeedAddresses[i];
            // Add the token to the array
            s_collateralTokens.push(_tokenAddresses[i]);
        }
        i_usdrCoin = new UsdrCoin(address(this));
    }

    ////////////////////
    // External Functions
    ////////////////////
    function getUsdrCoin() public view returns (UsdrCoin) {
        return UsdrCoin(i_usdrCoin);
    }

    /*
    * @notice follows CEI(check, effects, interactions)
    @param: _addressTokenCollateral: The address of the token to deposit the colateral.  Maybe the chainlink address to get the price of BTC,, ETH
    @param: _amountCollateral: The amount of collateral to deposit
    */
    function depositCollateralAndMintUsdr(
        address _addressTokenCollateral,
        uint256 _amountCollateral,
        uint256 _amountUsdrToMind
    ) external moreThanZero(_amountCollateral) isAllowedToken(_addressTokenCollateral) nonReentrant {
        depositCollateral(_addressTokenCollateral, _amountCollateral);
        mintUsdr(_amountUsdrToMind);
    }

    /*
    * @notice follows CEI(check, effects, interactions)
    @param: _addressTokenCollateral: The address of the token to deposit the colateral.  Maybe the chainlink address to get the price of BTC,, ETH
    @param: _amountCollateral: The amount of collateral to deposit
    */
    function depositCollateral(address _addressTokenCollateral, uint256 _amountCollateral)
        public
        moreThanZero(_amountCollateral)
        isAllowedToken(_addressTokenCollateral)
        nonReentrant
    {
        // Add the collateral to the user
        s_collateralDeposited[msg.sender][_addressTokenCollateral] += _amountCollateral;
        emit CollateralDeposited(msg.sender, _addressTokenCollateral, _amountCollateral);

        bool success = ERC20(_addressTokenCollateral).transferFrom(msg.sender, address(this), _amountCollateral);
        if (!success) {
            revert UsdrEngine_FailedTransfer(msg.sender, address(this), _amountCollateral);
        }
    }

    /*
    notice follows CEI(check, effects, interactions)
        @param: _addressTokenCollateral: The address of the token to redeem the colateral.
        @param: _amountCollateral: The amount of collateral to redeem
        @param: _amountUsdrToBurn: The amount of Usdr to burn
        @notice This function redeems the collateral and burns the Usdr
    */
    function redeemCollateralForUsdr(
        address _addressTokenCollateral,
        uint256 _amountCollateral,
        uint256 _amountUsdrToBurn
    ) external {
        burnUsdr(_amountUsdrToBurn);
        // redeemCollateral already calls _revertIfHealthFactorIsBroken
        redeemCollateral(_addressTokenCollateral, _amountCollateral);
    }

    // If they have too much Usdr and not enough Collateral, redeem the Collateral
    // To redeem Collateral, the user must have more Usdr than the threshold
    // 1. health factor > 1 after collateral pulled.
    // CE I: check, effects, interactions
    function redeemCollateral(address _addressTokenCollateral, uint256 _amountCollateral)
        public
        moreThanZero(_amountCollateral)
        nonReentrant
    {
        _redeemCollateral(_addressTokenCollateral, _amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // If they have too much Collateral and not enough Usdr, mint the Usdr
    // 1. Check if colateral value > Usdr value. If so, mint (Price feeds, values, etc)
    // $200 in ETH -> mind $20 in Usdr
    /*
    * @param: _amountUsdrToMint The amount of Usdr to mint
    *    
    * @notice follows CEI(check, effects, interactions) 
    * @notice This function is called when the user wants to mint Usdr
    * @notice They must have more collateral than the threshold
    */
    function mintUsdr(uint256 _amountUsdrToMint) public moreThanZero(_amountUsdrToMint) nonReentrant {
        s_usdrMinted[msg.sender] += _amountUsdrToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_usdrCoin.mint(msg.sender, _amountUsdrToMint);
        if (!minted) {
            revert UsdrEngine_FailedToMintUsdr(msg.sender, _amountUsdrToMint);
        }
        emit UsdrMinted(msg.sender, _amountUsdrToMint);
    }

    // If they have too much Usdr and not enough Collateral, burn the Usdr
    function burnUsdr(uint256 _amountUsdrToBurn) public {
        _burnUsdr(msg.sender, msg.sender, _amountUsdrToBurn);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // backing $75 / $50 usdr
    // Liquidator takes $75 backing and burns $50 usdr
    // Liquidate a user.  If anyone is undercollaterised, they will pay you to liquidate them.
    // // Verify if system is undercollateralised.
    // function getHealthFactor() public returns (uint256) {}
    /* 
    @params: _collateralAddress: The address of the token to redeem the colateral.
    @params: _user: The user to liquidate who broke te health factor.  Health factor < 1 
    @params: _amountCollateral: The amount of collateral to redeem
    @params: _debtToCover: The amount of Usdr to burn _amountUsdrToBurn
    @notice: This function redeems the collateral and burns the Usdr
    @notice: This function assumes the protocol will be 200% collaterized.
    */
    function liquidate(address _addressTokenCollateral, address _user, uint256 _debtToCover)
        external
        // isAllowedToken(collateral)
        moreThanZero(_debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(_user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert UsdrEngine_HealthFactorTooHigh(_user, startingUserHealthFactor);
        }

        // We want to burn their USDR "debt" and take their collateral
        // Bad user has 75% collateral.  We want to take 50% collateral
        // Bad user has 75% usdr.  We want to burn 50% usdr
        // ex: 140 eth deposited as collateral and 100$ usdr minted then recover $100 dolars
        // $100 usdr == ?? ETH to be redeemed?
        // _debtToCover == $100
        // If Eth == $2000.
        // 100 / 2000 == 0.05
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(_addressTokenCollateral, _debtToCover);
        // Give them 10% bonus for incentiving them to liquidate
        // So give the liquidator $110 in WETH for $100 in USDR
        // 0.05 ETH * 0.1 = 0.005 ETH
        uint256 bonusColateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateraltoRedeem = tokenAmountFromDebtCovered + bonusColateral;

        _redeemCollateral(_addressTokenCollateral, totalCollateraltoRedeem, _user, msg.sender);

        _burnUsdr(_user, msg.sender, _debtToCover);
        uint256 endingUserHealthFactor = _healthFactor(_user);
        if (endingUserHealthFactor < startingUserHealthFactor) {
            revert UsdrEngine_ErrorHealthFactorNotImproved(startingUserHealthFactor, endingUserHealthFactor);
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalUsdrMinted, uint256 totalCollateralValueInUsdr)
    {
        (totalUsdrMinted, totalCollateralValueInUsdr) = _getAccountInformationTotalUsdrAndCollateral(user);
        return (totalUsdrMinted, totalCollateralValueInUsdr);
    }

    ////////////////////
    // Internal and Private Functions
    ////////////////////

    function _calculateHealthFactor(uint256 totalUsdrMinted, uint256 totalCollateralValueInUsdr)
        private
        pure
        returns (uint256)
    {
        if (totalUsdrMinted == 0) {
            return type(uint256).max;
        }
        uint256 collateralAdjustedByThreshold =
            (totalCollateralValueInUsdr * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedByThreshold * PRECISION) / totalUsdrMinted;
    }

    /*
        @notice follows CEI(check, effects, interactions)
        @notice This function is called when the user wants to burn Usdr
        @ params onBehalfOf: The user who is burning Usdr.  Former msg.sender
        @ params _amountUsdrToBurn: The amount of Usdr to burn
        @ params usdrFrom: The address of the Usdr contract
    */
    function _burnUsdr(address onBehalfOf, address usdrFrom, uint256 _amountUsdrToBurn) private {
        s_usdrMinted[onBehalfOf] -= _amountUsdrToBurn;
        _revertIfHealthFactorIsBroken(onBehalfOf);
        bool sucess = i_usdrCoin.transferFrom(usdrFrom, address(this), _amountUsdrToBurn);
        if (!sucess) {
            revert UsdrEngine_FailedTransfer(onBehalfOf, usdrFrom, _amountUsdrToBurn);
        }

        i_usdrCoin.burn(_amountUsdrToBurn);
        // if (!burned) {
        //     revert UsdrEngine_FailedToBurnUsdr(msg.sender, _amountUsdrToBurn);
        // }
        emit UsdrBurned(onBehalfOf, usdrFrom, _amountUsdrToBurn);
        _revertIfHealthFactorIsBroken(onBehalfOf);
    }

    function _redeemCollateral(address _addressTokenCollateral, uint256 _amountCollateral, address from, address to)
        private
    {
        // Remove the collateral from the user(from )
        s_collateralDeposited[from][_addressTokenCollateral] -= _amountCollateral;
        emit CollateralRedeemed(from, to, _addressTokenCollateral, _amountCollateral);
        // Transfer the collateral to the user
        bool success = ERC20(_addressTokenCollateral).transfer(to, _amountCollateral);
        if (!success) {
            revert UsdrEngine_FailedTransfer(from, to, _amountCollateral);
        }
    }

    function _getAccountInformationTotalUsdrAndCollateral(address user)
        internal
        view
        returns (uint256 totalUsdrMinted, uint256 totalCollateralValueInUsdr)
    {
        // total usdr minted / total collateral value in usdr
        totalUsdrMinted = s_usdrMinted[user];
        totalCollateralValueInUsdr = getAccountCollateralValueInUsdr(user);
    }

    /*
    * @notice follows CEI(check, effects, interactions)
    * Returns how close to liquidation a user is
    * If it goes below 1, the user is undercollateralised and can be liquidated
    * and if it goes above 1, the user is overcollateralised
    */
    function _healthFactor(address user) internal view returns (uint256 factor) {
        // total usdr minted / total collateral
        // return totalUsdrMinted / totalCollateral
        (uint256 totalUsdrMinted, uint256 totalCollateralValueInUsdr) =
            _getAccountInformationTotalUsdrAndCollateral(user);
        // (150/100) it is overcollateralised
        // (100/150) it is undercollateralised and it can be liquidated
        // return (totalCollateralValueInUsdr / totalUsdrMinted);
        // $1000 ETH * 50 = 50000 ETH  / 100 = 500

        // $150 ETH / $100 USDR = 1.5
        // $150 ETH * 50 = $7500 ETH / 100 = (75 / 100) = 0.75 < 1

        // $1000 ETH / $100 USDR = 10
        // $1000 ETH * 50 = $50000 ETH / 100 = 500 / 100 = 5 > 1
        return _calculateHealthFactor(totalUsdrMinted, totalCollateralValueInUsdr);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. check if they have enough collateral
        // 2. Revert if they don't have it
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert UsdrEngine_HealthFactorIsLessThanOne(user, healthFactor);
        }
    }

    ////////////////////
    // Public and view Functions
    ////////////////////

    function getTokenAmountFromUsd(address token, uint256 usdAmount) public view returns (uint256 amountToken) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // $100e18 USD Debt
        // 1 ETH = 2000 USD
        // 100e18 / 2000 = 50 ETH
        return (usdAmount * PRECISION) / (uint256(price) * ADDITIONAL_FEE_PRECISION);
    }

    /*
        @notice follows CEI(check, effects, interactions)
        @param: user The address of the user to get the collateral value for
        @return: totalCollateralInUsdr
        @notice Returns the total value of the collateral in usdr
        @notice This function is called when the user wants to get the value of their collateral 
    */
    function getAccountCollateralValueInUsdr(address user) public view returns (uint256 totalCollateralInUsdr) {
        // loop through all the collateral the user has
        // get the value of the collateral in usdr
        // add all the values together
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            // Get the token
            address token = s_collateralTokens[i];
            // Get the amount of collateral deposited by this user for this token
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralInUsdr += getUsdValue(token, amount);
        }
        return totalCollateralInUsdr;
    }

    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // Ex: 1 ETH = $1000
        // return value from ChainLink 1000 * 1e8 (eight decimals)
        return ((uint256(price) * ADDITIONAL_FEE_PRECISION) * amount) / PRECISION; //(1000 * 1e8 * 1e10) * 10 * 1e18
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }
}
