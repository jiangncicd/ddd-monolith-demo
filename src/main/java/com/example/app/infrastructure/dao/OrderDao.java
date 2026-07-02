package com.example.app.infrastructure.dao;

import com.example.app.infrastructure.po.OrderItemPO;
import com.example.app.infrastructure.po.OrderPO;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import javax.annotation.Resource;

@Repository
public class OrderDao {

    @Resource
    private JdbcTemplate jdbcTemplate;

    public void insertOrder(OrderPO po) {
        jdbcTemplate.update(
                "INSERT INTO order_info (order_id, user_id, status, total_amount) VALUES (?, ?, ?, ?)",
                po.getOrderId(), po.getUserId(), po.getStatus(), po.getTotalAmount());
    }

    public void insertItem(OrderItemPO po) {
        jdbcTemplate.update(
                "INSERT INTO order_item (order_id, product_name, quantity, price) VALUES (?, ?, ?, ?)",
                po.getOrderId(), po.getProductName(), po.getQuantity(), po.getPrice());
    }

    public long countOrders() {
        Long count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM order_info", Long.class);
        return count == null ? 0L : count;
    }
}
