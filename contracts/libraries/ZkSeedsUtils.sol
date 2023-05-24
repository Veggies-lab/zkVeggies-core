//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.18;

library ZkSeedsUtils {
    enum SeedTypes {
        POTATO,
        BROCCOLI,
        TOMATO,
        CARROT,
        CHILLI
    }

    /// @dev Get a zkSeeds seed type.
    /// @return seedType A number that represent the seed type accordingto the
    ///         SeedTypes enum.
    function getSeedType(
        uint256 tokenId
    ) internal pure returns (uint256 seedType) {
        uint256 leastSignificantDigit = tokenId % 10;

        if (leastSignificantDigit < 3) return uint256(SeedTypes.POTATO);
        if (leastSignificantDigit >= 3 && leastSignificantDigit < 5)
            return uint256(SeedTypes.BROCCOLI);
        if (leastSignificantDigit >= 5 && leastSignificantDigit < 7)
            return uint256(SeedTypes.TOMATO);
        if (leastSignificantDigit >= 7 && leastSignificantDigit < 9)
            return uint256(SeedTypes.CARROT);
        if (leastSignificantDigit == 9) return uint256(SeedTypes.CHILLI);
    }

    /// @dev Check if a seed is a potato
    function isPotato(uint256 tokenId) internal pure returns (bool) {
        return getSeedType(tokenId) == uint256(SeedTypes.POTATO);
    }

    /// @dev Check if a seed is a broccoli
    function isBroccoli(uint256 tokenId) internal pure returns (bool) {
        return getSeedType(tokenId) == uint256(SeedTypes.BROCCOLI);
    }

    /// @dev Check if a seed is a tomato
    function isTomato(uint256 tokenId) internal pure returns (bool) {
        return getSeedType(tokenId) == uint256(SeedTypes.TOMATO);
    }

    /// @dev Check if a seed is a carrot
    function isCarrot(uint256 tokenId) internal pure returns (bool) {
        return getSeedType(tokenId) == uint256(SeedTypes.CARROT);
    }

    /// @dev Check if a seed is a chilli
    function isChilli(uint256 tokenId) internal pure returns (bool) {
        return getSeedType(tokenId) == uint256(SeedTypes.CHILLI);
    }
}
