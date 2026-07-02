package com.example.app.domain.order.repository;

import com.example.app.domain.order.model.aggregate.OrderAggregate;

/**
 * 订单仓储接口（定义在领域层，实现在 infrastructure）。
 */
public interface IOrderRepository {

    String nextOrderId();

    void save(OrderAggregate order);

    /** 订单总数（供统计/对账等查询用例使用） */
    long count();
}
