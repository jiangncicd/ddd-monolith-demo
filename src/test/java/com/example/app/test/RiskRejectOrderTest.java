package com.example.app.test;

import com.example.app.application.order.IOrderPlaceUseCase;
import com.example.app.application.order.OrderResult;
import com.example.app.application.order.PlaceOrderCommand;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.Collections;

import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

/**
 * 端到端验证外部风控接入：打开 risk.service.url，用 MockRestServiceServer 拦截真实的 RestTemplate 单例，
 * 让外部风控返回 HIGH —— 下单应被规则领域拒绝。
 * <p>用独立的 H2 库（riskdb）隔离本测试上下文，避免与其他测试共享内存库产生干扰。
 */
@Slf4j
@SpringBootTest(properties = {
        "risk.service.url=http://risk.local/evaluate",
        "spring.datasource.url=jdbc:h2:mem:riskdb;MODE=MySQL;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE"
})
public class RiskRejectOrderTest {

    @Autowired
    private IOrderPlaceUseCase orderPlaceUseCase;

    @Autowired
    private RestTemplate restTemplate;

    @Test
    void high_risk_rejects_order() {
        MockRestServiceServer server = MockRestServiceServer.createServer(restTemplate);
        server.expect(requestTo("http://risk.local/evaluate"))
                .andRespond(withSuccess("{\"riskLevel\":\"HIGH\",\"score\":95}", MediaType.APPLICATION_JSON));

        PlaceOrderCommand command = PlaceOrderCommand.builder()
                .userId("U0001") // 年龄通过，但外部风控 HIGH
                .items(Collections.singletonList(
                        PlaceOrderCommand.Item.builder().productName("显卡").quantity(1).price(new BigDecimal("4999.00")).build()
                ))
                .build();

        OrderResult result = orderPlaceUseCase.placeOrder(command);
        log.info("下单结果：{}", result);

        Assertions.assertFalse(result.isSuccess());
        Assertions.assertNull(result.getOrderId());
        server.verify();
    }
}
