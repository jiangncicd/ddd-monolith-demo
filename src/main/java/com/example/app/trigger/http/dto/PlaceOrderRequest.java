package com.example.app.trigger.http.dto;

import lombok.Data;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.List;

/**
 * HTTP 入参 DTO。只服务于 HTTP 协议，独立于 application 的 Command。
 */
@Data
public class PlaceOrderRequest implements Serializable {

    private String userId;
    private List<Item> items;

    @Data
    public static class Item implements Serializable {
        private String productName;
        private int quantity;
        private BigDecimal price;
    }
}
