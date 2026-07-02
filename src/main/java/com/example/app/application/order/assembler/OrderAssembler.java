package com.example.app.application.order.assembler;

import com.example.app.application.order.OrderResult;
import com.example.app.domain.order.model.aggregate.OrderAggregate;

/**
 * 装配/防腐：领域聚合 -> 用例出参。领域对象不直接穿透到外层。
 */
public final class OrderAssembler {

    private OrderAssembler() {
    }

    public static OrderResult toSuccess(OrderAggregate order) {
        return OrderResult.builder()
                .success(true)
                .orderId(order.getOrderId())
                .status(order.getStatus().name())
                .totalAmount(order.totalAmount().getAmount())
                .message("下单成功")
                .build();
    }

    public static OrderResult toRejected(String message) {
        return OrderResult.builder()
                .success(false)
                .message(message)
                .build();
    }
}
