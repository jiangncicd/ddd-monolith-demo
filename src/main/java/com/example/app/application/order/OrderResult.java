package com.example.app.application.order;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 用例出参（Result）。领域聚合不外泄，统一由 assembler 装配成 Result。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderResult {
    private boolean success;
    private String orderId;
    private String status;
    private BigDecimal totalAmount;
    private String message;
}
