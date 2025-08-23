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
    ////////////////////
    // State Variables
    ////////////////////

    uint256 private constant ADDITIONAL_FEE_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateralization
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
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
    event UsdrMinted(address indexed user, uint256 indexed amountUsdr);
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

    function depositCollateralAndMintUsdr() external {}

    /*
    * @notice follows CEI(check, effects, interactions)
    @param: _tokenCollateralAddress: The address of the token to deposit the colateral.  Maybe the chainling address to get the price of BTC,, ETH
    @param: _amountCollateral: The amount of collateral to deposit
    */
    function depositCollateral(address _tokenCollateralAddress, uint256 _amountCollateral)
        external
        moreThanZero(_amountCollateral)
        isAllowedToken(_tokenCollateralAddress)
        nonReentrant
    {
        // Add the collateral to the user
        s_collateralDeposited[msg.sender][_tokenCollateralAddress] += _amountCollateral;
        emit CollateralDeposited(msg.sender, _tokenCollateralAddress, _amountCollateral);

        bool success = ERC20(_tokenCollateralAddress).transferFrom(msg.sender, address(this), _amountCollateral);
        if (!success) {
            revert UsdrEngine_FailedTransfer(msg.sender, address(this), _amountCollateral);
        }
    }

    function redeemandCollateralForUsdr() external {}

    function redeemandCollateral() external {}

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
    function mintUsdr(uint256 _amountUsdrToMint) external moreThanZero(_amountUsdrToMint) nonReentrant {
        s_usdrMinted[msg.sender] += _amountUsdrToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_usdrCoin.mint(msg.sender, _amountUsdrToMint);
        if (!minted) {
            revert UsdrEngine_FailedToMintUsdr(msg.sender, _amountUsdrToMint);
        }
        emit UsdrMinted(msg.sender, _amountUsdrToMint);
    }

    // If they have too much Usdr and not enough Collateral, burn the Usdr
    function burnUsdr() external {}

    function liquidate() external {}

    // Verify if system is undercollateralised.
    function getHealthFactor() public returns (uint256) {}

    ////////////////////
    // Internal and Private Functions
    ////////////////////

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
        uint256 collateralAdjustedByThreshold =
            (totalCollateralValueInUsdr * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedByThreshold * PRECISION) / totalUsdrMinted;
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
    // Public Functions
    ////////////////////

    /*
    * @

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
}
