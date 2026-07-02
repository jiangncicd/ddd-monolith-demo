package com.example.app.domain.order.service;

import com.example.app.domain.order.model.aggregate.OrderAggregate;
import com.example.app.domain.order.model.entity.OrderItemEntity;
import com.example.app.domain.order.repository.IOrderRepository;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;
import java.util.List;

/**
 * 订单领域服务：装配聚合并落库。只关心"订单"这一个领域。
 */
@Service
public class OrderService {

    @Resource
    private IOrderRepository orderRepository;

    public OrderAggregate createOrder(String userId, List<OrderItemEntity> items) {
        OrderAggregate order = new OrderAggregate(userId);
        for (OrderItemEntity item : items) {
            order.addItem(item);
        }
        order.assignId(orderRepository.nextOrderId());
        orderRepository.save(order);
        return order;
    }

    /** 领域查询：订单总数 */
    public long totalCount() {
        return orderRepository.count();
    }
}
