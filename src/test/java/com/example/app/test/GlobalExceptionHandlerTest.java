package com.example.app.test;

import com.example.app.application.order.IOrderPlaceUseCase;
import com.example.app.application.order.OrderResult;
import com.example.app.trigger.http.OrderController;
import com.example.app.types.AppException;
import com.example.app.types.Constants;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 只加载 web 切片（Controller + @RestControllerAdvice），mock 掉 application 用例后抛各类异常，
 * 验证全局异常处理把它们翻译成统一 Response 信封。
 */
@WebMvcTest(OrderController.class)
public class GlobalExceptionHandlerTest {

    private static final String BODY =
            "{\"userId\":\"U0001\",\"items\":[{\"productName\":\"x\",\"quantity\":1,\"price\":1.00}]}";

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private IOrderPlaceUseCase orderPlaceUseCase;

    @Test
    void success_returns_0000() throws Exception {
        given(orderPlaceUseCase.placeOrder(any()))
                .willReturn(OrderResult.builder().success(true).orderId("ORD1").build());

        mockMvc.perform(post("/api/order/place").contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(Constants.ResponseCode.SUCCESS.getCode()))
                .andExpect(jsonPath("$.data.success").value(true));
    }

    @Test
    void app_exception_returns_its_code_http_200() throws Exception {
        given(orderPlaceUseCase.placeOrder(any()))
                .willThrow(new AppException(Constants.ResponseCode.RULE_REJECT, "风控拒绝"));

        mockMvc.perform(post("/api/order/place").contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(Constants.ResponseCode.RULE_REJECT.getCode()))
                .andExpect(jsonPath("$.info").value("风控拒绝"));
    }

    @Test
    void illegal_argument_returns_0002_http_400() throws Exception {
        given(orderPlaceUseCase.placeOrder(any()))
                .willThrow(new IllegalArgumentException("非法订单项"));

        mockMvc.perform(post("/api/order/place").contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(Constants.ResponseCode.ILLEGAL_PARAMETER.getCode()));
    }

    @Test
    void unknown_exception_returns_0001_http_500() throws Exception {
        given(orderPlaceUseCase.placeOrder(any()))
                .willThrow(new RuntimeException("boom"));

        mockMvc.perform(post("/api/order/place").contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.code").value(Constants.ResponseCode.UN_ERROR.getCode()));
    }
}
