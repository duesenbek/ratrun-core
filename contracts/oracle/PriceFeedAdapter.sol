// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
    function decimals() external view returns (uint8);
}

contract PriceFeedAdapter {
    error PriceFeed__ZeroAddress();
    error PriceFeed__ZeroThreshold();
    error PriceFeed__StalePrice(uint256 updatedAt, uint256 threshold);
    error PriceFeed__NonPositivePrice(int256 price);
    error PriceFeed__StaleRound(uint80 roundId, uint80 answeredInRound);

    AggregatorV3Interface public immutable feed;
    uint256               public immutable stalenessThreshold;

    event PriceFetched(int256 price, uint256 updatedAt);

    constructor(address _feed, uint256 _stalenessThreshold) {
        if (_feed == address(0))       revert PriceFeed__ZeroAddress();
        if (_stalenessThreshold == 0)  revert PriceFeed__ZeroThreshold();
        feed               = AggregatorV3Interface(_feed);
        stalenessThreshold = _stalenessThreshold;
    }

    function getLatestPrice() external view returns (int256 price) {
        return _fetchPrice();
    }

    function decimals() external view returns (uint8) {
        return feed.decimals();
    }

    function _fetchPrice() internal view returns (int256) {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        if (answer <= 0)
            revert PriceFeed__NonPositivePrice(answer);
        if (answeredInRound < roundId)
            revert PriceFeed__StaleRound(roundId, answeredInRound);
        if (block.timestamp - updatedAt > stalenessThreshold)
            revert PriceFeed__StalePrice(updatedAt, stalenessThreshold);

        return answer;
    }
}
