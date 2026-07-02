package com.example.app.trigger.rpc;

import com.example.app.application.order.IOrderPlaceUseCase;
import com.example.app.application.order.OrderResult;
import com.example.app.application.order.PlaceOrderCommand;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.annotation.Resource;

/**
 * RPC 触发器实现：和 http/mq 一样只做适配，复用同一个 {@link IOrderPlaceUseCase}。
 * <p>接入真实 Dubbo 时，把类上注解换成 {@code @org.apache.dubbo.config.annotation.DubboService}
 * 即可对外暴露（并在 application.yml 配置注册中心）。这里用普通 {@code @Service} 保持开箱即跑与可测。
 */
@Slf4j
@Service
public class OrderRpcService implements IOrderRpcService {

    @Resource
    private IOrderPlaceUseCase orderPlaceUseCase;

    @Override
    public OrderResult placeOrder(PlaceOrderCommand command) {
        log.info("[RPC] 收到下单请求 userId={}", command.getUserId());
        OrderResult result = orderPlaceUseCase.placeOrder(command);
        log.info("[RPC] 下单处理结果：{}", result);
        return result;
    }
}
