package com.example.app.application.order;

/**
 * 查询用例（与命令用例 {@link IOrderPlaceUseCase} 对称）。
 * <p>把"读"与"写"用例分开，是 CQRS 的朴素形态；trigger 层（如 task）通过它读数据，
 * 而不直接依赖 infrastructure。
 */
public interface IOrderStatQuery {
    long totalOrders();
}
