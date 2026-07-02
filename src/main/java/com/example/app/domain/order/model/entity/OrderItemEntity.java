package com.example.app.domain.order.model.entity;

import com.example.app.domain.order.model.valobj.Money;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 实体：订单项。携带自身的小行为（计算小计）——充血，而非纯数据。
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderItemEntity {

    private String productName;
    private int quantity;
    private Money price;

    /** 小计 = 单价 * 数量 */
    public Money subtotal() {
        return price.multiply(quantity);
    }
}
