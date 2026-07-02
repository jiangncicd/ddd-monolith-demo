package com.example.app.application.order;

import com.example.app.domain.order.service.OrderService;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;

/**
 * 查询用例实现：编排/透传领域查询。依赖方向仍是 {@code application → domain}。
 */
@Service
public class OrderStatQuery implements IOrderStatQuery {

    @Resource
    private OrderService orderService;

    @Override
    public long totalOrders() {
        return orderService.totalCount();
    }
}
