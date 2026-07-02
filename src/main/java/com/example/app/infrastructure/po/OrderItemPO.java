package com.example.app.infrastructure.po;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class OrderItemPO {
    private Long id;
    private String orderId;
    private String productName;
    private int quantity;
    private BigDecimal price;
}
