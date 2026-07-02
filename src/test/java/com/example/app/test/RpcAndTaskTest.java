package com.example.app.test;

import com.example.app.application.order.OrderResult;
import com.example.app.application.order.PlaceOrderCommand;
import com.example.app.trigger.rpc.IOrderRpcService;
import com.example.app.trigger.task.OrderStatTask;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

import java.math.BigDecimal;
import java.util.Collections;

/**
 * 验证 rpc / task 两个触发器：都复用 application 用例，不直接碰 infrastructure。
 */
@Slf4j
@SpringBootTest
public class RpcAndTaskTest {

    @Autowired
    private IOrderRpcService orderRpcService;

    @Autowired
    private OrderStatTask orderStatTask;

    @Test
    public void test_rpc_place_order() {
        PlaceOrderCommand command = PlaceOrderCommand.builder()
                .userId("U0001")
                .items(Collections.singletonList(
                        PlaceOrderCommand.Item.builder().productName("音响").quantity(1).price(new BigDecimal("599.00")).build()
                ))
                .build();

        OrderResult result = orderRpcService.placeOrder(command);
        Assertions.assertTrue(result.isSuccess());
        Assertions.assertNotNull(result.getOrderId());
    }

    @Test
    public void test_task_runs_without_touching_infrastructure() {
        // 直接触发定时任务方法，验证 task -> application 查询用例 -> domain 链路可用
        orderStatTask.reportOrderStat();
    }
}
