// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/PullPayment.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//保险合约
contract Insure is PullPayment, Ownable {
    using SafeMath for uint256;

    event PayPremiumSuccessEvent(string _dydxId, uint256 insureOrderId);

    //投保订单
    struct InsureOrder {
        uint256 insureOrderId;
        //dydx的订单Id
        string dydxOrderId;
        //投保的地址
        address insureAddress;
        //爆仓的价格
        uint256 burstPrice;
        //是否支付保费
        bool isPaied;
        //是否已经赔偿
        bool indemnity;
    }

    //每笔订单支付的用户
    struct InsureOrderUser {
        //支付的地址
        address payAddress;
        //支付的金额
        uint256 amount;
        //是否是投保人
        bool isOwner;
    }

    //手续费
    uint256 feePercent;
    //购买保单金额
    uint256 insureOrderPrice;

    //订单Id对应的支付的人
    mapping(uint256 => InsureOrderUser[]) private insureOrderUsers;
    //订单Id对应的这笔订单的总金额
    mapping(uint256 => uint256) private orderTotalPayAmount;

    //所有的订单ID
    InsureOrder[] private allOrders;
    //地址对应的订单
    mapping(address => InsureOrder[]) private insureOrders;

    //支持的代币类型
    mapping(string => bool) public tokenTypes;

    /**
     * _feePercent: 手续费百分比，0-100
     * _insureOrderPrice: 保费价格
     */
    constructor(uint256 _feePercent, uint256 _insureOrderPrice) {
        require(_feePercent < 100, "Fee Error");
        require(_insureOrderPrice > 0, "Insure order price error");
        feePercent = _feePercent;
        insureOrderPrice = _insureOrderPrice;
    }

    /**
        获取手续费
     */
    function getFeePercent() public view returns (uint256) {
        return feePercent;
    }

    /**
        获取保费价格
     */
    function getInsureOrderPrice() public view returns (uint256) {
        return insureOrderPrice;
    }

    //修改代币是否支持
    function changeTokenTypes(string memory _tokenType, bool allow)
        public
        onlyOwner
    {
        tokenTypes[_tokenType] = allow;
    }

    //判断代币是否支持
    function getTokenTypeStatus(string memory _tokenType)
        public
        view
        returns (bool)
    {
        return tokenTypes[_tokenType];
    }

    //获取当前调用者的订单列表
    function getOwnerInsureOrders()
        public
        view
        returns (InsureOrder[] memory orders)
    {
        return insureOrders[msg.sender];
    }

    //根据地址获取所有的订单列表
    function getAllInsureOrders(address _insureAddress)
        public
        view
        onlyOwner
        returns (InsureOrder[] memory orders)
    {
        return insureOrders[_insureAddress];
    }

    //生成保险订单，_insureAddress:投保地址，_dydxOrderId：dydx的订单ID，_burstPrice：爆仓价格
    function addInsureOrder(
        string memory tokenType,
        address _insureAddress,
        string memory _dydxOrderId,
        uint256 _burstPrice
    ) public checkTokenTypeIsSupport(tokenType) onlyOwner returns (uint256) {
        require(_burstPrice > 0, "_burstPrice Error");

        //生成orderId，下标加1
        uint256 _insureOrderId = allOrders.length.add(1);

        InsureOrder memory order = InsureOrder({
            insureOrderId: _insureOrderId,
            dydxOrderId: _dydxOrderId,
            insureAddress: _insureAddress,
            burstPrice: _burstPrice,
            isPaied: false,
            indemnity: false
        });

        allOrders.push(order);
        insureOrders[_insureAddress].push(order);
        return _insureOrderId;
    }

    //根据订单Id获取订单信息和下标
    function getInsureOrderByOrderId(uint256 _insureOrderId)
        public
        view
        returns (InsureOrder memory, uint256 index)
    {
        require(_insureOrderId > 0, "_insureOrderId Error");
        uint256 orderIndex = _insureOrderId.sub(1);
        return (allOrders[orderIndex], orderIndex);
    }

    //支付保费
    function payPremium(uint256 _insureOrderId, string memory _dydxOrderId)
        public
        payable
    {
        (
            InsureOrder memory order,
            uint256 orderIndex
        ) = getInsureOrderByOrderId(_insureOrderId);

        require(
            stringEqual(_dydxOrderId, order.dydxOrderId),
            "Order exception"
        );
        require(msg.value > 0, "The premium exception");
        require(msg.value == insureOrderPrice, "The premium exception");
        require(!order.isPaied, "The order paied");

        allOrders[orderIndex].isPaied = true;

        for (uint256 i = 0; i < insureOrders[msg.sender].length; i++) {
            if (insureOrders[msg.sender][i].insureOrderId == _insureOrderId) {
                insureOrders[msg.sender][i].isPaied = true;
            }
        }

        insureOrderUsers[_insureOrderId].push(
            InsureOrderUser({
                payAddress: msg.sender,
                amount: msg.value,
                isOwner: true
            })
        );

        orderTotalPayAmount[_insureOrderId] = msg.value;
        //发送支付保费成功的事件
        emit PayPremiumSuccessEvent(_dydxOrderId, _insureOrderId);
    }

    //接受保单
    function agreeInsureOrder(
        uint256 _insureOrderId,
        string memory _dydxOrderId
    ) public payable {
        (InsureOrder memory order, ) = getInsureOrderByOrderId(_insureOrderId);
        require(
            stringEqual(_dydxOrderId, order.dydxOrderId),
            "Order exception"
        );
        require(msg.value > 0, "The premium exception");

        insureOrderUsers[_insureOrderId].push(
            InsureOrderUser({
                payAddress: msg.sender,
                amount: msg.value,
                isOwner: false
            })
        );
    }

    /**
     * _insureOrderId ：保单Id
     * _dydxOrderId : dydx的订单Id
     * _isBurst ：是否爆仓，true-爆仓 ，false-没有爆仓
     */
    function indemnity(
        uint256 _insureOrderId,
        string memory _dydxOrderId,
        bool _isBurst
    ) public onlyOwner {
        //根据订单ID获取订单信息
        (
            InsureOrder memory order,
            uint256 orderIndex
        ) = getInsureOrderByOrderId(_insureOrderId);
        //判断传的dydx的订单ID是否和查询的一致
        require(
            stringEqual(_dydxOrderId, order.dydxOrderId),
            "Order exception"
        );
        //判断订单是否生效
        require(order.isPaied, "Order not paied");
        //修改allOrders里面的订单状态
        allOrders[orderIndex].indemnity = true;
        //修改地址对应订单下面的订单状态
        for (uint256 i = 0; i < insureOrders[msg.sender].length; i++) {
            if (insureOrders[msg.sender][i].insureOrderId == _insureOrderId) {
                insureOrders[msg.sender][i].indemnity = true;
            }
        }
        uint256 _totalPercent = 100;
        //除去手续费之后的总奖金
        uint256 totalBonus = orderTotalPayAmount[_insureOrderId]
            .mul(_totalPercent.sub(feePercent))
            .div(_totalPercent);

        if (_isBurst) {
            //已经爆仓，投保人获胜可以获取所有的奖金
            _asyncTransfer(order.insureAddress, totalBonus);
        } else {
            //没有爆仓，接保人获胜，按比例分配奖金
            //总份数，订单下面的所有奖金减去投保人的投保金额就是总份数
            uint256 totalPercent = orderTotalPayAmount[_insureOrderId] -
                insureOrderPrice;
            //该笔订单总共有多少人支付
            uint256 insureOrderUsersSize = insureOrderUsers[_insureOrderId]
                .length;
            for (uint256 j = 0; j < insureOrderUsersSize; j++) {
                //如果不是投保人就要分配奖金
                if (insureOrderUsers[_insureOrderId][j].isOwner) {
                    //获得的奖金 = 总奖金除以总份数乘当前所占份数
                    _asyncTransfer(
                        insureOrderUsers[_insureOrderId][j].payAddress,
                        totalBonus.div(totalPercent).mul(
                            insureOrderUsers[_insureOrderId][j].amount
                        )
                    );
                }
            }
        }
    }

    //检查当前代币是否支持
    modifier checkTokenTypeIsSupport(string memory tokenType) {
        require(tokenTypes[tokenType], "The current token is not supported");
        _;
    }

    //字符串比较
    function stringEqual(string memory self, string memory other)
        internal
        pure
        returns (bool)
    {
        bytes memory self_rep = bytes(self);
        bytes memory other_rep = bytes(other);

        if (self_rep.length != other_rep.length) {
            return false;
        }
        uint256 selfLen = self_rep.length;
        for (uint256 i = 0; i < selfLen; i++) {
            if (self_rep[i] != other_rep[i]) return false;
        }
        return true;
    }

    //获取余额
    function getBalance(address _address) public view returns (uint256) {
        return _address.balance;
    }
}
