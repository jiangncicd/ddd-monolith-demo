/**
 * 订单领域：本示例中"充血 + 聚合"的完整样板。
 * <p>{@code OrderAggregate} 作为聚合根，管理 {@code OrderItemEntity} 与值对象
 * {@code Money}/{@code OrderStatus} 的一致性，并封装算总额等自身行为。
 */
package com.example.app.domain.order;
