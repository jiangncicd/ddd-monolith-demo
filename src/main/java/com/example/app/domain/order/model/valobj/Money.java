package com.example.app.domain.order.model.valobj;

import lombok.Value;

import java.math.BigDecimal;

/**
 * 值对象：金额。不可变，通过属性值识别（典型的 Value Object）。
 */
@Value
public class Money {

    BigDecimal amount;

    public static Money of(BigDecimal amount) {
        return new Money(amount);
    }

    public static Money zero() {
        return new Money(BigDecimal.ZERO);
    }

    public Money add(Money other) {
        return new Money(this.amount.add(other.amount));
    }

    public Money multiply(int quantity) {
        return new Money(this.amount.multiply(BigDecimal.valueOf(quantity)));
    }
}
