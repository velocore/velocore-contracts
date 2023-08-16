// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./CurveCryptoPool.sol";
import "../Satellite.sol";

contract CurveCryptoPoolFactory is Satellite {
    using TokenLib for Token;
    using UncheckedMemory for Token[];
    using UncheckedMemory for uint256[];

    Token public immutable hubToken;

    Token[] public tokenList;
    mapping(Token => CurveCryptoPool) public canonicalPool;
    mapping(CurveCryptoPool => bool) public isCanonicalPool;

    function canonicalPools(uint256 begin, uint256 maxLength)
        external
        view
        returns (Token[] memory tokens, CurveCryptoPool[] memory pools)
    {
        uint256 len = tokenList.length <= begin ? 0 : Math.min(tokenList.length - begin, maxLength);
        tokens = new Token[](len);
        pools = new CurveCryptoPool[](len);
        for (uint256 i = begin; i < begin + len; i++) {
            tokens[i] = tokenList[i];
            pools[i] = canonicalPool[tokens[i]];
        }
    }

    function canonicalPoolsLength() external view returns (uint256) {
        return tokenList.length;
    }

    constructor(IVault vault_, Token hubToken_) Satellite(vault_, address(this)) {
        hubToken = hubToken_;
    }

    function deploy(Token token) external returns (CurveCryptoPool) {
        require(!(hubToken == token));
        require(address(canonicalPool[token]) == address(0));

        uint256[] memory weights = new uint256[](2);
        weights.u(0, 1);
        weights.u(1, 1);

        CurveCryptoPool ret = new CurveCryptoPool(IVault(address(vault)), CurveCryptoParam({
            a: 400000,
            g_e18: 0.000145e18,
            midFee_e18: 0.0026e18,
            outFee_e18: 0.0045e18,
            gammaFee_e18: 0.00023e18,
            baseToken: token,
            quoteToken: hubToken,
            name: string(abi.encodePacked("Velocore LP: ", token.symbol())),
            symbol: string(abi.encodePacked(token.symbol(), "-VLP")),
            initialPrice: 10e18
        }));

        tokenList.push(token);
        canonicalPool[token] = ret;
        isCanonicalPool[ret] = true;

        return ret;
    }
}
