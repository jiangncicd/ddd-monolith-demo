package com.example.app.application.order;

/**
 * 用例接口：trigger 依赖抽象而非实现。
 */
public interface IOrderPlaceUseCase {
    OrderResult placeOrder(PlaceOrderCommand command);
}
