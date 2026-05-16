// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockAggregatorV3 {
    int256  private _price;
    uint256 private _updatedAt;
    uint80  private _roundId;
    uint8   private _decimals;
    bool    private _staleRound;

    constructor(int256 initialPrice, uint8 dec) {
        _price     = initialPrice;
        _decimals  = dec;
        _roundId   = 1;
        _updatedAt = block.timestamp;
    }

    function setPrice(int256 price) external {
        _price     = price;
        _roundId++;
        _updatedAt = block.timestamp;
    }

    function setUpdatedAt(uint256 ts) external {
        _updatedAt = ts;
    }

    function setStaleRound(bool stale) external {
        _staleRound = stale;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        answeredInRound = _staleRound ? _roundId - 1 : _roundId;
        return (_roundId, _price, _updatedAt, _updatedAt, answeredInRound);
    }
}
