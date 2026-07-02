package com.example.app.infrastructure.po;

import lombok.Data;

import java.math.BigDecimal;

@Data
public class OrderPO {
    private Long id;
    private String orderId;
    private String userId;
    private String status;
    private BigDecimal totalAmount;
}
