package com.example.app.test;

import com.example.app.application.order.IOrderPlaceUseCase;
import com.example.app.application.order.OrderResult;
import com.example.app.application.order.PlaceOrderCommand;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.Collections;

/**
 * 端到端验证：HTTP 之外，直接驱动 application 用例，串起 user + rule + order + infrastructure。
 */
@Slf4j
@SpringBootTest
public class ApiTest {

    @Autowired
    private IOrderPlaceUseCase orderPlaceUseCase;

    @Test
    public void test_place_order_success() {
        PlaceOrderCommand command = PlaceOrderCommand.builder()
                .userId("U0001") // Alice, 25 岁，规则通过
                .items(Arrays.asList(
                        PlaceOrderCommand.Item.builder().productName("键盘").quantity(1).price(new BigDecimal("199.00")).build(),
                        PlaceOrderCommand.Item.builder().productName("鼠标").quantity(2).price(new BigDecimal("99.50")).build()
                ))
                .build();

        OrderResult result = orderPlaceUseCase.placeOrder(command);
        log.info("下单结果：{}", result);

        Assertions.assertTrue(result.isSuccess());
        Assertions.assertNotNull(result.getOrderId());
        Assertions.assertEquals(0, new BigDecimal("398.00").compareTo(result.getTotalAmount()));
    }

    @Test
    public void test_place_order_rule_reject() {
        PlaceOrderCommand command = PlaceOrderCommand.builder()
                .userId("U0002") // Bob, 16 岁，规则拒绝
                .items(Collections.singletonList(
                        PlaceOrderCommand.Item.builder().productName("显示器").quantity(1).price(new BigDecimal("1299.00")).build()
                ))
                .build();

        OrderResult result = orderPlaceUseCase.placeOrder(command);
        log.info("下单结果：{}", result);

        Assertions.assertFalse(result.isSuccess());
        Assertions.assertNull(result.getOrderId());
    }
}
