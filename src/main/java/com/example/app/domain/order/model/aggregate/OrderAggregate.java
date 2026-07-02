package com.example.app.domain.order.model.aggregate;

import com.example.app.domain.order.model.entity.OrderItemEntity;
import com.example.app.domain.order.model.valobj.Money;
import com.example.app.domain.order.model.valobj.OrderStatus;
import lombok.Getter;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * 聚合根：实体（OrderItem）+ 值对象（Money/OrderStatus）的一致性边界。
 * <p>
 * 纪律：聚合只封装"与自身相关的、单一简单"的行为（加项、算总额、状态流转）；
 * 跨领域的编排（查用户 -> 过规则 -> 下单）交给 application 层，别塞进聚合。
 */
@Getter
public class OrderAggregate {

    private String orderId;
    private final String userId;
    private final List<OrderItemEntity> items;
    private OrderStatus status;

    public OrderAggregate(String userId) {
        this.userId = userId;
        this.items = new ArrayList<>();
        this.status = OrderStatus.CREATED;
    }

    public void addItem(OrderItemEntity item) {
        if (item == null || item.getQuantity() <= 0) {
            throw new IllegalArgumentException("非法订单项");
        }
        this.items.add(item);
    }

    /** 聚合内核心行为：汇总所有订单项的金额 */
    public Money totalAmount() {
        Money total = Money.zero();
        for (OrderItemEntity item : items) {
            total = total.add(item.subtotal());
        }
        return total;
    }

    public void assignId(String orderId) {
        this.orderId = orderId;
    }

    /** 对外只读，保护聚合内部集合 */
    public List<OrderItemEntity> getItems() {
        return Collections.unmodifiableList(items);
    }
}
