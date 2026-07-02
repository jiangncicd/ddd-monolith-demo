package com.example.app.trigger.rpc;

import com.example.app.application.order.OrderResult;
import com.example.app.application.order.PlaceOrderCommand;

/**
 * RPC 对外服务契约（Dubbo 风格）。
 * <p>真实微服务里，这个接口会放在独立的 {@code api} 模块，由调用方引 Jar 做代理；
 * 出入参需 {@code implements Serializable}。本单体示例为精简起见，直接复用 application 的
 * Command/Result 作为契约。
 */
public interface IOrderRpcService {
    OrderResult placeOrder(PlaceOrderCommand command);
}
