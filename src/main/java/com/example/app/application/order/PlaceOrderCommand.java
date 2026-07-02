package com.example.app.application.order;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

/**
 * 用例入参（Command）。application 层的出入参独立于 trigger 的 DTO 和 domain 的模型。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlaceOrderCommand {

    private String userId;
    private List<Item> items;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Item {
        private String productName;
        private int quantity;
        private BigDecimal price;
    }
}
