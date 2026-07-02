package com.example.app.trigger.mq;

import lombok.Data;

import java.io.Serializable;
import java.math.BigDecimal;
import java.util.List;

/**
 * MQ 消息体。每种触发器有自己的协议模型（这里是消息 payload），独立于 HTTP DTO 与领域模型。
 */
@Data
public class OrderPlaceMessage implements Serializable {

    private String userId;
    private List<Item> items;

    @Data
    public static class Item implements Serializable {
        private String productName;
        private int quantity;
        private BigDecimal price;
    }
}
