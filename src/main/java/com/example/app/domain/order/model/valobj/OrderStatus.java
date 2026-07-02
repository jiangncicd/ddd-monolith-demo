package com.example.app.domain.order.model.valobj;

/**
 * 值对象：订单状态。无唯一标识，靠取值本身识别。
 */
public enum OrderStatus {
    CREATED,
    PAID,
    CANCELLED
}
