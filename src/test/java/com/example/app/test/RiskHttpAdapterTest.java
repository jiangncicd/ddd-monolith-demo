package com.example.app.test;

import com.example.app.domain.rule.model.valobj.RiskLevel;
import com.example.app.infrastructure.adapter.RiskHttpAdapter;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestTemplate;

import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

/**
 * 适配器单元测试：用 MockRestServiceServer 拦截 RestTemplate，验证"调外部接口 + 防腐翻译"，
 * 无需真实外部服务、无需 Spring 容器。
 */
public class RiskHttpAdapterTest {

    private static final String URL = "http://risk.local/evaluate";

    private MockRestServiceServer server;
    private RiskHttpAdapter adapter;

    @BeforeEach
    void setUp() {
        RestTemplate restTemplate = new RestTemplate();
        server = MockRestServiceServer.createServer(restTemplate);
        adapter = new RiskHttpAdapter();
        ReflectionTestUtils.setField(adapter, "restTemplate", restTemplate);
        ReflectionTestUtils.setField(adapter, "riskServiceUrl", URL);
    }

    @Test
    void high_risk_translated_to_domain_HIGH() {
        server.expect(requestTo(URL)).andExpect(method(HttpMethod.POST))
                .andRespond(withSuccess("{\"riskLevel\":\"HIGH\",\"score\":95}", MediaType.APPLICATION_JSON));

        Assertions.assertEquals(RiskLevel.HIGH, adapter.evaluate("U0001", 25));
        server.verify();
    }

    @Test
    void low_risk_translated_to_domain_LOW() {
        server.expect(requestTo(URL))
                .andRespond(withSuccess("{\"riskLevel\":\"LOW\",\"score\":10}", MediaType.APPLICATION_JSON));

        Assertions.assertEquals(RiskLevel.LOW, adapter.evaluate("U0001", 25));
        server.verify();
    }

    @Test
    void empty_url_fails_open_to_LOW() {
        ReflectionTestUtils.setField(adapter, "riskServiceUrl", "");
        Assertions.assertEquals(RiskLevel.LOW, adapter.evaluate("U0001", 25));
    }
}
