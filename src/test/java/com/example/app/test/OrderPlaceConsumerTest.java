package com.example.app.test;

import com.example.app.infrastructure.dao.OrderDao;
import com.example.app.trigger.mq.OrderPlaceConsumer;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * 验证 MQ 触发器：收到消息后经 application 用例把订单写入库。
 */
@Slf4j
@SpringBootTest
public class OrderPlaceConsumerTest {

    @Autowired
    private OrderPlaceConsumer orderPlaceConsumer;

    @Autowired
    private OrderDao orderDao;

    @Test
    public void test_consume_place_order_success() {
        long before = orderDao.countOrders();

        String message = "{\"userId\":\"U0001\",\"items\":[{\"productName\":\"耳机\",\"quantity\":1,\"price\":299.00}]}";
        orderPlaceConsumer.onMessage(message);

        Assertions.assertEquals(before + 1, orderDao.countOrders());
    }

    @Test
    public void test_consume_rule_reject_no_order_written() {
        long before = orderDao.countOrders();

        // Bob 16 岁，规则拒绝，不应落库
        String message = "{\"userId\":\"U0002\",\"items\":[{\"productName\":\"手柄\",\"quantity\":1,\"price\":199.00}]}";
        orderPlaceConsumer.onMessage(message);

        Assertions.assertEquals(before, orderDao.countOrders());
    }
}
